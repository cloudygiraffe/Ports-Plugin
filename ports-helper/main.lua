-- main.lua: Ports & Arc Helper entry point.
--
-- Takes the chores and guesswork out of Player-owned Ports and The Arc:
-- reset countdowns and reminders, warnings before rerolls or resources are
-- wasted, the Arc's daily bird and castaway timetable, a crew optimizer, and
-- a story helper for getting the right adventurers to visit.
--
-- How the pieces fit together (see docs/DESIGN.md):
--
--   sources/port_vars.lua ----+
--   (game variables, always)  +--> port_state.lua --> warnings.lua --\
--   sources/captains_log.lua -+          |                             display.lua --> panel.lua
--   (open port windows)                  |                             story.lua ----/
--   schedule.lua, arc_schedule.lua ------+--> reminders.lua --> alert_line.lua
--   optimizer.lua (crew search, run a slice each server tick)
--   clock.lua <-- voyage-list timer variable, Captain's Log RuneDate, chat
--                 timestamps, os.time() (best available source wins)
--
-- This file only wires game events and the panel to those modules. Everything
-- that decides what to show lives in pure, unit-tested modules under src/.
--
-- Event budget: Logic (50/s) only advances the clock. ServerLogic (every
-- 0.6 s) does the real work, spread out: the optimizer gets a fixed slice
-- every tick, game data is read every 3rd tick, the panel and reminders are
-- refreshed every 8th tick.

local Clock = require("src/clock")
local Schedule = require("src/schedule")
local PortState = require("src/port_state")
local Reminders = require("src/reminders")
local Optimizer = require("src/optimizer")
local Display = require("src/display")
local Story = require("src/story")
local Storage = require("src/storage")
local Panel = require("src/panel")
local AlertLine = require("src/alert_line")
local CaptainsLog = require("src/sources/captains_log")
local PortVars = require("src/sources/port_vars")

local READ_WINDOWS_EVERY = 3   -- server ticks (0.6 s each) between game-data reads
local REFRESH_EVERY = 8        -- server ticks between panel/reminder refreshes
-- Crew combinations checked per server tick. A full roster (5 captains x
-- C(25,5) crew = 265,650 setups) finishes in about 18 ticks (~11 s) without
-- a noticeable frame cost; see docs/DESIGN.md.
local OPTIMIZER_STEPS_PER_TICK = 15000
-- The RuneDate header is only accurate to ~7 minutes, so it only corrects the
-- clock when the clock is unknown or more than 15 minutes out.
local RUNEDATE_RESYNC_SECONDS = 900

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

-- Everything here survives the panel being closed and reopened; the panel is
-- rebuilt from it on every ContentLayerReady.
local settings = Storage.LoadSettings(Reminders.DEFAULT_SETTINGS) -- reminder toggles
local shownReminders = Storage.LoadShown()  -- { key = occurrence } already shown
local section = "overview"                  -- Panel.SECTIONS key on screen
local crewInputs = { morale = "", combat = "", seafaring = "", resource = false }
local crewJob = nil      -- running optimizer search, if any
local crewResult = nil   -- last finished result
local characterName = nil -- display name of the logged-in character, once known
local storyTarget = Storage.LoadStoryTarget() or "icons" -- Story.TARGETS key

local alertLine = AlertLine.new()
local panel -- created below

-- True if the player granted the optional chatAccess permission. Guarded:
-- the permission API must never be able to break the plugin.
local function hasChatAccess()
    local ok, granted = pcall(function()
        return Plugin.HasPermission(PluginPermissions.chatAccess)
    end)
    return ok and granted == true
end

-- The last voyage requirement filled into the crew optimizer, so a voyage is
-- only filled in once (and the player can still type over it).
local lastRequirementKey = nil

-- True once any port data (ships, rerolls, resources) has been read; the
-- overview uses it to explain why ship/resource warnings are missing.
local function portDataKnown()
    local state = PortState.Get()
    return state.ships ~= nil or state.rerolls ~= nil or state.resources ~= nil
end

-- The captains, crew and ship stats for the optimizer, from PortState.
-- TO DO: nothing fills these in yet (see the README roadmap: decoding the
-- POP_CREW_INV_VAR_* roster variables), so the optimizer reports an empty roster.
local function roster()
    local state = PortState.Get()
    return state.captains or {}, state.crew or {}, state.ship or {}
end

--------------------------------------------------------------------------------
-- Panel content
--------------------------------------------------------------------------------

-- Builds the text for the section currently on screen. Returns a string with
-- RuneScape markup (<br>, <col=...>).
local function bodyText()
    local now = Clock.Now()
    if section == "overview" then
        -- The streak is only shown once voyages are actually being recorded.
        local streak = nil
        if now and PortState.HasVoyageHistory() then
            streak = PortState.Streak(Schedule.DayKey(now))
        end
        return Display.Overview(now, PortState.Get(), streak, portDataKnown())
    elseif section == "arc" then
        return Display.ArcToday(now)
    elseif section == "crew" then
        local _, crew = roster()
        return Display.CrewResult(crewResult, #crew, crewJob ~= nil)
    elseif section == "story" then
        return Story.HelperText(storyTarget)
    elseif section == "settings" then
        return "Reminders appear as a gold line at the top of the screen"
            .. (hasChatAccess() and " and in your chat box." or ".")
            .. "<br>Times are in game time (UTC), which is when RuneScape resets."
    end
    return ""
end

-- Re-renders the body text. Cheap no-op while the panel isn't visible.
local function refreshPanel()
    panel:SetBody(bodyText())
end

--------------------------------------------------------------------------------
-- Reminders
--------------------------------------------------------------------------------

-- Shows any reminder that has just become due, once per occurrence (the
-- occurrence is saved, so reloading the plugin doesn't repeat it).
local function checkReminders()
    local due = Reminders.Due(Clock.Now(), settings, shownReminders)
    for _, reminder in ipairs(due) do
        shownReminders[reminder.key] = reminder.occurrence
        alertLine:Show(reminder.text)
        if hasChatAccess() then
            pcall(function() Chat.AddMessage(reminder.text) end)
        end
    end
    if #due > 0 then
        Storage.SaveShown(shownReminders)
    end
end

--------------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------------

-- Panel callbacks: the panel owns no state, it reports what the player did.
panel = Panel.new({
    onSection = function(key)
        section = key
        panel:ShowSection(key)
        refreshPanel()
    end,
    -- Starts a new optimizer search; it runs a slice per server tick below.
    onFindCrew = function(morale, combat, seafaring, isResourceVoyage)
        crewInputs = { morale = morale, combat = combat, seafaring = seafaring,
                       resource = isResourceVoyage }
        local captains, crew, ship = roster()
        if #captains == 0 or #crew == 0 then
            crewResult = nil
            refreshPanel()
            return
        end
        crewJob = Optimizer.NewJob({
            voyage = { morale = tonumber(morale) or 0, combat = tonumber(combat) or 0,
                       seafaring = tonumber(seafaring) or 0 },
            ship = ship, captains = captains, crew = crew,
            resourceVoyage = isResourceVoyage,
        })
        crewResult = nil
        refreshPanel()
    end,
    onSetting = function(key, value)
        settings[key] = value
        Storage.SaveSettings(settings)
    end,
    onStoryTarget = function(key)
        storyTarget = key
        Storage.SaveStoryTarget(key)
        refreshPanel()
    end,
}, Story.TARGETS)

-- The game hands us a fresh, empty layer each time the panel is opened
-- (needs "hasRibbonIcon": true in plugin.json).
Event.ContentLayerReady.Subscribe("portsPanel", function(event)
    panel:Build(event.component, section, settings, crewInputs, storyTarget)
    refreshPanel()
end)

--------------------------------------------------------------------------------
-- Game events
--------------------------------------------------------------------------------

-- Keeps the clock ticking (50 times a second; kept tiny).
Event.Logic.Subscribe("portsClock", function(event)
    Clock.OnLogicTick(event.logicTick)
end)

-- Loads the character's Portnight history after login or a character switch.
-- PersistentDB is shared by every character on the computer, hence per-name keys.
local function checkCharacter()
    local ok, name = pcall(function()
        if Player.IsAvailable() then
            return Player.GetEntity().displayName
        end
        return nil
    end)
    if ok and name and name ~= characterName then
        characterName = name
        PortState.ImportVoyageDays(Storage.LoadVoyageDays(name))
    end
end

-- Reads the port's game variables, and fills the crew optimizer with the
-- requirements of the voyage the game is showing.
local function readPortVars()
    local fields = PortVars.Read()
    if next(fields) == nil then
        return
    end
    PortState.Update(fields, Clock.Now())
    local need = fields.voyageRequirement
    if need then
        local key = need.morale .. "/" .. need.combat .. "/" .. need.seafaring
        if key ~= lastRequirementKey then
            lastRequirementKey = key
            crewInputs.morale = tostring(need.morale)
            crewInputs.combat = tostring(need.combat)
            crewInputs.seafaring = tostring(need.seafaring)
            panel:SetCrewInputs(need.morale, need.combat, need.seafaring)
        end
    end
end

-- Reads the Captain's Log and port windows while they're open.
local function readPortWindows()
    if not CaptainsLog.IsConfigured() then
        return
    end
    local logTime, fields = CaptainsLog.Read()
    if logTime then
        local now = Clock.Now()
        if now == nil or math.abs(now - logTime) > RUNEDATE_RESYNC_SECONDS then
            Clock.SyncWithQuality(logTime, Clock.QUALITY.RUNEDATE)
        end
    end
    if fields and next(fields) ~= nil then
        PortState.Update(fields, Clock.Now())
    end
end

local serverTicks = 0
Event.ServerLogic.Subscribe("portsTick", function()
    serverTicks = serverTicks + 1
    alertLine:Update()

    -- Run the crew search a little each tick so the game never stutters.
    if crewJob then
        if crewJob:Step(OPTIMIZER_STEPS_PER_TICK) then
            crewResult = crewJob:Result()
            crewJob = nil
            refreshPanel()
        end
    end

    if serverTicks % READ_WINDOWS_EVERY == 0 then
        checkCharacter()
        readPortVars()
        readPortWindows()
    end
    if serverTicks % REFRESH_EVERY == 0 then
        checkReminders()
        refreshPanel()
    end
end)

-- Opening the voyage list stamps the current minute into a game variable
-- (POP_VOYAGE_LIST_TIMER_STARTED, minutes since 1970; observed on the beta
-- world, October 22nd, 2026), which gives the plugin the time with no
-- permissions at all. Only a change is trusted: the game also re-sends the old
-- value, which would be stale. +30 s puts the estimate mid-minute.
Event.VarTransmit.Subscribe("portsVars", function(event)
    if PortVars.IsTimerStarted(event) and event.newValue ~= event.oldValue then
        local unix = PortVars.MinutesToUnix(event.newValue)
        if unix then
            Clock.SyncWithQuality(unix + 30, Clock.QUALITY.PORT_TIMER)
        end
    end
end)

-- Chat timestamps are a fallback clock. Only delivered with the optional
-- chatAccess permission; guarded so the plugin works without it.
pcall(function()
    Event.ChatMessage.Subscribe("portsChat", function(event)
        if type(event.timestamp) == "number" and event.timestamp > 0 then
            Clock.SyncWithQuality(event.timestamp, Clock.QUALITY.CHAT)
        end
    end)
end)

-- os.time() isn't documented for plugins; if the sandbox has it, it's the
-- best clock of all. Observed on the beta world: not available.
Clock.TrySystemClock()

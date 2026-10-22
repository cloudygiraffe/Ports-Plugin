-- Ports & Arc helper
-- Takes the chores and guesswork out of Player-owned Ports and The Arc:
-- reset countdowns and reminders, warnings before rerolls or resources are
-- wasted, the Arc's daily bird and castaway timetable, a crew optimizer, and
-- a story helper for getting the right adventurers to visit.
--
-- How the pieces fit together (see docs/DESIGN.md):
--
--   sources/captains_log.lua --> port_state.lua --> warnings.lua --\
--   (reads open port windows)        |                               display.lua --> panel.lua
--   schedule.lua, arc_schedule.lua --+--> reminders.lua --> alert_line.lua
--   optimizer.lua (crew search, run a little each tick)
--
-- This file only wires game events and the panel to those modules.

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

local READ_WINDOWS_EVERY = 3   -- server ticks (0.6 s each) between window reads
local REFRESH_EVERY = 8        -- server ticks between panel/reminder refreshes
local OPTIMIZER_STEPS_PER_TICK = 15000
local RUNEDATE_RESYNC_SECONDS = 900 -- only re-sync from the Log if we're 15+ min off

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local settings = Storage.LoadSettings(Reminders.DEFAULT_SETTINGS)
local shownReminders = Storage.LoadShown()
local section = "overview"
local crewInputs = { morale = "", combat = "", seafaring = "", resource = false }
local crewJob = nil      -- running optimizer search, if any
local crewResult = nil   -- last finished result
local characterName = nil
local storyTarget = Storage.LoadStoryTarget() or "icons"

local alertLine = AlertLine.new()
local panel -- created below

local function hasChatAccess()
    local ok, granted = pcall(function()
        return Plugin.HasPermission(PluginPermissions.chatAccess)
    end)
    return ok and granted == true
end

-- The last voyage requirement filled into the crew optimizer, so a voyage is
-- only filled in once (and the player can still type over it).
local lastRequirementKey = nil

-- True once any port data (ships, rerolls, resources) has been read.
local function portDataKnown()
    local state = PortState.Get()
    return state.ships ~= nil or state.rerolls ~= nil or state.resources ~= nil
end

local function roster()
    local state = PortState.Get()
    return state.captains or {}, state.crew or {}, state.ship or {}
end

--------------------------------------------------------------------------------
-- Panel content
--------------------------------------------------------------------------------

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

local function refreshPanel()
    panel:SetBody(bodyText())
end

--------------------------------------------------------------------------------
-- Reminders
--------------------------------------------------------------------------------

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

panel = Panel.new({
    onSection = function(key)
        section = key
        panel:ShowSection(key)
        refreshPanel()
    end,
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

-- Opening the voyage list stamps the current minute into a game variable,
-- which gives the plugin the time with no permissions at all. Only a change is
-- trusted (a re-sent old value would be stale); +30 s is the middle of that minute.
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

Clock.TrySystemClock()

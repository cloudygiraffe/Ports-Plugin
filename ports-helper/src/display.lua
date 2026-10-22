-- display.lua
-- Builds the text for each section of the panel. Pure functions, unit
-- tested. Uses RuneScape text markup: "<br>" for a new line and
-- "<col=RRGGBB>...</col>" for colour.

local TimeUtil = require("src/timeutil")
local Schedule = require("src/schedule")
local ArcSchedule = require("src/arc_schedule")
local Warnings = require("src/warnings")

local Display = {}

local GOLD = "ffd24a"
local GREY = "9a9a9a"
local RED = "ff6b6b"
local ORANGE = "ff9f43"

local function colour(text, hex)
    return "<col=" .. hex .. ">" .. text .. "</col>"
end

local function heading(text)
    return colour(text, GOLD)
end

-- Shown wherever the plugin needs the time but doesn't know it yet.
Display.NO_CLOCK = colour("The plugin doesn't know the time yet. Open your Captain's Log once, "
    .. "or allow the optional chat permission, and the countdowns will appear.", GREY)

--------------------------------------------------------------------------------
-- Overview: resets, reminders, warnings, streak
--------------------------------------------------------------------------------

-- state: PortState.Get(); streak: PortState.Streak(today), or nil while the
-- plugin can't yet see voyages being sent; now may be nil.
function Display.Overview(now, state, streak, portDataKnown)
    local lines = {}

    table.insert(lines, heading("Resets"))
    if now then
        table.insert(lines, "Daily reset in " .. TimeUtil.FormatDuration(Schedule.NextDailyReset(now) - now)
            .. " (unused rerolls are lost)")
        table.insert(lines, "Meg, Black Marketeer and Advance Time reset in "
            .. TimeUtil.FormatDuration(Schedule.NextWeeklyReset(now) - now))
        local tip = Schedule.BarmaidsTip(now)
        if tip.availableNow then
            table.insert(lines, colour("Barmaid's Tip voyage available today", GOLD))
        else
            table.insert(lines, "Next Barmaid's Tip in " .. TimeUtil.FormatDuration(tip.startsAt - now))
        end
    else
        table.insert(lines, Display.NO_CLOCK)
    end

    table.insert(lines, "")
    table.insert(lines, heading("Needs attention"))
    local warnings = Warnings.Compute(state, now)
    if #warnings == 0 then
        table.insert(lines, colour("Nothing right now.", GREY))
    end
    for _, warning in ipairs(warnings) do
        local hex = warning.level == Warnings.URGENT and RED
            or (warning.level == Warnings.SOON and ORANGE or nil)
        table.insert(lines, "- " .. (hex and colour(warning.text, hex) or warning.text))
    end
    if not portDataKnown then
        table.insert(lines, colour("Ship, reroll and resource warnings appear once the plugin "
            .. "can read your Captain's Log (see docs/TESTING.md).", GREY))
    end

    table.insert(lines, "")
    table.insert(lines, heading("Portnight"))
    if streak then
        table.insert(lines, streak .. " day" .. (streak == 1 and "" or "s")
            .. " in a row with a voyage sent (14 needed for the achievement)")
    else
        table.insert(lines, colour("Streak tracking starts once the plugin can see voyages being sent.", GREY))
    end

    return table.concat(lines, "<br>")
end

--------------------------------------------------------------------------------
-- Arc today
--------------------------------------------------------------------------------

function Display.ArcToday(now)
    if now == nil then
        return Display.NO_CLOCK
    end
    local lines = {}
    local bird = ArcSchedule.BirdToday(now)
    table.insert(lines, heading(TimeUtil.WEEKDAY_NAMES[TimeUtil.Weekday(now)] .. "'s bird"))
    table.insert(lines, bird.bird .. " on " .. bird.island)
    if bird.visibleNow then
        table.insert(lines, colour("Out now, for another "
            .. TimeUtil.FormatDuration(bird.visibleUntil - now), GOLD))
    end
    if bird.nextSpawn then
        table.insert(lines, "Next appearance in " .. TimeUtil.FormatDuration(bird.nextSpawn - now)
            .. " (about 10 minutes each, every 30 min 30 s)")
    else
        table.insert(lines, "No more appearances today.")
    end

    table.insert(lines, "")
    table.insert(lines, heading("Castaway bottles out today"))
    local names = {}
    for _, castaway in ipairs(ArcSchedule.CastawaysToday(now)) do
        table.insert(names, castaway.number .. ". " .. castaway.name)
    end
    table.insert(lines, table.concat(names, "<br>"))
    table.insert(lines, colour("Bottles you've already found stay visible to you.", GREY))
    return table.concat(lines, "<br>")
end

--------------------------------------------------------------------------------
-- Crew optimizer
--------------------------------------------------------------------------------

local function percent(fraction)
    return math.floor(fraction * 1000 + 0.5) / 10 .. "%"
end

-- result: Optimizer job Result(), or nil. rosterSize: number of crew known.
function Display.CrewResult(result, rosterSize, searching)
    if rosterSize == 0 then
        return colour("No crew loaded yet. Once the plugin can read your Crew Roster "
            .. "(see docs/TESTING.md), enter a voyage's Morale, Combat and Seafaring "
            .. "above and press Find best crew.", GREY)
    end
    if searching then
        return colour("Checking every captain and crew combination...", GREY)
    end
    if result == nil then
        return colour("Enter the voyage's three stats above and press Find best crew.", GREY)
    end
    local lines = {}
    table.insert(lines, heading("Best success chance: " .. percent(result.chance)))
    table.insert(lines, "Morale " .. percent(result.bars.morale) .. " | Combat "
        .. percent(result.bars.combat) .. " | Seafaring " .. percent(result.bars.seafaring))
    table.insert(lines, "Captain: " .. (result.captain.name or "?"))
    local crewNames = {}
    for _, member in ipairs(result.crew) do
        table.insert(crewNames, (member.name or "?") .. " (lvl " .. (member.level or "?") .. ")")
    end
    table.insert(lines, "Crew: " .. table.concat(crewNames, ", "))
    table.insert(lines, colour("Ties go to your lowest-level crew, so they level up.", GREY))
    return table.concat(lines, "<br>")
end

return Display

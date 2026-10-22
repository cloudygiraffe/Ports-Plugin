-- reminders.lua
-- Decides which one-off reminders are due right now. Each reminder has an
-- "occurrence" (for example, today's date) so it is shown once per
-- occurrence, even across reloads. Pure functions: unit tested.
--
-- Reminders:
--   resetSoon : the daily reset is coming; use your rerolls and send ships
--   tip       : it's Thursday; the Barmaid's Tip voyage is available
--   weekly    : Wednesday's reset (Meg, Black Marketeer, Advance Time) is coming
--   bird      : today's Arc bird is about to appear (off by default)

local Schedule = require("src/schedule")
local ArcSchedule = require("src/arc_schedule")
local TimeUtil = require("src/timeutil")

local Reminders = {}

Reminders.DEFAULT_SETTINGS = {
    resetSoon = true,
    resetLeadMinutes = 60,
    tip = true,
    weekly = true,
    bird = false,
    birdLeadMinutes = 2,
}

-- Returns the list of due reminders as { key, occurrence, text }. The caller
-- shows each one and stores shown[key] = occurrence, so it isn't repeated.
-- The occurrence is the Unix time of the event itself (e.g. the reset), so a
-- reminder fires again for the next reset but never twice for the same one.
--   now      : Unix time (reminders need a clock; returns {} if nil)
--   settings : see DEFAULT_SETTINGS
--   shown    : { [key] = occurrence } of reminders already shown
function Reminders.Due(now, settings, shown)
    local due = {}
    if now == nil then
        return due
    end
    settings = settings or Reminders.DEFAULT_SETTINGS
    shown = shown or {}

    local function add(key, occurrence, text)
        if shown[key] ~= occurrence then
            table.insert(due, { key = key, occurrence = occurrence, text = text })
        end
    end

    local nextReset = Schedule.NextDailyReset(now)
    if settings.resetSoon and nextReset - now <= (settings.resetLeadMinutes or 60) * 60 then
        add("resetSoon", nextReset, "Ports resets in " .. TimeUtil.FormatDuration(nextReset - now)
            .. ": use your voyage and crew rerolls before they're lost.")
    end

    local tip = Schedule.BarmaidsTip(now)
    if settings.tip and tip.availableNow then
        add("tip", tip.endsAt, "It's Thursday: the Barmaid's Tip voyage is available in your port.")
    end

    local weekly = Schedule.NextWeeklyReset(now)
    if settings.weekly and weekly - now <= 24 * 3600 then
        add("weekly", weekly, "Meg, the Black Marketeer and Advance Time reset at midnight UTC tonight.")
    end

    if settings.bird then
        local bird = ArcSchedule.BirdToday(now)
        local lead = (settings.birdLeadMinutes or 2) * 60
        if bird.nextSpawn and bird.nextSpawn - now <= lead then
            add("bird", bird.nextSpawn, "The " .. bird.bird .. " appears on " .. bird.island
                .. " in " .. TimeUtil.FormatDuration(bird.nextSpawn - now) .. ".")
        end
    end

    return due
end

return Reminders

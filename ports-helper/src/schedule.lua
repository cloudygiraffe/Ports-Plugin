-- schedule.lua
-- When Player-owned Ports' daily and weekly events happen. Pure functions of
-- the current Unix time, so they are fully unit tested.
--
-- From the RuneScape Wiki (see docs/RESEARCH.md):
--   * Daily reset, 00:00 UTC: new visiting adventurers and captain for hire,
--     new Trader stock, 15 voyage rerolls and 15 crew rerolls, chimes over the
--     200,000 cap trimmed. UNUSED REROLLS ARE LOST.
--   * Wednesday 00:00 UTC: Meg's questions, the Black Marketeer's stock and
--     the Advance Time spell's 3 charges reset.
--   * Thursday: the Barmaid's Tip voyage is offered; it must be claimed
--     before Thursday's reset (i.e. by Friday 00:00 UTC).

local TimeUtil = require("src/timeutil")

local Schedule = {}

local WEDNESDAY = 3
local THURSDAY = 4
local DAY = TimeUtil.SECONDS_PER_DAY

-- Unix time of the next daily reset (00:00 UTC) strictly after `now`.
function Schedule.NextDailyReset(now)
    return TimeUtil.DayStart(now) + DAY
end

-- Unix time of the next 00:00 UTC on the given weekday (1 = Monday) after
-- `now`. If today is that weekday, its 00:00 has already passed, so this
-- returns the same weekday next week.
local function nextWeekdayStart(now, weekday)
    local today = TimeUtil.Weekday(now)
    local daysAhead = (weekday - today) % 7
    if daysAhead == 0 then
        daysAhead = 7 -- today's 00:00 has already passed
    end
    return TimeUtil.DayStart(now) + daysAhead * DAY
end

-- Unix time of the next Wednesday reset (Meg, Black Marketeer, Advance Time).
function Schedule.NextWeeklyReset(now)
    return nextWeekdayStart(now, WEDNESDAY)
end

-- Information about the Barmaid's Tip for `now`:
--   { availableNow = true,  endsAt = <Friday 00:00> }  on Thursdays
--   { availableNow = false, startsAt = <next Thursday 00:00> } otherwise
function Schedule.BarmaidsTip(now)
    if TimeUtil.Weekday(now) == THURSDAY then
        return { availableNow = true, endsAt = TimeUtil.DayStart(now) + DAY }
    end
    return { availableNow = false, startsAt = nextWeekdayStart(now, THURSDAY) }
end

-- The "day key" of `now`: whole days since January 1st, 1970 UTC, so it
-- changes at each daily reset. Used to remember things like "sent a voyage
-- today" (PortState's Portnight history is keyed by it).
function Schedule.DayKey(now)
    return math.floor(now / DAY)
end

return Schedule

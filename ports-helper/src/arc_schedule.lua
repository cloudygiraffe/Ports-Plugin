-- arc_schedule.lua
-- The Arc's fixed, public timetables: which island bird appears today (and
-- when), and which castaway bottles are out today. These are the same for
-- every player on every world, so they only need the current time.
--
-- Source: the RuneScape Wiki's "The Arc/Birds" and "Castaways" pages and its
-- rotation code (Module:Rotations/js), checked October 22nd, 2026. If a
-- spawn time ever disagrees with the game, the numbers below are the only
-- thing to change.

local TimeUtil = require("src/timeutil")

local ArcSchedule = {}

local DAY = TimeUtil.SECONDS_PER_DAY

--------------------------------------------------------------------------------
-- Birds
--------------------------------------------------------------------------------

-- On its day, an island's bird appears every 30 minutes 30 seconds from
-- 00:00 UTC and stays for about 10 minutes.
ArcSchedule.BIRD_INTERVAL_SECONDS = 1830
ArcSchedule.BIRD_VISIBLE_SECONDS = 600

-- Index 1 = Monday ... 7 = Sunday.
ArcSchedule.BIRDS = {
    { bird = "Crested Sillago Snatcher", island = "Whale's Maw" },
    { bird = "Shrine Ibis", island = "Aminishi" },
    { bird = "Gongdung Peligorn", island = "Goshima" },
    { bird = "Cyclosis Cockatiel", island = "Cyclosis" },
    { bird = "Titchy Tinamou", island = "The Islands That Once Were Turtles" },
    { bird = "Tuai Leit Toucan", island = "Tuai Leit" },
    { bird = "Waiko Warbler", island = "Waiko" },
}

-- Today's island bird and its spawn timing relative to `now`:
--   bird, island      : names
--   visibleNow        : true if it is out right now
--   visibleUntil      : when the current appearance ends (if visibleNow)
--   nextSpawn         : start of the next appearance today, or nil if none
function ArcSchedule.BirdToday(now)
    local entry = ArcSchedule.BIRDS[TimeUtil.Weekday(now)]
    local dayStart = TimeUtil.DayStart(now)
    local intoDay = now - dayStart
    local index = math.floor(intoDay / ArcSchedule.BIRD_INTERVAL_SECONDS)
    local currentStart = dayStart + index * ArcSchedule.BIRD_INTERVAL_SECONDS
    local result = { bird = entry.bird, island = entry.island }

    if now < currentStart + ArcSchedule.BIRD_VISIBLE_SECONDS then
        result.visibleNow = true
        result.visibleUntil = currentStart + ArcSchedule.BIRD_VISIBLE_SECONDS
    else
        result.visibleNow = false
    end
    local nextStart = currentStart + ArcSchedule.BIRD_INTERVAL_SECONDS
    if nextStart < dayStart + DAY then
        result.nextSpawn = nextStart
    end
    return result
end

--------------------------------------------------------------------------------
-- Castaways
--------------------------------------------------------------------------------

-- Bottle n is out every n days, changing at 00:00 UTC. `firstDay` is a date
-- it was out; every n days after (or before) that, it is out again.
ArcSchedule.CASTAWAYS = {
    { number = 1,  name = "Milky Bay",       firstDay = { 2025, 8, 31 } }, -- every day
    { number = 2,  name = "Goon Docks",      firstDay = { 2025, 8, 31 } },
    { number = 3,  name = "Christmas Island", firstDay = { 2025, 8, 31 } },
    { number = 4,  name = "Monkeys",         firstDay = { 2025, 8, 29 } },
    { number = 5,  name = "Springbreak",     firstDay = { 2025, 8, 30 } },
    { number = 6,  name = "Cannonball Run",  firstDay = { 2025, 8, 31 } },
    { number = 7,  name = "Eisetes Cretor",  firstDay = { 2025, 8, 27 } },
    { number = 8,  name = "The Hamlet",      firstDay = { 2025, 8, 29 } },
    { number = 9,  name = "Quis-land",       firstDay = { 2025, 8, 31 } },
    { number = 10, name = "Agar Atoll",      firstDay = { 2025, 8, 25 } },
}

-- Returns the castaway bottles out on the day containing `now`, in bottle
-- order, e.g. { { number = 1, name = "Milky Bay" }, ... }.
function ArcSchedule.CastawaysToday(now)
    local today = math.floor(now / DAY)
    local out = {}
    for _, castaway in ipairs(ArcSchedule.CASTAWAYS) do
        local first = TimeUtil.DaysFromCivil(castaway.firstDay[1], castaway.firstDay[2], castaway.firstDay[3])
        if (today - first) % castaway.number == 0 then
            table.insert(out, { number = castaway.number, name = castaway.name })
        end
    end
    return out
end

return ArcSchedule

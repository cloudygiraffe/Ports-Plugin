-- Unit tests for the parts of the plugin that do not need the game client.
--
-- Run from the repository root with any Lua 5.1+ interpreter:
--     lua tests/run_tests.lua

package.path = "ports-helper/?.lua;" .. package.path

local TimeUtil = require("src/timeutil")
local Schedule = require("src/schedule")
local ArcSchedule = require("src/arc_schedule")
local RuneDate = require("src/runedate")

local passed, failed = 0, 0
local tests = {}

local function test(name, body)
    table.insert(tests, { name = name, body = body })
end

local function eq(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected)
            .. ", got " .. tostring(actual), 2)
    end
end

local function at(year, month, day, hour, minute)
    return TimeUtil.ToUnix(year, month, day, hour or 0, minute or 0, 0)
end

-- Thursday, October 22nd, 2026, 16:10 UTC (11:10 in Chicago).
local NOW = at(2026, 10, 22, 16, 10)

--------------------------------------------------------------------------------
-- Time helpers
--------------------------------------------------------------------------------

test("Weekdays: October 22nd, 2026 is a Thursday", function()
    eq(TimeUtil.Weekday(NOW), 4)
    eq(TimeUtil.Weekday(at(2026, 10, 26)), 1, "Monday")
    eq(TimeUtil.Weekday(at(2026, 10, 25, 23, 59)), 7, "Sunday")
end)

--------------------------------------------------------------------------------
-- Port schedule
--------------------------------------------------------------------------------

test("Next daily reset is the coming midnight UTC", function()
    eq(Schedule.NextDailyReset(NOW), at(2026, 10, 23))
end)

test("Next weekly reset is the coming Wednesday", function()
    eq(Schedule.NextWeeklyReset(NOW), at(2026, 10, 28))
    -- Exactly at Wednesday midnight, the next one is a week away.
    eq(Schedule.NextWeeklyReset(at(2026, 10, 28)), at(2026, 11, 4))
end)

test("Barmaid's Tip is available all Thursday", function()
    local tip = Schedule.BarmaidsTip(NOW)
    eq(tip.availableNow, true)
    eq(tip.endsAt, at(2026, 10, 23))
end)

test("Outside Thursday the Barmaid's Tip says when it comes back", function()
    local tip = Schedule.BarmaidsTip(at(2026, 10, 23, 1))
    eq(tip.availableNow, false)
    eq(tip.startsAt, at(2026, 10, 29))
end)

--------------------------------------------------------------------------------
-- RuneDate
--------------------------------------------------------------------------------

test("RuneDate 0 is February 27th, 2002", function()
    eq(RuneDate.ToUnix(0), at(2002, 2, 27))
end)

test("RuneDate matches the Wiki's January 1st, 2018 example (5787)", function()
    eq(RuneDate.FromUnix(at(2018, 1, 1)), 5787)
end)

test("The Captain's Log header is parsed", function()
    eq(RuneDate.ParseFromText("Captain's Log, Runedate 9034.67"), 9034.67)
    eq(RuneDate.ParseFromText("<col=ffffff>Captain's Log, Runedate: 9034</col>"), 9034)
    eq(RuneDate.ParseFromText("Runedate 12"), nil, "implausible values rejected")
    eq(RuneDate.ParseFromText("Crew roster"), nil)
end)

--------------------------------------------------------------------------------
-- Arc schedule
--------------------------------------------------------------------------------

test("Thursday's bird is the Cyclosis Cockatiel", function()
    eq(ArcSchedule.BirdToday(NOW).bird, "Cyclosis Cockatiel")
    eq(ArcSchedule.BirdToday(at(2026, 10, 26)).bird, "Crested Sillago Snatcher", "Monday")
end)

test("Bird spawns every 30 min 30 s from midnight and stays 10 minutes", function()
    local justAfterMidnight = ArcSchedule.BirdToday(at(2026, 10, 22, 0, 5))
    eq(justAfterMidnight.visibleNow, true)
    eq(justAfterMidnight.visibleUntil, at(2026, 10, 22, 0, 10))
    eq(justAfterMidnight.nextSpawn, at(2026, 10, 22) + 1830)

    local between = ArcSchedule.BirdToday(at(2026, 10, 22, 0, 20))
    eq(between.visibleNow, false)
    eq(between.nextSpawn, at(2026, 10, 22) + 1830)
end)

test("No spawn is promised past midnight", function()
    local late = ArcSchedule.BirdToday(at(2026, 10, 22, 23, 55))
    eq(late.nextSpawn, nil)
end)

local function castawayNames(now)
    local names = {}
    for _, castaway in ipairs(ArcSchedule.CastawaysToday(now)) do
        table.insert(names, castaway.name)
    end
    return table.concat(names, ", ")
end

-- These four days come from the Wiki's rotation, worked out independently.
test("Castaways match the Wiki rotation for late October 2026", function()
    eq(castawayNames(at(2026, 10, 22)), "Milky Bay, Christmas Island")
    eq(castawayNames(at(2026, 10, 27)), "Milky Bay, Goon Docks, Monkeys, The Hamlet")
    eq(castawayNames(at(2026, 10, 28)), "Milky Bay, Christmas Island, Eisetes Cretor, Quis-land")
    eq(castawayNames(at(2026, 10, 29)), "Milky Bay, Goon Docks, Springbreak, Agar Atoll")
end)

test("All ten castaways line up on the Wiki's sync day, October 3rd, 2029", function()
    eq(#ArcSchedule.CastawaysToday(at(2029, 10, 3)), 10)
end)

--------------------------------------------------------------------------------
-- Additional test files register themselves here.
--------------------------------------------------------------------------------

local extraFiles = { "tests/port_tests.lua", "tests/optimizer_tests.lua", "tests/story_tests.lua" }
for _, path in ipairs(extraFiles) do
    local chunk = loadfile(path)
    if chunk then
        chunk(test, eq)
    end
end

for _, case in ipairs(tests) do
    local ok, err = pcall(case.body)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. case.name .. "\n      " .. tostring(err))
    end
end

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end

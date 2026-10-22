-- Port state, warnings and reminders tests. Loaded by tests/run_tests.lua.
local test, eq = ...
local TimeUtil = require("src/timeutil")
local Schedule = require("src/schedule")
local PortState = require("src/port_state")
local Warnings = require("src/warnings")
local Reminders = require("src/reminders")

local function at(year, month, day, hour, minute)
    return TimeUtil.ToUnix(year, month, day, hour or 0, minute or 0, 0)
end

local function texts(list)
    local out = {}
    for _, item in ipairs(list) do table.insert(out, item.text) end
    return table.concat(out, " | ")
end

local function has(text, piece)
    return string.find(text, piece, 1, true) ~= nil
end

test("Portnight streak counts consecutive days, ending today or yesterday", function()
    PortState.Reset()
    for day = 100, 104 do PortState.RecordVoyageSent(day) end
    eq(PortState.Streak(104), 5, "sent today")
    eq(PortState.Streak(105), 5, "not yet today")
    eq(PortState.Streak(106), 0, "missed a day")
end)

test("Voyage days survive saving and loading", function()
    PortState.Reset()
    PortState.RecordVoyageSent(10)
    PortState.RecordVoyageSent(30)
    local saved = PortState.ExportVoyageDays(20)
    PortState.Reset()
    PortState.ImportVoyageDays(saved)
    eq(PortState.Streak(30), 1)
    eq(PortState.Streak(10), 0, "old days were dropped")
end)

test("Unused rerolls warn only in the last two hours before reset", function()
    local state = { rerolls = { voyage = 4, crew = 0 } }
    eq(texts(Warnings.Compute(state, at(2026, 10, 21, 12))), "")
    local late = texts(Warnings.Compute(state, at(2026, 10, 21, 23, 0)))
    eq(has(late, "lose 4 voyage rerolls at reset in 1 h"), true, late)
end)

test("Returned ships are the most urgent warning", function()
    local state = {
        ships = { { name = "The Lucky Lad", status = "returned" } },
        resources = { chimes = 199000 },
    }
    local list = Warnings.Compute(state, at(2026, 10, 21, 12))
    eq(has(list[1].text, "The Lucky Lad has returned"), true)
    eq(list[1].level, Warnings.URGENT)
end)

test("Trade goods near the cap are listed", function()
    local list = texts(Warnings.Compute({ resources = { tradeGoods = { plate = 245, spices = 100 } } }, nil))
    eq(has(list, "plate 245/250"), true, list)
    eq(has(list, "spices"), false, list)
end)

test("Chimes over the cap warn about the reset trim", function()
    local list = texts(Warnings.Compute({ resources = { chimes = 205000 } }, nil))
    eq(has(list, "over the 200,000 cap"), true, list)
end)

test("Thursday shows the Barmaid's Tip", function()
    local list = texts(Warnings.Compute({}, at(2026, 10, 22, 16)))
    eq(has(list, "Barmaid's Tip voyage is available today, for 8 h"), true, list)
end)

test("Reset reminder appears in the last hour and only once per reset", function()
    local settings = Reminders.DEFAULT_SETTINGS
    eq(#Reminders.Due(at(2026, 10, 21, 22, 0), settings, {}), 0, "two hours out")
    local due = Reminders.Due(at(2026, 10, 21, 23, 10), settings, {})
    eq(#due, 1)
    eq(due[1].key, "resetSoon")
    local shown = { resetSoon = due[1].occurrence }
    eq(#Reminders.Due(at(2026, 10, 21, 23, 30), settings, shown), 0, "already shown")
end)

test("Thursday tip and Wednesday weekly reminders", function()
    local settings = Reminders.DEFAULT_SETTINGS
    local thursday = Reminders.Due(at(2026, 10, 22, 9), settings, {})
    eq(thursday[1].key, "tip")
    local tuesday = Reminders.Due(at(2026, 10, 27, 9), settings, {})
    eq(tuesday[1].key, "weekly")
end)

test("Bird reminders are off by default and work when switched on", function()
    local now = at(2026, 10, 22, 0, 29) -- next spawn at 00:30:30
    eq(#Reminders.Due(now, Reminders.DEFAULT_SETTINGS, { tip = Schedule.BarmaidsTip(now).endsAt }), 0)
    local settings = { bird = true, birdLeadMinutes = 2 }
    local due = Reminders.Due(now, settings, {})
    eq(due[1].key, "bird")
    eq(has(due[1].text, "Cyclosis Cockatiel"), true)
end)

test("No clock, no reminders", function()
    eq(#Reminders.Due(nil, Reminders.DEFAULT_SETTINGS, {}), 0)
end)

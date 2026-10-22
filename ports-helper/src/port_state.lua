-- port_state.lua
-- What the plugin currently knows about the player's port.
--
-- Sources fill this in as they learn things: sources/port_vars.lua reads the
-- game's variables every few seconds, and sources/captains_log.lua reads open
-- port windows (once their IDs are known). Everything is optional: the panel
-- shows only what is known. This module is a plain store; it doesn't read the
-- game itself.
--
-- Fields (all may be nil):
--   rerolls           : { voyage = n, crew = n }       (port_vars; likely "left today")
--   voyageRequirement : { morale, combat, seafaring }  (port_vars; the voyage
--                       shown in the game's voyage list)
--   ships             : list of { name, status = "sailing"|"returned"|"damaged",
--                       returnsAt }                    (no source yet)
--   resources         : { chimes = n, tradeGoods = { plate = n, ... } } (no source yet)
--   captains, crew    : rosters for the optimizer, as Optimizer.NewJob expects
--   ship              : { morale, combat, seafaring } from the ship's parts
--                       (captains/crew/ship: no source yet; see README roadmap)
--   distance          : total distance sailed           (no source yet)
--   updatedAt         : Unix time of the last update (nil if the clock is unknown)
--
-- It also keeps the days on which a voyage was sent, for the Portnight
-- achievement (send at least one voyage a day, 14 days in a row).
-- TO DO: nothing calls RecordVoyageSent yet; a "voyage sent" signal from the
-- game variables is still to be found, so the panel hides the streak.

local PortState = {}

local state = {}
local voyageDays = {} -- set of day keys (Schedule.DayKey) with a voyage sent

-- Merges newly learned values into the state (shallow: each key replaces the
-- old value). `values` is a table of the fields above; `now` may be nil.
function PortState.Update(values, now)
    for key, value in pairs(values) do
        state[key] = value
    end
    state.updatedAt = now
end

-- Returns the current state table (read-only by convention).
function PortState.Get()
    return state
end

-- True once any voyage day has been recorded (until then a streak of 0
-- would just mean "not tracked yet").
function PortState.HasVoyageHistory()
    return next(voyageDays) ~= nil
end

-- Records that a voyage was sent on the given day (a Schedule.DayKey).
function PortState.RecordVoyageSent(dayKey)
    voyageDays[dayKey] = true
end

-- Days in a row, ending today (or yesterday, if nothing has been sent yet
-- today), with at least one voyage sent. `todayKey` is Schedule.DayKey(now).
-- Not sending yet today doesn't break the streak until the day is over.
function PortState.Streak(todayKey)
    local day = todayKey
    if not voyageDays[day] then
        day = day - 1
    end
    local streak = 0
    while voyageDays[day] do
        streak = streak + 1
        day = day - 1
    end
    return streak
end

-- For saving (storage.lua): the recorded day keys >= keepFromDay, sorted.
-- PersistentDB stores lists more predictably than number-keyed sets.
function PortState.ExportVoyageDays(keepFromDay)
    local list = {}
    for day in pairs(voyageDays) do
        if day >= keepFromDay then
            table.insert(list, day)
        end
    end
    table.sort(list)
    return list
end

-- Replaces the recorded days with a saved list (ignores non-numbers).
function PortState.ImportVoyageDays(list)
    voyageDays = {}
    for _, day in pairs(list or {}) do
        if type(day) == "number" then
            voyageDays[day] = true
        end
    end
end

-- Test helper.
function PortState.Reset()
    state = {}
    voyageDays = {}
end

return PortState

-- port_state.lua
-- What the plugin currently knows about the player's port.
--
-- Sources fill this in as they learn things (sources/log_reader.lua reads the
-- Captain's Log while it's open; game variables may follow once the discovery
-- tool finds them). Everything is optional: the panel shows only what is known.
--
-- Fields (all may be nil):
--   ships     : list of { name, status = "sailing"|"returned"|"damaged", returnsAt }
--   rerolls   : { voyage = n, crew = n }
--   resources : { chimes = n, tradeGoods = { plate = n, spices = n, ... } }
--   distance  : total distance sailed
--   updatedAt : Unix time of the last update
--
-- It also keeps the days on which a voyage was sent, for the Portnight
-- achievement (send at least one voyage a day, 14 days in a row).

local PortState = {}

local state = {}
local voyageDays = {} -- set of day keys (Schedule.DayKey) with a voyage sent

-- Merges newly learned values into the state.
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

-- Records that a voyage was sent on the given day.
function PortState.RecordVoyageSent(dayKey)
    voyageDays[dayKey] = true
end

-- Days in a row, ending today (or yesterday, if nothing has been sent yet
-- today), with at least one voyage sent.
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

-- For saving and loading (storage.lua). Day keys are stored as a list.
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

-- sources/port_vars.lua
-- Reads port values straight from the game's variables. No permissions and
-- no open windows needed for most of them.
--
-- Names and IDs come from the client's own variable lists (console commands
-- `pan VarPlayer` and `pan VarClient`, October 22nd, 2026 beta client). Values
-- marked CONFIRMED were checked against the game on the beta world; the rest
-- are best readings of the names and still need checking (tools/ports-discovery
-- prints them all; see docs/TESTING.md).
--
-- The game calls Morale "graft" internally (POP_*_GRAFT).

local PortVars = {}

PortVars.IDS = {
    -- VarClient: minutes since January 1st, 1970 UTC when the voyage list was
    -- opened. CONFIRMED: 29878112 = 11:32 a.m. Central, October 22nd, 2026,
    -- the moment a voyage was sent.
    timerStarted = { domain = "VarClient", id = 2624, name = "POP_VOYAGE_LIST_TIMER_STARTED" },

    -- VarPlayer varbits. TO CONFIRM: assumed to be rerolls left today.
    voyageRerolls = { domain = "VarPlayer", id = -17122, name = "POP_VOYAGE_REROLLS" },
    crewRerolls = { domain = "VarPlayer", id = -17462, name = "POP_CREW_REROLLS" },

    -- VarPlayer: the voyage currently shown in the voyage list. Requirements
    -- (DIFF) and your selected ship + crew totals (SHIP). CONFIRMED to update
    -- when a voyage is picked (combat 6500 / graft 6500 / seafaring 0).
    diffMorale = { domain = "VarPlayer", id = 3411, name = "POP_VOYAGE_LIST_DIFF_GRAFT" },
    diffCombat = { domain = "VarPlayer", id = 3412, name = "POP_VOYAGE_LIST_DIFF_COMBAT" },
    diffSeafaring = { domain = "VarPlayer", id = 3413, name = "POP_VOYAGE_LIST_DIFF_SEAFARING" },
    shipMorale = { domain = "VarPlayer", id = 3408, name = "POP_VOYAGE_LIST_SHIP_GRAFT" },
    shipCombat = { domain = "VarPlayer", id = 3409, name = "POP_VOYAGE_LIST_SHIP_COMBAT" },
    shipSeafaring = { domain = "VarPlayer", id = 3410, name = "POP_VOYAGE_LIST_SHIP_SEAFARING" },
    returnTimer = { domain = "VarPlayer", id = 3414, name = "POP_VOYAGE_LIST_TIMER" },
}

-- Sane range for "minutes since 1970": 2020 to 2045.
local MIN_MINUTES = 26297280
local MAX_MINUTES = 39444480

local function read(entry)
    local ok, value = pcall(function()
        return var[entry.domain].FromID(entry.id).value
    end)
    if ok and type(value) == "number" then
        return value
    end
    return nil
end

-- For tests: replaces the reader.
function PortVars.SetReader(reader)
    read = reader
end

-- Converts a "minutes since 1970" value to Unix seconds, or nil if it isn't
-- one (0 before the voyage list has ever been opened, for example).
function PortVars.MinutesToUnix(minutes)
    if type(minutes) ~= "number" or minutes < MIN_MINUTES or minutes > MAX_MINUTES then
        return nil
    end
    return minutes * 60
end

-- Unix time the voyage list was last opened, if the game has sent it.
function PortVars.TimerStartedUnix()
    return PortVars.MinutesToUnix(read(PortVars.IDS.timerStarted))
end

-- Reads everything with a known meaning. Returns a table of PortState fields
-- (only the ones that could be read).
function PortVars.Read()
    local fields = {}
    local voyage = read(PortVars.IDS.voyageRerolls)
    local crew = read(PortVars.IDS.crewRerolls)
    if voyage ~= nil or crew ~= nil then
        fields.rerolls = { voyage = voyage or 0, crew = crew or 0 }
    end

    local morale = read(PortVars.IDS.diffMorale)
    local combat = read(PortVars.IDS.diffCombat)
    local seafaring = read(PortVars.IDS.diffSeafaring)
    if (morale or 0) + (combat or 0) + (seafaring or 0) > 0 then
        fields.voyageRequirement = { morale = morale or 0, combat = combat or 0, seafaring = seafaring or 0 }
    end
    return fields
end

-- True if a VarTransmit event is one of ours (any POP_ variable).
function PortVars.IsPortVariable(event)
    local ok, name = pcall(function() return event.var.configName end)
    return ok and type(name) == "string" and string.sub(name, 1, 4) == "POP_"
end

-- True if a VarTransmit event is the voyage-list timer (a fresh clock reading).
function PortVars.IsTimerStarted(event)
    local ok, name = pcall(function() return event.var.configName end)
    return ok and name == PortVars.IDS.timerStarted.name
end

return PortVars

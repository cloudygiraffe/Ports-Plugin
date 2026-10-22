-- sources/port_vars.lua
-- Reads port values straight from the game's variables. No permissions and
-- no open windows needed for most of them.
--
-- Names and IDs come from the client's own variable lists (console commands
-- `pan VarPlayer` and `pan VarClient`, October 22nd, 2026 beta client); none
-- of this is in Jagex's documentation, and IDs may change with game updates.
-- Values marked CONFIRMED were checked against the game on the beta world;
-- the rest are best readings of the names and still need checking
-- (tools/ports-discovery prints them all; see docs/TESTING.md). The full list
-- of port variables found so far is in docs/VARIABLES.md.
--
-- Varbits have negative IDs in the client's list, and var.VarPlayer.FromID()
-- accepts them as-is (observed on the beta world).
--
-- The game appears to call Morale "graft" internally (POP_*_GRAFT): the
-- voyage list's three requirements are GRAFT, COMBAT and SEAFARING. TO
-- CONFIRM against the in-game voyage screen.

local PortVars = {}

PortVars.IDS = {
    -- VarClient: minutes since January 1st, 1970 UTC, stamped when the voyage
    -- list is opened. CONFIRMED: read 29878112 = 16:32 UTC on October 22nd,
    -- 2026, the minute a voyage was sent on the beta world. main.lua uses its
    -- VarTransmit change as a clock source.
    timerStarted = { domain = "VarClient", id = 2624, name = "POP_VOYAGE_LIST_TIMER_STARTED" },

    -- VarPlayer varbits (7 and 4 bits): voyage and crew rerolls left today;
    -- they feed the "lost at reset" warning. Voyage rerolls LIKELY: the
    -- holding VarPlayer 3403 went 8847 -> 8846, whose low 7 bits are 15 -> 14,
    -- matching the 15 daily rerolls. Crew rerolls TO CONFIRM.
    voyageRerolls = { domain = "VarPlayer", id = -17122, name = "POP_VOYAGE_REROLLS" },
    crewRerolls = { domain = "VarPlayer", id = -17462, name = "POP_CREW_REROLLS" },

    -- VarPlayer: the voyage currently shown in the voyage list. Requirements
    -- (DIFF) and your selected ship + crew totals (SHIP). CONFIRMED to update
    -- when a voyage is picked (combat 6500 / graft 6500 / seafaring 0).
    -- DIFF_* fill in the crew optimizer; SHIP_* and the return timer are read
    -- by nothing yet (kept here as the known IDs).
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

-- Reads one variable's value, or nil if it can't be read (not logged in, ID
-- unknown to this client, ...). Replaceable for tests via SetReader.
local function read(entry)
    local ok, value = pcall(function()
        return var[entry.domain].FromID(entry.id).value
    end)
    if ok and type(value) == "number" then
        return value
    end
    return nil
end

-- For tests: replaces the reader with function(entry) -> number|nil.
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
-- Unused by main.lua (which only trusts a fresh change); kept for tools/tests.
function PortVars.TimerStartedUnix()
    return PortVars.MinutesToUnix(read(PortVars.IDS.timerStarted))
end

-- Reads everything with a known meaning. Returns a table of PortState fields
-- (only the ones that could be read; {} before login):
--   rerolls           = { voyage, crew }  if either reroll varbit is readable
--   voyageRequirement = { morale, combat, seafaring }  if any is above 0
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

-- True if a VarTransmit event is one of ours (any POP_ variable). Not used by
-- main.lua yet (it polls instead); handy for reacting to changes instantly.
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

-- sources/captains_log.lua
-- Reads the Captain's Log and the port's own windows while they are open.
--
-- STATUS: scaffold, inactive. WINDOW_IDS and PARSERS are both empty, so
-- IsConfigured() is false and main.lua skips this source. Most port data now
-- comes from game variables instead (sources/port_vars.lua), which needs no
-- open window; this source stays for what the variables don't cover.
--
-- What it does once WINDOW_IDS is filled in:
--   * The Captain's Log header shows the RuneDate with the fraction of the
--     day ("Captain's Log, Runedate 9034.67"), a clock with no permissions
--     (Clock.QUALITY.RUNEDATE, the lowest-ranked source).
--   * Any parser in PARSERS gets the window's text and returns PortState
--     fields. Candidates if the variables fall short: ship status and return
--     times (Log page 1), resources and trade goods (page 4), distance and
--     port score (page 3), crew stats (the Crew Roster).
--
-- The interface IDs aren't documented. tools/ports-discovery prints
-- "PORT WINDOW? interface=..." with a text sample for any open window that
-- looks like a port window; put those IDs in WINDOW_IDS.

local WindowText = require("src/sources/window_text")
local RuneDate = require("src/runedate")

local CaptainsLog = {}

-- Interface IDs reported by tools/ports-discovery, e.g. { 1234, 1235 }.
local WINDOW_IDS = {
}

-- Each parser takes the list of text strings from an open window and returns
-- a table of PortState fields it found, or nil. Add new ones here.
local PARSERS = {
}

-- Replaces the window IDs (used by tests).
function CaptainsLog.SetWindowIds(ids)
    WINDOW_IDS = ids
end

-- True once at least one window ID is known (otherwise main.lua skips this).
function CaptainsLog.IsConfigured()
    return #WINDOW_IDS > 0
end

-- Finds a RuneDate in a list of strings. Pure: unit tested.
function CaptainsLog.FindRuneDate(texts)
    for _, text in ipairs(texts or {}) do
        local value = RuneDate.ParseFromText(text)
        if value then
            return value
        end
    end
    return nil
end

-- Reads every open port window (a few hundred component reads; main.lua calls
-- it every 3rd server tick). Parser errors are caught and ignored. Returns:
--   unixTime : the time from the RuneDate header, or nil
--   fields   : PortState fields found by the parsers (may be empty)
-- or nil, nil if none of the windows are open.
function CaptainsLog.Read()
    local anyOpen = false
    local unixTime = nil
    local fields = {}
    for _, interfaceId in ipairs(WINDOW_IDS) do
        local texts = WindowText.Read(interfaceId)
        if texts then
            anyOpen = true
            local runeDate = CaptainsLog.FindRuneDate(texts)
            if runeDate then
                unixTime = RuneDate.EstimateNow(runeDate)
            end
            for _, parser in ipairs(PARSERS) do
                local ok, found = pcall(parser, texts)
                if ok and type(found) == "table" then
                    for key, value in pairs(found) do
                        fields[key] = value
                    end
                end
            end
        end
    end
    if not anyOpen then
        return nil, nil
    end
    return unixTime, fields
end

return CaptainsLog

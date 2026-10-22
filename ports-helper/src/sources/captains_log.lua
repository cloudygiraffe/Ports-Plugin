-- sources/captains_log.lua
-- Reads the Captain's Log and the port's own windows while they are open.
--
-- What works now:
--   * The Captain's Log header shows the RuneDate with the fraction of the
--     day ("Captain's Log, Runedate 9034.67"). That gives the plugin a clock
--     with no permissions at all.
--
-- What comes next (once tools/ports-discovery has shown what these windows
-- contain on the beta world):
--   * ship status and return times (Captain's Log, page 1)
--   * resources and trade goods (page 4)
--   * distance and port score (page 3)
--   * rerolls left (the Voyages window)
--   * captain and crew stats (the Crew Roster), for the crew optimizer
-- Each one is a small parser added to PARSERS below; the text is already
-- collected for them.
--
-- STATUS: the window IDs are not documented. Fill in WINDOW_IDS from the
-- discovery tool's "PORT WINDOW?" lines.

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

-- Reads every open port window. Returns:
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

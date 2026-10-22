-- runedate.lua
-- Converts between the RuneDate and Unix time.
--
-- The RuneDate counts days since February 27th, 2002, 00:00 UTC, with the
-- fraction of the current day after the decimal point. The Captain's Log
-- header shows it ("Captain's Log, Runedate 9033.46"), which gives the plugin
-- a clock without any permissions: reading that header while the Log is open
-- tells us the time to within about 7 minutes (see EstimateNow), which is
-- enough for reset countdowns until a better source comes along.
--
-- Worked example: RuneDate 9034.67 = 1014768000 + 9034.67 x 86400
--                = 1795363488 Unix seconds.

local RuneDate = {}

RuneDate.UNIX_AT_DAY_ZERO = 1014768000 -- February 27th, 2002, 00:00 UTC
local DAY = 86400

-- Unix seconds for a RuneDate (whole or fractional).
function RuneDate.ToUnix(runeDate)
    return RuneDate.UNIX_AT_DAY_ZERO + runeDate * DAY
end

-- The Wiki says the displayed RuneDate is rounded DOWN to two decimals
-- (steps of 0.01 day = 864 s, about 14.4 minutes), so the real time is up to
-- one step later. Adding half a step (432 s) puts the estimate in the middle:
-- within about 7 minutes either way.
RuneDate.HALF_DISPLAY_STEP_SECONDS = 0.005 * DAY

-- Best estimate of "now" from a RuneDate read off the Captain's Log.
function RuneDate.EstimateNow(displayedRuneDate)
    return RuneDate.ToUnix(displayedRuneDate) + RuneDate.HALF_DISPLAY_STEP_SECONDS
end

-- RuneDate (with fraction) for Unix seconds.
function RuneDate.FromUnix(unixSeconds)
    return (unixSeconds - RuneDate.UNIX_AT_DAY_ZERO) / DAY
end

-- Finds "Runedate 9033.46" (any case, optional colon, with or without a
-- fraction) in a piece of text and returns the number, or nil.
-- Pure function: unit tested.
function RuneDate.ParseFromText(text)
    if type(text) ~= "string" then
        return nil
    end
    local plain = string.gsub(text, "<[^>]*>", " ")
    local number = string.match(string.lower(plain), "runedate:?%s*(%d+%.?%d*)")
    if number == nil then
        return nil
    end
    local value = tonumber(number)
    -- Sanity check: RuneDate 6500 is late 2019 and 36000 is around 2100, so
    -- anything outside that range is a stray number, not today's date.
    if value == nil or value < 6500 or value > 36000 then
        return nil
    end
    return value
end

return RuneDate

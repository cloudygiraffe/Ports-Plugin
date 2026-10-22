-- runedate.lua
-- Converts between the RuneDate and Unix time.
--
-- The RuneDate counts days since February 27th, 2002, 00:00 UTC, with the
-- fraction of the current day after the decimal point. The Captain's Log
-- header shows it ("Captain's Log, Runedate 9033.46"), which gives the plugin
-- a clock without any permissions: reading that header while the Log is open
-- tells us the time to within about 15 minutes, and the countdowns only need
-- to be that accurate until a better source comes along.

local RuneDate = {}

RuneDate.UNIX_AT_DAY_ZERO = 1014768000 -- February 27th, 2002, 00:00 UTC
local DAY = 86400

-- Unix seconds for a RuneDate (whole or fractional).
function RuneDate.ToUnix(runeDate)
    return RuneDate.UNIX_AT_DAY_ZERO + runeDate * DAY
end

-- The Wiki says the displayed RuneDate is rounded DOWN to two decimals
-- (steps of about 14.4 minutes), so the real time is up to one step later.
-- Adding half a step puts the estimate in the middle: within about 7 minutes.
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
    -- Sanity check: between 2020 and 2100, to reject stray numbers.
    if value == nil or value < 6500 or value > 36000 then
        return nil
    end
    return value
end

return RuneDate

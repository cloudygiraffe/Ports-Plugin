-- warnings.lua
-- Turns the schedule and port state into short, prioritised warnings, such
-- as rerolls about to be lost or a resource near its cap. Pure functions:
-- unit tested without the game.
--
-- Caps (RuneScape Wiki, docs/RESEARCH.md):
--   * Chimes: soft cap 200,000; anything over is trimmed at the daily reset.
--   * Trade goods: hard cap 250 each; extra is lost when claiming a voyage.

local Schedule = require("src/schedule")
local TimeUtil = require("src/timeutil")

local Warnings = {}

Warnings.CHIME_CAP = 200000
Warnings.TRADE_GOOD_CAP = 250
Warnings.REROLL_WARNING_SECONDS = 2 * 3600 -- warn this long before reset

-- Warning levels, most urgent first.
Warnings.URGENT = 1
Warnings.SOON = 2
Warnings.INFO = 3

-- Returns a list of { level, text }, most urgent first.
--   state : PortState.Get()
--   now   : Unix time, or nil if unknown (time-based warnings are skipped)
function Warnings.Compute(state, now)
    local list = {}
    local function warn(level, text)
        table.insert(list, { level = level, text = text })
    end

    -- Ships waiting to be claimed earn nothing.
    for _, ship in ipairs(state.ships or {}) do
        if ship.status == "returned" then
            warn(Warnings.URGENT, (ship.name or "A ship") .. " has returned. Claim it and send it out again.")
        elseif ship.status == "damaged" then
            warn(Warnings.SOON, (ship.name or "A ship") .. " is damaged and needs repairing.")
        end
    end

    -- Rerolls are lost at the daily reset.
    if now and state.rerolls then
        local untilReset = Schedule.NextDailyReset(now) - now
        local voyage = state.rerolls.voyage or 0
        local crew = state.rerolls.crew or 0
        if untilReset <= Warnings.REROLL_WARNING_SECONDS and (voyage > 0 or crew > 0) then
            local parts = {}
            if voyage > 0 then table.insert(parts, voyage .. " voyage") end
            if crew > 0 then table.insert(parts, crew .. " crew") end
            warn(Warnings.URGENT, "You'll lose " .. table.concat(parts, " and ")
                .. " rerolls at reset in " .. TimeUtil.FormatDuration(untilReset) .. ".")
        end
    end

    -- Resource caps.
    local resources = state.resources or {}
    if resources.chimes and resources.chimes > Warnings.CHIME_CAP then
        warn(Warnings.SOON, "Chimes are over the 200,000 cap; the extra is trimmed at reset.")
    elseif resources.chimes and resources.chimes >= Warnings.CHIME_CAP * 0.95 then
        warn(Warnings.INFO, "Chimes are close to the 200,000 cap.")
    end
    local goodsNearCap = {}
    for name, amount in pairs(resources.tradeGoods or {}) do
        if amount >= Warnings.TRADE_GOOD_CAP - 10 then
            table.insert(goodsNearCap, name .. " " .. amount .. "/250")
        end
    end
    table.sort(goodsNearCap)
    if #goodsNearCap > 0 then
        warn(Warnings.SOON, "Trade goods near the 250 cap (extra is lost on claiming): "
            .. table.concat(goodsNearCap, ", ") .. ".")
    end

    -- The Barmaid's Tip only lasts until Thursday's reset.
    if now then
        local tip = Schedule.BarmaidsTip(now)
        if tip.availableNow then
            warn(Warnings.INFO, "The Barmaid's Tip voyage is available today, for "
                .. TimeUtil.FormatDuration(tip.endsAt - now) .. ".")
        end
    end

    table.sort(list, function(a, b) return a.level < b.level end)
    return list
end

return Warnings

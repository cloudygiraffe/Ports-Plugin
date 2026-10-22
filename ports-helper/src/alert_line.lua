-- alert_line.lua
-- A short-lived gold line near the top of the game screen for reminders,
-- on the layer the API provides for plugins. It never blocks clicks
-- (clickthrough) and hides itself after SHOW_SECONDS.
--
-- The component is created lazily and recreated if the game rebuilds its
-- interfaces (any error while changing it drops the reference).

local Clock = require("src/clock")

local AlertLine = {}
AlertLine.__index = AlertLine

local WIDTH, HEIGHT, TOP = 520, 22, 30
local SHOW_SECONDS = 12

-- Creates an alert line. Nothing is drawn until Show() is called.
function AlertLine.new()
    return setmetatable({ text = nil, hideTick = nil }, AlertLine)
end

-- Creates the text component if it doesn't exist yet. Returns true if ready.
function AlertLine:ensureBuilt()
    if self.text ~= nil then
        return true
    end
    local parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
    if parent == nil then
        return false
    end
    local ok = pcall(function()
        local text = ui.Text.new(parent)
        text:SetSize(WIDTH, HEIGHT)
        text:SetPos(0, TOP, 0.5, 0.0, -0.5, 0.0) -- centred horizontally
        text.font = id.Font.MUSEO_SANS_15PT_REGULAR
        text.isShadowed = true
        text:AlignTo(ui.AlignMode.CENTRE)
        text.clickthrough = true
        text.hidden = true
        self.text = text
    end)
    if not ok then
        self.text = nil
    end
    return ok
end

-- Runs a change on the component; forgets it if the game rebuilt its
-- interface, so the next call creates a fresh one.
function AlertLine:apply(change)
    if not self:ensureBuilt() then
        return
    end
    if not pcall(change) then
        self.text = nil
    end
end

-- Shows `message` (plain text; it's coloured gold here) for SHOW_SECONDS.
function AlertLine:Show(message)
    self:apply(function()
        self.text.content = "<col=ffd24a>" .. message .. "</col>"
        self.text.hidden = false
    end)
    self.hideTick = Clock.CurrentTick() + Clock.SecondsToTicks(SHOW_SECONDS)
end

-- Call every server tick: hides the line once its time is up.
function AlertLine:Update()
    if self.hideTick and Clock.CurrentTick() >= self.hideTick then
        self.hideTick = nil
        self:apply(function() self.text.hidden = true end)
    end
end

return AlertLine

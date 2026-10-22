-- sources/window_text.lua
-- Collects the text shown in one of the game's own windows (an "interface"),
-- so other modules can look for numbers and names in it. Read-only: it never
-- clicks, scrolls or changes anything.
--
-- Plugins can find a loaded window with ui.Interfaces:GetInterface(id) and
-- walk its components with IterateStaticComponents / IterateDynamicComponents
-- (documented on the Component Collection page). The docs don't say whether
-- a window object itself can list its components, so if that fails this
-- falls back to asking for each fixed component number in turn.

local WindowText = {}

local MAX_COMPONENTS = 4000 -- safety limit per read
local MAX_STATIC_ID = 400   -- fallback range of fixed component numbers

-- The component's text, or nil if it has none (or isn't a text component).
local function readText(component)
    local ok, content = pcall(function() return component.content end)
    if ok and type(content) == "string" and content ~= "" then
        return content
    end
    return nil
end

-- Depth-first walk of a component and its children, appending every text
-- found to `out`. `budget.remaining` caps the total components visited, so a
-- huge window can't stall a tick.
local function walk(component, out, budget)
    if budget.remaining <= 0 then
        return
    end
    budget.remaining = budget.remaining - 1
    local text = readText(component)
    if text then
        table.insert(out, text)
    end
    local function child(childComponent)
        walk(childComponent, out, budget)
        return budget.remaining <= 0 -- true stops the iteration
    end
    pcall(function() component:IterateStaticComponents(child) end)
    pcall(function() component:IterateDynamicComponents(child) end)
end

-- True if the window with this ID is currently open.
function WindowText.IsOpen(interfaceId)
    local ok, interface = pcall(function()
        return ui.Interfaces:GetInterface(interfaceId)
    end)
    return ok and interface ~= nil
end

-- Returns a list of every text string in the window, in the order found, or
-- nil if the window isn't open.
function WindowText.Read(interfaceId)
    local ok, interface = pcall(function()
        return ui.Interfaces:GetInterface(interfaceId)
    end)
    if not ok or interface == nil then
        return nil
    end
    local out, budget = {}, { remaining = MAX_COMPONENTS }
    local function top(component)
        walk(component, out, budget)
        return budget.remaining <= 0
    end
    local listed = pcall(function() interface:IterateStaticComponents(top) end)
    if not listed then
        for staticId = 0, MAX_STATIC_ID do
            local okComponent, component = pcall(function()
                return ui.Interfaces:GetComponent(interfaceId, staticId)
            end)
            if okComponent and component ~= nil and top(component) then
                break
            end
        end
    end
    return out
end

return WindowText

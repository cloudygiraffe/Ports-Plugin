-- End-to-end test of main.lua against a fake version of the game's plugin API.
--
-- Run from the repository root:
--     lua tests/mock_game_test.lua
--
-- The fakes only implement what the plugin uses, with the names documented at
-- developer.runescape.com. Reading an unknown API member, or setting an
-- undocumented component property, raises an error.

package.path = "ports-helper/?.lua;" .. package.path

local failures = 0
local function check(condition, message)
    if not condition then
        failures = failures + 1
        print("FAIL: " .. message)
    end
end
local function has(text, piece)
    return type(text) == "string" and string.find(text, piece, 1, true) ~= nil
end

local function strict(name, fields)
    return setmetatable(fields, {
        __index = function(_, key)
            error("plugin used unknown API member " .. name .. "." .. tostring(key), 2)
        end,
    })
end

-- Events ----------------------------------------------------------------------
local subscribers = {}
local function fakeEvent(eventName)
    subscribers[eventName] = {}
    return strict("Event." .. eventName, {
        Subscribe = function(refName, callback) subscribers[eventName][refName] = callback end,
        Unsubscribe = function(refName) subscribers[eventName][refName] = nil end,
    })
end
local function fire(eventName, payload)
    for _, callback in pairs(subscribers[eventName]) do callback(payload) end
end
Event = strict("Event", {
    Logic = fakeEvent("Logic"),
    ServerLogic = fakeEvent("ServerLogic"),
    ContentLayerReady = fakeEvent("ContentLayerReady"),
    ChatMessage = fakeEvent("ChatMessage"),
    VarTransmit = fakeEvent("VarTransmit"),
})

-- UI ---------------------------------------------------------------------------
local DOCUMENTED_PROPERTIES = {
    Layer = {},
    Text = { content = true, font = true, maxLines = true, hidden = true,
             isShadowed = true, clickthrough = true },
    InputField = { content = true, emptyText = true, stylesheetID = true, hidden = true },
    List = { stylesheetID = true, dropdownMaxVisibleEntries = true, hidden = true },
    Button = { label = true, stylesheetID = true, hidden = true },
    Check = { label = true, value = true, stylesheetID = true, hidden = true },
}
local components = {}
local function fakeComponent(kind)
    local state = { kind = kind, hooks = {}, visibleGlobal = true, entries = {} }
    local methods = {}
    function methods.SetPos(_, ...) end
    function methods.SetSize(_, ...) end
    function methods.AlignTo(_, ...) end
    function methods.MoveToFront(_) end
    function methods.Subscribe(_, hook, callback) state.hooks[hook] = callback end
    function methods.Setup(_, visibility, filter, maxLength)
        assert(visibility ~= nil and filter ~= nil and maxLength ~= nil, "Setup needs three arguments")
    end
    function methods.Add(_, label, entryId) table.insert(state.entries, { label = label, id = entryId }) return true end
    function methods.SetEntrySelected(_, entryId, selected) state.selected = selected and entryId or nil end
    local component = setmetatable({}, {
        __index = function(_, key)
            if methods[key] then return methods[key] end
            if key == "selectedEntries" then
                return state.selected and { { id = state.selected } } or {}
            end
            return state[key]
        end,
        __newindex = function(_, key, value)
            if not DOCUMENTED_PROPERTIES[kind][key] then
                error("plugin set undocumented property " .. kind .. "." .. tostring(key), 2)
            end
            state[key] = value
        end,
    })
    table.insert(components, component)
    return component
end
local function constructor(kind)
    return strict("ui." .. kind, { new = function() return fakeComponent(kind) end })
end
local pluginLayer = fakeComponent("Layer")
ui = strict("ui", {
    Interfaces = strict("ui.Interfaces", {
        GetComponent = function(_, componentId) return componentId == "PLUGIN_LAYER" and pluginLayer or nil end,
        GetInterface = function() return nil end,
    }),
    Text = constructor("Text"), InputField = constructor("InputField"), List = constructor("List"),
    Button = constructor("Button"), Check = constructor("Check"),
    AlignMode = strict("ui.AlignMode", { TOPLEFT = 0, CENTRE = 1, BOTTOMRIGHT = 2, JUSTIFY = 3 }),
    Hook = strict("ui.Hook", { ONBUTTONPRESSED = "ONBUTTONPRESSED", ONSELECTIONCHANGED = "ONSELECTIONCHANGED" }),
    TextContentVisibilityMode = strict("ui.TextContentVisibilityMode", { VISIBLE = 0, SHOW_LAST = 1, HIDDEN = 2 }),
    InputFieldFilterMode = strict("ui.InputFieldFilterMode",
        { NONE = 0, ALPHANUMERIC = 1, NUMERIC = 2, QUANTITY = 3, NUMBERS_AS_TEXT = 4 }),
})
id = strict("id", {
    Font = strict("id.Font", { MUSEO_SANS_15PT_REGULAR = 1 }),
    Component = strict("id.Component", { TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP = "PLUGIN_LAYER" }),
    StyleSheet = strict("id.StyleSheet", {
        INPUT_DEFAULT = 1, DROPDOWN_DEFAULT = 2, BUTTON_DEFAULT = 3, CHECKBOX_DEFAULT = 4,
    }),
})

-- Services ---------------------------------------------------------------------
Player = strict("Player", {
    IsAvailable = function() return true end,
    GetEntity = function() return { displayName = "CloudGiraffe" } end,
})
local database = {}
PersistentDB = strict("PersistentDB", {
    GetStructuredData = function(_, key) return database[key] end,
    SetStructuredData = function(_, key, value) database[key] = value return true end,
})
PluginPermissions = strict("PluginPermissions", { httpAccess = "h", chatAccess = "c", trackingAccess = "t" })
Plugin = strict("Plugin", { HasPermission = function() return true end })
local chatLines = {}
-- Port variables: the voyage list is showing a 6500 Morale / 6500 Combat voyage.
local portVars = { [3411] = 6500, [3412] = 6500, [3413] = 0, [-17122] = 2, [-17462] = 1 }
var = strict("var", {
    VarPlayer = strict("var.VarPlayer", {
        FromID = function(variableId)
            if portVars[variableId] == nil then error("unknown variable") end
            return { value = portVars[variableId] }
        end,
    }),
    VarClient = strict("var.VarClient", {
        FromID = function() error("unknown variable") end,
    }),
})

Chat = strict("Chat", { AddMessage = function(message) table.insert(chatLines, message) end })

-- The game clock: 23:10 UTC on Wednesday, October 21st, 2026 (50 min to reset).
local START = 1792624200
os.time = function() return START end

-- Run ------------------------------------------------------------------------------
dofile("ports-helper/main.lua")

local tick = 0
local function advanceSeconds(seconds)
    for _ = 1, math.floor(seconds / 0.6) do
        tick = tick + 30
        fire("Logic", { logicTick = 100000 + tick })
        fire("ServerLogic", nil)
    end
end
advanceSeconds(6)

-- The reset reminder fires within the last hour.
local alertText
for _, component in ipairs(components) do
    if component.kind == "Text" and has(component.content, "Ports resets in") then
        alertText = component.content
    end
end
check(alertText ~= nil, "reset reminder shown on screen")
check(#chatLines >= 1 and has(chatLines[1], "rerolls"), "reset reminder posted to chat")

-- Open the panel: overview shows the countdowns.
local root = fakeComponent("Layer")
fire("ContentLayerReady", { component = root })
local body
for _, component in ipairs(components) do
    if component.kind == "Text" and component.maxLines == 22 then body = component end
end
check(has(body.content, "Daily reset in 49 min"), "overview shows the daily reset (got: " .. tostring(body.content) .. ")")
check(has(body.content, "Streak tracking starts"), "no fake 0-day streak before voyage data exists")

-- Switch to Arc today.
local sections
for _, component in ipairs(components) do
    if component.kind == "List" and sections == nil then sections = component end
end
sections:SetEntrySelected(2, true)
sections.hooks.ONSELECTIONCHANGED(sections, 2, 1)
check(has(body.content, "Gongdung Peligorn"), "Wednesday's bird shown")
check(has(body.content, "Milky Bay"), "castaways shown")

-- Crew optimizer with a roster supplied as a parser would.
require("src/port_state").Update({
    captains = { { name = "Cap", level = 3, morale = 300, combat = 300, seafaring = 300 } },
    crew = {
        { name = "A", level = 1, morale = 200, combat = 0, seafaring = 0 },
        { name = "B", level = 2, morale = 0, combat = 200, seafaring = 0 },
        { name = "C", level = 3, morale = 0, combat = 0, seafaring = 200 },
        { name = "D", level = 9, morale = 300, combat = 300, seafaring = 300 },
    },
    ship = { morale = 100, combat = 100, seafaring = 0 },
}, START)
sections:SetEntrySelected(3, true)
sections.hooks.ONSELECTIONCHANGED(sections, 3, 1)
local find, inputs = nil, {}
for _, component in ipairs(components) do
    if component.kind == "Button" and component.label == "Find best crew" then find = component end
    if component.kind == "InputField" then table.insert(inputs, component) end
end
check(find.hidden == false and inputs[1].hidden == false, "crew controls visible in the crew section")
check(inputs[1].content == "6500" and inputs[2].content == "6500" and inputs[3].content == "0",
    "crew inputs filled from the voyage the game is showing (got " .. tostring(inputs[1].content) .. ")")
sections:SetEntrySelected(1, true)
sections.hooks.ONSELECTIONCHANGED(sections, 1, 1)
check(has(body.content, "2 voyage"), "overview warns about rerolls read from the game (got: " .. tostring(body.content) .. ")")
sections:SetEntrySelected(3, true)
sections.hooks.ONSELECTIONCHANGED(sections, 3, 1)
inputs[1].content, inputs[2].content, inputs[3].content = "1000", "900", "800"
find.hooks.ONBUTTONPRESSED(find)
advanceSeconds(2)
check(has(body.content, "Best success chance"), "optimizer result shown (got: " .. tostring(body.content) .. ")")
check(has(body.content, "Captain: Cap"), "captain listed")

-- Story helper: pick a trio from the topic dropdown.
sections:SetEntrySelected(4, true)
sections.hooks.ONSELECTIONCHANGED(sections, 4, 1)
local storyList
for _, component in ipairs(components) do
    if component.kind == "List" and component.dropdownMaxVisibleEntries == 10 then storyList = component end
end
check(storyList and storyList.hidden == false, "story dropdown visible in the story section")
check(find.hidden == true, "crew controls hidden outside the crew section")
check(has(body.content, "Port icons"), "story section opens on the icon overview")
storyList:SetEntrySelected(14, true)
storyList.hooks.ONSELECTIONCHANGED(storyList, 14, 1)
check(has(body.content, "Trio storyline: Quin"), "Quin trio page shown (got: " .. tostring(body.content) .. ")")
check(database.storyTarget and database.storyTarget.key == "trio:quin", "story topic saved")

-- Reminder settings are saved.
sections:SetEntrySelected(5, true)
sections.hooks.ONSELECTIONCHANGED(sections, 5, 1)
local birdBox
for _, component in ipairs(components) do
    if component.kind == "Check" and component.label == "Arc bird about to appear" then birdBox = component end
end
check(birdBox.hidden == false, "reminder checkboxes visible in the reminders section")
birdBox.value = true
birdBox.hooks.ONBUTTONPRESSED(birdBox, 1)
check(database.reminderSettings and database.reminderSettings.bird == true, "bird reminder setting saved")

print(failures == 0 and "mock game test passed" or (failures .. " check(s) failed"))
if failures > 0 then os.exit(1) end

-- panel.lua
-- The plugin's window, opened from its icon in the Plugins ribbon window.
--
-- A section dropdown at the top switches between:
--   1. Port overview   : resets, warnings, Portnight streak
--   2. Arc today       : today's bird and castaway bottles
--   3. Crew optimizer  : voyage stats in, best captain and crew out
--   4. Story helper    : port icons, storylines and which capes need them
--   5. Reminders       : which reminders to show
-- Each section is mostly one block of text built by display.lua or story.lua.
-- The crew inputs, the story topic dropdown and the reminder checkboxes sit in
-- a "controls" row that is only shown in their own section.
--
-- The game hands the plugin an empty layer each time the window is shown
-- (ContentLayerReady), so Build() recreates everything; main.lua keeps state.

local Panel = {}
Panel.__index = Panel

Panel.SECTIONS = {
    { id = 1, key = "overview", label = "Port overview" },
    { id = 2, key = "arc",      label = "Arc today" },
    { id = 3, key = "crew",     label = "Crew optimizer" },
    { id = 4, key = "story",    label = "Story helper" },
    { id = 5, key = "settings", label = "Reminders" },
}

-- Reminder checkboxes shown in the Reminders section: settings key -> label.
Panel.REMINDER_CHECKS = {
    { key = "resetSoon", label = "1 hour before daily reset" },
    { key = "tip",       label = "Barmaid's Tip on Thursdays" },
    { key = "weekly",    label = "Day before Wednesday reset" },
    { key = "bird",      label = "Arc bird about to appear" },
}

local FONT = id.Font.MUSEO_SANS_15PT_REGULAR
local LINE = 20
local CONTROL = 28
local BODY_ROWS = 22
local CONTROLS_TOP = 58
local BODY_TOP = 150

-- callbacks:
--   onSection(sectionKey)
--   onFindCrew(morale, combat, seafaring, isResourceVoyage)
--   onSetting(key, value)
--   onStoryTarget(targetKey)
-- storyTargets: { { id, key, label }, ... } for the Story helper dropdown.
function Panel.new(callbacks, storyTargets)
    local self = setmetatable({}, Panel)
    self.callbacks = callbacks
    self.storyTargets = storyTargets or {}
    self.root = nil
    self.parts = {}
    return self
end

local function sectionByKey(key)
    for _, section in ipairs(Panel.SECTIONS) do
        if section.key == key then return section end
    end
    return Panel.SECTIONS[1]
end

local function addText(parent, x, y, widthFraction, rows)
    local text = ui.Text.new(parent)
    text:SetPos(0, y, x, 0.0)
    text:SetSize(0, LINE * rows, widthFraction, 0.0)
    text.font = FONT
    text.maxLines = rows
    -- TOPLEFT means "left" horizontally and "top" vertically.
    text:AlignTo(ui.AlignMode.TOPLEFT, ui.AlignMode.TOPLEFT)
    text.content = ""
    return text
end

local function selectedId(list)
    local ok, entryId = pcall(function()
        local selected = list.selectedEntries
        return selected and selected[1] and selected[1].id or nil
    end)
    return ok and entryId or nil
end

-- Builds the window.
--   sectionKey : section to show
--   settings   : reminder settings (to tick the boxes)
--   crewInputs : { morale = "", combat = "", seafaring = "", resource = bool }
--   storyTarget: Story helper topic key to show
function Panel:Build(root, sectionKey, settings, crewInputs, storyTarget)
    self.root = root
    self.parts = {}
    local parts = self.parts

    local title = addText(root, 0, 0, 1.0, 1)
    title.content = "<col=ffd24a>Ports & Arc helper</col>"

    -- Section dropdown (moved to the front at the end so it opens over the body).
    local sections = ui.List.new(root)
    sections:SetPos(0, 24)
    sections:SetSize(0, CONTROL, 1.0, 0.0)
    sections.stylesheetID = id.StyleSheet.DROPDOWN_DEFAULT
    sections.dropdownMaxVisibleEntries = #Panel.SECTIONS
    for _, section in ipairs(Panel.SECTIONS) do
        sections:Add(section.label, section.id)
    end
    sections:SetEntrySelected(sectionByKey(sectionKey).id, true, false)
    sections:Subscribe(ui.Hook.ONSELECTIONCHANGED, function(component)
        local chosen = selectedId(component)
        for _, section in ipairs(Panel.SECTIONS) do
            if section.id == chosen then
                self.callbacks.onSection(section.key)
            end
        end
    end)

    -- Crew optimizer controls: three stat boxes, a checkbox and a button.
    parts.crew = {}
    local statNames = { "morale", "combat", "seafaring" }
    local statLabels = { "Morale", "Combat", "Seafaring" }
    for index, stat in ipairs(statNames) do
        local field = ui.InputField.new(root)
        field:SetPos(0, CONTROLS_TOP, (index - 1) / 3, 0.0)
        field:SetSize(-6, CONTROL, 1 / 3, 0.0)
        field.stylesheetID = id.StyleSheet.INPUT_DEFAULT
        pcall(function()
            field:Setup(ui.TextContentVisibilityMode.VISIBLE, ui.InputFieldFilterMode.NUMERIC, 6)
        end)
        field.emptyText = statLabels[index] .. " needed"
        field.content = crewInputs[stat] or ""
        parts.crew[stat] = field
    end
    local resource = ui.Check.new(root)
    resource:SetPos(0, CONTROLS_TOP + CONTROL + 6)
    resource:SetSize(0, CONTROL, 0.5, 0.0)
    resource.stylesheetID = id.StyleSheet.CHECKBOX_DEFAULT
    resource.label = "Resource voyage (use a merchant)"
    resource.value = crewInputs.resource == true
    parts.crew.resource = resource
    local find = ui.Button.new(root)
    find:SetPos(0, CONTROLS_TOP + CONTROL + 6, 0.5, 0.0)
    find:SetSize(0, CONTROL, 0.5, 0.0)
    find.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
    find.label = "Find best crew"
    find:Subscribe(ui.Hook.ONBUTTONPRESSED, function()
        local crew = parts.crew
        self.callbacks.onFindCrew(crew.morale.content, crew.combat.content,
            crew.seafaring.content, crew.resource.value == true)
    end)
    parts.crew.find = find

    -- Reminder checkboxes, two columns.
    parts.settings = {}
    for index, check in ipairs(Panel.REMINDER_CHECKS) do
        local box = ui.Check.new(root)
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        box:SetPos(0, CONTROLS_TOP + row * (CONTROL + 4), column * 0.5, 0.0)
        box:SetSize(0, CONTROL, 0.5, 0.0)
        box.stylesheetID = id.StyleSheet.CHECKBOX_DEFAULT
        box.label = check.label
        box.value = settings[check.key] == true
        -- Read the documented Bool `value` rather than the hook's argument,
        -- which the docs describe inconsistently.
        box:Subscribe(ui.Hook.ONBUTTONPRESSED, function(component)
            self.callbacks.onSetting(check.key, component.value == true)
        end)
        parts.settings[check.key] = box
    end

    -- Story helper topic dropdown.
    local story = ui.List.new(root)
    story:SetPos(0, CONTROLS_TOP)
    story:SetSize(0, CONTROL, 1.0, 0.0)
    story.stylesheetID = id.StyleSheet.DROPDOWN_DEFAULT
    story.dropdownMaxVisibleEntries = 10
    local storyChosen = self.storyTargets[1] and self.storyTargets[1].id
    for _, target in ipairs(self.storyTargets) do
        story:Add(target.label, target.id)
        if target.key == storyTarget then storyChosen = target.id end
    end
    if storyChosen then
        story:SetEntrySelected(storyChosen, true, false)
    end
    story:Subscribe(ui.Hook.ONSELECTIONCHANGED, function(component)
        local chosen = selectedId(component)
        for _, target in ipairs(self.storyTargets) do
            if target.id == chosen then
                self.callbacks.onStoryTarget(target.key)
            end
        end
    end)
    parts.story = { list = story }

    parts.body = addText(root, 0, BODY_TOP, 1.0, BODY_ROWS)

    -- Dropdowns open downwards over the body, so they go in front of it.
    pcall(function() story:MoveToFront() end)
    pcall(function() sections:MoveToFront() end)
    self:ShowSection(sectionKey)
end

function Panel:IsVisible()
    if self.root == nil then return false end
    local ok, visible = pcall(function() return self.root.visibleGlobal end)
    return ok and visible == true
end

-- Shows only the controls that belong to the section.
function Panel:ShowSection(sectionKey)
    if self.root == nil then return end
    pcall(function()
        for _, component in pairs(self.parts.crew) do
            component.hidden = sectionKey ~= "crew"
        end
        for _, component in pairs(self.parts.settings) do
            component.hidden = sectionKey ~= "settings"
        end
        for _, component in pairs(self.parts.story) do
            component.hidden = sectionKey ~= "story"
        end
    end)
end

-- Fills in the crew optimizer's three stat boxes (e.g. from the voyage the
-- game is showing). Does nothing while the panel isn't built.
function Panel:SetCrewInputs(morale, combat, seafaring)
    if self.root == nil or self.parts.crew == nil then return end
    pcall(function()
        self.parts.crew.morale.content = tostring(morale)
        self.parts.crew.combat.content = tostring(combat)
        self.parts.crew.seafaring.content = tostring(seafaring)
    end)
end

function Panel:SetBody(text)
    if not self:IsVisible() then return end
    pcall(function() self.parts.body.content = text end)
end

return Panel

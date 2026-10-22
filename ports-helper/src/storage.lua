-- storage.lua
-- Saves settings and history with the plugin API's PersistentDB.
--
-- PersistentDB is shared by every character on this computer. Ports progress
-- is per character, so the Portnight history is saved under the character's
-- name; reminder settings and the story topic are shared.
--
-- Keys:
--   reminderSettings      { resetSoon = bool, ... } (see Reminders.DEFAULT_SETTINGS)
--   remindersShown        { key = occurrence } of reminders already shown
--   storyTarget           { key = "<Story.TARGETS key>" }
--   voyageDays:<name>     list of day keys with a voyage sent (Portnight)
--
-- Every call is wrapped in pcall: storage problems must never break the
-- plugin, they just mean nothing is remembered.

local Storage = {}

local KEY_SETTINGS = "reminderSettings"
local KEY_SHOWN = "remindersShown"
local VOYAGE_DAYS_PREFIX = "voyageDays:"
local KEY_STORY_TARGET = "storyTarget"

-- Returns the saved table for `key`, or nil (missing, not a table, or error).
local function get(key)
    local ok, value = pcall(function() return PersistentDB:GetStructuredData(key) end)
    if ok and type(value) == "table" then
        return value
    end
    return nil
end

-- Saves a table under `key`; failures are ignored.
local function set(key, value)
    pcall(function() return PersistentDB:SetStructuredData(key, value) end)
end

-- Reminder settings, filled in with defaults for anything not saved.
function Storage.LoadSettings(defaults)
    local saved = get(KEY_SETTINGS) or {}
    local settings = {}
    for key, value in pairs(defaults) do
        if saved[key] ~= nil then
            settings[key] = saved[key]
        else
            settings[key] = value
        end
    end
    return settings
end

function Storage.SaveSettings(settings)
    set(KEY_SETTINGS, settings)
end

-- Which reminder occurrences have been shown: { resetSoon = <occurrence>, ... }
function Storage.LoadShown()
    return get(KEY_SHOWN) or {}
end

function Storage.SaveShown(shown)
    set(KEY_SHOWN, shown)
end

-- The Story helper topic last looked at.
function Storage.LoadStoryTarget()
    local saved = get(KEY_STORY_TARGET)
    return saved and saved.key or nil
end

function Storage.SaveStoryTarget(key)
    set(KEY_STORY_TARGET, { key = key })
end

-- Portnight history for one character (list of day keys).
-- TO DO: SaveVoyageDays isn't called yet, since voyages aren't recorded yet.
function Storage.LoadVoyageDays(characterName)
    return get(VOYAGE_DAYS_PREFIX .. characterName) or {}
end

function Storage.SaveVoyageDays(characterName, list)
    set(VOYAGE_DAYS_PREFIX .. characterName, list)
end

return Storage

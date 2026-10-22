-- Ports Discovery (developer tool, never meant for the Plugin Hub)
--
-- Run this on the plugin beta world to find what the Ports & Arc helper can
-- read from the game. Everything is printed to the client console (ALT + the
-- key under Esc). Copy the console output into an issue.
--
-- What it does:
--   1. Lists every VarPlayer / VarClient whose name looks port or Arc related,
--      with its current value, then logs whenever one of them changes. Send a
--      voyage, collect one, use a reroll: the matching variables should move.
--   2. Watches for open game windows whose text looks like a port window (the
--      Captain's Log, Crew Roster, voyage screens) and prints the interface ID
--      plus a sample of its text. Those IDs go into
--      ports-helper/src/sources/captains_log.lua.
--   3. With the optional chat permission, prints chat messages that mention
--      ports words (voyages returning, Portnight, rerolls), so we can see
--      which ones are useful.

local VAR_KEYWORDS = {
    "PORT", "POP", "VOYAGE", "SHIP", "CREW", "CHIME", "REROLL", "ARC",
    "CONTRACT", "TAIJITU", "CASTAWAY", "BERRY", "PLANTER", "ADVENTURER",
}
local WINDOW_KEYWORDS = {
    "RUNEDATE", "VOYAGE", "MORALE", "SEAFARING", "CHIMES", "CREW", "CAPTAIN",
    "REROLL", "PORT", "ADVENTURER", "SHIPYARD", "REGION",
}
local CHAT_KEYWORDS = { "voyage", "ship", "port", "reroll", "chimes", "portnight", "adventurer" }

local DOMAINS = { "VarPlayer", "VarClient" }
local IDS_PER_TICK = 600
local MAX_CONSECUTIVE_MISSES = 5000
local HARD_ID_LIMIT = 150000

local function say(...)
    print("[Ports discovery]", ...)
end

local function stripTags(text)
    return (string.gsub(text or "", "<[^>]*>", " "))
end

--------------------------------------------------------------------------------
-- 1: scan variable names, then log changes
--------------------------------------------------------------------------------

local matches = {} -- configName -> true

local function nameMatches(name)
    local upper = string.upper(name or "")
    for _, keyword in ipairs(VAR_KEYWORDS) do
        -- Whole-word-ish match so "ARC" doesn't hit "SEARCH" or "MARCH".
        if string.find(upper, "%f[%w_]" .. keyword) or string.find(upper, "_" .. keyword) then
            return true
        end
    end
    return false
end

local function describe(variable)
    local ok, value = pcall(function() return variable.value end)
    return string.format("id=%s name=%s value=%s varbit=%s",
        tostring(variable.id), tostring(variable.configName),
        ok and tostring(value) or "?", tostring(variable.isVarBit))
end

local function lookup(domain, variableId)
    local ok, variable = pcall(function() return var[domain].FromID(variableId) end)
    if ok then return variable end
    return nil
end

-- Each job walks IDs in one direction: up from 0, or down from -1 for
-- varbits (whose IDs are negative in the docs' examples).
local jobs = {}
for _, domain in ipairs(DOMAINS) do
    table.insert(jobs, { domain = domain, nextId = 0, step = 1, misses = 0, found = 0 })
    table.insert(jobs, { domain = domain, nextId = -1, step = -1, misses = 0, found = 0 })
end

local function scanStep()
    local job = jobs[1]
    if job == nil then return false end
    for _ = 1, IDS_PER_TICK do
        local variable = lookup(job.domain, job.nextId)
        if variable ~= nil then
            job.misses = 0
            job.found = job.found + 1
            if nameMatches(variable.configName) then
                matches[variable.configName] = true
                say("MATCH", job.domain, describe(variable))
            end
        else
            job.misses = job.misses + 1
        end
        job.nextId = job.nextId + job.step
        if job.misses >= MAX_CONSECUTIVE_MISSES or math.abs(job.nextId) > HARD_ID_LIMIT then
            say(string.format("finished %s %s: %d variables found",
                job.domain, job.step > 0 and "(normal)" or "(varbits)", job.found))
            table.remove(jobs, 1)
            if #jobs == 0 then
                say("Scan complete. Now open the Captain's Log and Crew Roster, and send or collect a voyage.")
            end
            return true
        end
    end
    return true
end

Event.VarTransmit.Subscribe("portsDiscoveryVars", function(event)
    local name = event.var and event.var.configName or "?"
    if matches[name] then
        say("CHANGE", name, tostring(event.oldValue) .. " -> " .. tostring(event.newValue))
    end
end)

--------------------------------------------------------------------------------
-- 2: find the port windows
--------------------------------------------------------------------------------

local MAX_INTERFACE_ID = 3000      -- how many interface IDs to check
local INTERFACE_CHECK_TICKS = 5    -- check every 5 server ticks (~3 s)
local MAX_COMPONENTS = 3000
local RECHECK_TICKS = 50           -- re-read an open window every ~30 s at most
local reportedInterfaces = {}      -- interfaceId -> true once printed
local lastInspected = {}           -- interfaceId -> tick when last inspected

-- Collects up to `limit` non-empty text strings from a component tree.
local function collectText(component, out, budget, limit)
    if budget.remaining <= 0 or #out >= limit then return end
    budget.remaining = budget.remaining - 1
    local ok, content = pcall(function() return component.content end)
    if ok and type(content) == "string" and content ~= "" then
        table.insert(out, content)
    end
    local function child(c)
        collectText(c, out, budget, limit)
        return budget.remaining <= 0 or #out >= limit
    end
    pcall(function() component:IterateStaticComponents(child) end)
    pcall(function() component:IterateDynamicComponents(child) end)
end

-- How many different port words appear across the window's text.
local function portScore(texts)
    local all = string.upper(stripTags(table.concat(texts, " ")))
    local hits = {}
    for _, keyword in ipairs(WINDOW_KEYWORDS) do
        if string.find(all, keyword, 1, true) then
            table.insert(hits, keyword)
        end
    end
    return #hits, hits
end

local function inspectInterface(interfaceId, interface)
    local texts, budget = {}, { remaining = MAX_COMPONENTS }
    local function top(component)
        collectText(component, texts, budget, 300)
        return budget.remaining <= 0
    end
    local listed = pcall(function() interface:IterateStaticComponents(top) end)
    if not listed then
        for staticId = 0, 400 do
            local ok, component = pcall(function()
                return ui.Interfaces:GetComponent(interfaceId, staticId)
            end)
            if ok and component ~= nil then top(component) end
        end
    end
    local score, hits = portScore(texts)
    if score >= 2 then
        reportedInterfaces[interfaceId] = true
        say(string.format("PORT WINDOW? interface=%d words=%s listedChildren=%s texts=%d",
            interfaceId, table.concat(hits, ","), tostring(listed), #texts))
        for index = 1, math.min(#texts, 40) do
            say("   text[" .. index .. "]: " .. texts[index])
        end
    end
end

-- Also list any interface names in id.Interface that look port related.
pcall(function()
    for name, value in pairs(id.Interface) do
        local upper = string.upper(tostring(name))
        if string.find(upper, "PORT", 1, true) or string.find(upper, "VOYAGE", 1, true)
            or string.find(upper, "CREW", 1, true) then
            say("id.Interface name:", name, "=", tostring(value))
        end
    end
end)

local interfaceTicks = 0
Event.ServerLogic.Subscribe("portsDiscoveryWindows", function()
    interfaceTicks = interfaceTicks + 1
    if interfaceTicks % INTERFACE_CHECK_TICKS ~= 0 then return end
    for interfaceId = 0, MAX_INTERFACE_ID do
        local recentlyChecked = lastInspected[interfaceId] ~= nil
            and interfaceTicks - lastInspected[interfaceId] < RECHECK_TICKS
        if not reportedInterfaces[interfaceId] and not recentlyChecked then
            local ok, interface = pcall(function()
                return ui.Interfaces:GetInterface(interfaceId)
            end)
            if ok and interface ~= nil then
                lastInspected[interfaceId] = interfaceTicks
                inspectInterface(interfaceId, interface)
            else
                lastInspected[interfaceId] = nil -- closed: inspect as soon as it reopens
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- 3: port chat messages (optional chat permission)
--------------------------------------------------------------------------------

pcall(function()
    Event.ChatMessage.Subscribe("portsDiscoveryChat", function(event)
        local text = string.lower(stripTags(event.chatMessage or ""))
        for _, keyword in ipairs(CHAT_KEYWORDS) do
            if string.find(text, keyword, 1, true) then
                say("CHAT", "type=" .. tostring(event.chatType), "time=" .. tostring(event.timestamp),
                    event.chatMessage)
                return
            end
        end
    end)
end)

--------------------------------------------------------------------------------
-- Drive the scan from the server tick
--------------------------------------------------------------------------------

say("Scanning variable names. This takes a minute or two...")
local scanFinished = false
Event.ServerLogic.Subscribe("portsDiscoveryScan", function()
    if not scanFinished then
        scanFinished = not scanStep()
    end
end)

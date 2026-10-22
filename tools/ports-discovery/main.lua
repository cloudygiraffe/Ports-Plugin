-- Ports Discovery (developer tool, never meant for the Plugin Hub)
--
-- Run this on the plugin beta world to find what the Ports & Arc helper can
-- read from the game. Everything is printed to the client console (ALT + the
-- key under Esc). Copy the console output into an issue.
--
-- What it does:
--   1. OFF by default (SCAN_NAMES near the bottom): scans every VarPlayer /
--      VarClient ID and lists those whose name looks port or Arc related
--      ("MATCH" lines), then logs whenever one of them changes ("CHANGE"
--      lines, rate-limited, plus a 2-minute summary). The client's own
--      `pan VarPlayer` / `pan VarClient` lists (docs/VARIABLES.md) now cover
--      the same ground without flooding the console; turn the scan back on
--      only if a game update renames variables.
--   2. Watches for open game windows whose text looks like a port window (the
--      Captain's Log, Crew Roster, voyage screens) and prints the interface ID
--      plus a sample of its text ("PORT WINDOW?" lines). Those IDs go into
--      ports-helper/src/sources/captains_log.lua. The Ports & Arc helper's own
--      panel is skipped.
--   2b. Prints a labelled snapshot of the known port variables ("PORT VARS"
--      blocks) at start and whenever a value changes: rerolls, today's
--      visitors, voyage slots, the voyage list, resources, hotspots and every
--      adventurer's story progress. Compare it with the game to confirm what
--      each variable means.
--   3. With the optional chat permission, prints chat messages that mention
--      ports words (voyages returning, Portnight, rerolls), so we can see
--      which ones are useful.
--
-- Everything is read-only; nothing is clicked or changed.

-- Variable names are split on "_" and a name matches only if one of its
-- parts is exactly one of these words, so "ARC" doesn't match ARCHAEOLOGY and
-- "POP" doesn't match POPUP.
local VAR_WORDS = {
    PORT = true, PORTS = true, POP = true, POPS = true, VOYAGE = true, VOYAGES = true,
    SHIP = true, SHIPS = true, CREW = true, CHIME = true, CHIMES = true,
    REROLL = true, REROLLS = true, ARC = true, CONTRACT = true, CONTRACTS = true,
    TAIJITU = true, CASTAWAY = true, CASTAWAYS = true, PLANTER = true,
    ADVENTURER = true, ADVENTURERS = true, PORTNIGHT = true, SEAFARING = true,
}
-- Whole words that only appear in port windows. A window is reported when
-- it has at least 3 different ones, or says "Runedate".
local WINDOW_WORDS = {
    "RUNEDATE", "VOYAGE", "VOYAGES", "MORALE", "SEAFARING", "CHIMES", "CREW",
    "CAPTAIN", "REROLL", "REROLLS", "ADVENTURER", "SHIPYARD", "BARMAID",
}
local MAX_CHANGE_LINES = 150       -- stop printing CHANGE lines after this many
local CHANGE_QUIET_SECONDS = 10    -- print each variable at most once per 10 s
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
    for part in string.gmatch(string.upper(name or ""), "[^_]+") do
        if VAR_WORDS[part] then
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

-- Logs changes to matched variables, rate-limited so a busy variable can't
-- flood the console. Counts of everything are printed every 2 minutes.
local latestTick = 0
local changeLines = 0
local lastPrinted = {}   -- name -> logic tick last printed
local changeCounts = {}  -- name -> changes since the last summary
Event.Logic.Subscribe("portsDiscoveryTick", function(event)
    latestTick = event.logicTick
end)

Event.VarTransmit.Subscribe("portsDiscoveryVars", function(event)
    local name = event.var and event.var.configName or "?"
    if not matches[name] then return end
    changeCounts[name] = (changeCounts[name] or 0) + 1
    local quiet = lastPrinted[name] == nil
        or latestTick - lastPrinted[name] >= CHANGE_QUIET_SECONDS * 50
    if quiet and changeLines < MAX_CHANGE_LINES then
        changeLines = changeLines + 1
        lastPrinted[name] = latestTick
        say("CHANGE", name, tostring(event.oldValue) .. " -> " .. tostring(event.newValue))
        if changeLines == MAX_CHANGE_LINES then
            say("CHANGE lines paused (limit reached). Summaries continue every 2 minutes.")
        end
    end
end)

local summaryTicks = 0
Event.ServerLogic.Subscribe("portsDiscoverySummary", function()
    summaryTicks = summaryTicks + 1
    if summaryTicks % 200 ~= 0 or next(changeCounts) == nil then return end
    local parts = {}
    for name, count in pairs(changeCounts) do
        table.insert(parts, name .. "=" .. count)
    end
    table.sort(parts)
    say("CHANGES in the last 2 minutes: " .. table.concat(parts, ", "))
    changeCounts = {}
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

-- Which port words appear (as whole words) across the window's text.
local function portWords(texts)
    local all = " " .. string.upper(stripTags(table.concat(texts, " "))) .. " "
    local hits = {}
    for _, word in ipairs(WINDOW_WORDS) do
        if string.find(all, "%f[%a]" .. word .. "%f[%A]") then
            table.insert(hits, word)
        end
    end
    return hits
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
    -- Skip the Ports & Arc helper's own panel.
    for _, text in ipairs(texts) do
        if string.find(text, "Ports & Arc helper", 1, true) then
            reportedInterfaces[interfaceId] = true
            return
        end
    end
    local hits = portWords(texts)
    local hasRuneDate = hits[1] == "RUNEDATE"
    if #hits >= 3 or hasRuneDate then
        reportedInterfaces[interfaceId] = true
        say(string.format("PORT WINDOW? interface=%d words=%s listedChildren=%s texts=%d",
            interfaceId, table.concat(hits, ","), tostring(listed), #texts))
        for index = 1, math.min(#texts, 25) do
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
-- 2b: snapshot of the port variables found in the client's own lists
-- (`pan VarPlayer`). Printed as "PORT VARS" blocks now and whenever a value
-- changes (checked every ~3 s). Compare with what the game shows.
--------------------------------------------------------------------------------

local SNAPSHOT = {
    { "voyage rerolls", -17122 }, { "crew rerolls", -17462 },
    { "in port today: adventurer 1", -17023 }, { "in port today: adventurer 2", -17024 },
    { "story voyage offered by adventurer 1", -17025 }, { "story voyage offered by adventurer 2", -17026 },
    { "ship 1 voyage id", -17072 }, { "ship 1 done", -17073 },
    { "ship 2 voyage id", -17083 }, { "ship 2 done", -17084 },
    { "ship 3 voyage id", -17094 }, { "ship 3 done", -17095 },
    { "ship 4 voyage id", -17105 }, { "ship 4 done", -17106 },
    { "list: need morale", 3411 }, { "list: need combat", 3412 }, { "list: need seafaring", 3413 },
    { "list: have morale", 3408 }, { "list: have combat", 3409 }, { "list: have seafaring", 3410 },
    { "list: return timer (min since 1970)", 3414 }, { "voyages tracker", 3403 },
    { "port upgrade building", -17432 }, { "port upgrade level", -17433 },
    { "resource 1", 3441 }, { "resource 2", 3442 }, { "resource 3", 3443 }, { "resource 4", 3444 },
    { "resource 5", 3445 }, { "resource 6", 3446 }, { "resource 7", 3447 }, { "resource 8", 4038 },
    { "resource 9", 4039 }, { "goods 1", 3439 }, { "goods 2", 3440 },
    { "hotspots 1", 3437 }, { "hotspots 2", 3438 },
}
for number = 1, 12 do
    -- POP_ADVENTURER_n_COMPLETED / _AVAILABLE / _MISSION, packed per adventurer.
    local completed = ({ -16995, -16999, -17003, -17008, -17012, -17016,
                         -21307, -21311, -21315, -26836, -26840, -26844 })[number]
    table.insert(SNAPSHOT, { "adventurer " .. number .. " story done", completed })
    table.insert(SNAPSHOT, { "adventurer " .. number .. " available", completed - 1 })
    table.insert(SNAPSHOT, { "adventurer " .. number .. " mission", completed - 3 })
end
for _, trio in ipairs({ { "QUIN", -17020 }, { "COLONIST", -17007 }, { "CREATURE", -21319 }, { "KAIJU", -26848 } }) do
    table.insert(SNAPSHOT, { "trio " .. trio[1] .. " done", trio[2] })
end

local function readVarPlayer(variableId)
    local ok, value = pcall(function() return var.VarPlayer.FromID(variableId).value end)
    if ok then return value end
    return "?"
end

local lastSnapshot = nil
local function snapshot()
    local parts = {}
    for _, entry in ipairs(SNAPSHOT) do
        table.insert(parts, entry[1] .. "=" .. tostring(readVarPlayer(entry[2])))
    end
    local key = table.concat(parts, "  ")
    if key ~= lastSnapshot then
        lastSnapshot = key
        say("PORT VARS ----------------------------------------")
        -- A few per line so the console stays readable.
        for index = 1, #parts, 4 do
            say("   " .. table.concat(parts, "  ", index, math.min(index + 3, #parts)))
        end
    end
end

local snapshotTicks = 0
Event.ServerLogic.Subscribe("portsDiscoverySnapshot", function()
    snapshotTicks = snapshotTicks + 1
    if snapshotTicks % 5 == 0 then snapshot() end
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

-- The variable-name scan is off by default: the client's own lists (console
-- `pan VarPlayer` / `pan VarClient`, see docs/VARIABLES.md) give every name and
-- ID directly, and the scan's MATCH lines flood the console. Set SCAN_NAMES =
-- true to run it again (e.g. after a game update renames variables).
local SCAN_NAMES = false
if SCAN_NAMES then
    say("Scanning variable names. This takes a minute or two...")
end
local scanFinished = not SCAN_NAMES
Event.ServerLogic.Subscribe("portsDiscoveryScan", function()
    if not scanFinished then
        scanFinished = not scanStep()
    end
end)

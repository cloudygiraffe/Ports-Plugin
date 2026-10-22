-- story.lua
-- The story helper: which adventurers each Ports storyline needs, and which
-- icon to build in your port to make an adventurer more likely to visit.
-- Pure data and text functions, unit tested.
--
-- Data from the RuneScape Wiki (Ornate arch / icon hotspot page, each
-- adventurer's page, Trip to the East, Eastern Adventurer pages, and
-- Category:Player-owned port voyages), checked October 22nd, 2026. Wiki text
-- is CC BY-NC-SA 3.0; see docs/RESEARCH.md for links.

local Story = {}

local GOLD = "ffd24a"
local GREY = "9a9a9a"

local function colour(text, hex)
    return "<col=" .. hex .. ">" .. text .. "</col>"
end

--------------------------------------------------------------------------------
-- Data
--------------------------------------------------------------------------------

Story.ICON_COST_CHIMES = 1000
Story.HOTSPOTS = 3

-- Distance needed to unlock each sea region.
Story.REGIONS = {
    { name = "Arc",      distance = 0 },
    { name = "Skull",    distance = 5000 },
    { name = "Hook",     distance = 40000 },
    { name = "Scythe",   distance = 140000 },
    { name = "Bowl",     distance = 450000 },
    { name = "Pincers",  distance = 1200000 },
    { name = "Loop",     distance = 2300000 },
    { name = "Shield",   distance = 4100000 },
}

-- Every adventurer: hotspot icon, skill needing level 90 to build it, the
-- final (6th) story voyage, and its reward. Story voyages 1-6 go one region
-- at a time from the Arc to the Pincers.
Story.ADVENTURERS = {
    { key = "whaler",     name = "The Whaler",     person = "Hubbub",   icon = "Whale skull trophy",  skill = "Fishing",
      final = "The Whale Whisperer", finalStats = "8,000 each", reward = "100 Spices" },
    { key = "biologist",  name = "The Biologist",  person = "Bethan",   icon = "Mammoth head",        skill = "Herblore",
      final = "People are the Deadliest Disease", finalStats = "16,000 Combat", reward = "25 Ancient bones" },
    { key = "occultist",  name = "The Occultist",  person = "Zu Zu",    icon = "Occult artefact",     skill = "Runecrafting",
      final = "The Loophole", finalStats = "9,600 Combat, 9,600 Seafaring", reward = "25 Chi" },
    { key = "assassin",   name = "The Assassin",   person = "Ling",     icon = "Human skull",         skill = "Slayer",
      final = "Pulling the Tooth", finalStats = "8,000 each", reward = "25 Lacquer" },
    { key = "convict",    name = "The Convict",    person = "Marcus Fine", icon = "Stocks",           skill = "Thieving",
      final = "Hail To The Khan", finalStats = "9,600 Combat, 9,600 Seafaring", reward = "25 Plate" },
    { key = "missionary", name = "The Missionary", person = "Tomlin",   icon = "Saradominist symbol", skill = "Prayer",
      final = "God's Grace Upon You", finalStats = "9,600 Combat, 9,600 Seafaring", reward = "25 Plate" },
    { key = "trapper",    name = "The Trapper",    person = "Reginald Wellington-Smythe", icon = "Trap", skill = "Hunter",
      final = "Theories Abound", finalStats = "9,600 Morale, 9,600 Combat", reward = "18 Pearls, 7 Koi scales" },
    { key = "chef",       name = "The Chef",       person = "Carlos Napp", icon = "Cooking pot",      skill = "Cooking",
      final = "Barrels of Mystery", finalStats = "9,600 Morale, 9,600 Seafaring", reward = "18 Pearls, 28 Spices" },
    { key = "architect",  name = "The Architect",  person = "Lidylla",  icon = "Ornate arch",         skill = "Construction",
      final = "Foundations", finalStats = "9,600 Combat, 9,600 Seafaring", reward = "12 Pearls, 12 Koi scales" },
    { key = "exile",      name = "The Exile",      person = "Honovi",   icon = "Torn bag",            skill = "Dungeoneering",
      final = "Weight On, Weight Off", finalStats = "9,600 Morale, 9,600 Combat", reward = "15 Lacquer, 10 Ancient bones" },
    { key = "memory",     name = "The Memory",     person = "Aagi",     icon = "Butterfly",           skill = "Divination",
      final = "Remember the Dead", finalStats = "9,600 Morale, 9,600 Seafaring", reward = "20 Chi, 10 Koi scales" },
    { key = "tengu",      name = "The Tengu",      person = "Sojobo and Shanao", icon = "Tengu mask", skill = "Agility",
      final = "A Bird in the Hand", finalStats = "8,000 each", reward = "20 Plate, 10 Pearls" },
}

-- The four trio storylines. Each unlocks once all three members have finished
-- their solo storylines; after that, any two of the three in port together
-- bring the next trio voyage. Voyage stats are Morale/Combat/Seafaring.
Story.TRIOS = {
    { key = "quin", name = "Quin", achievement = "Eastern Adventurer: Quin",
      members = { "assassin", "occultist", "whaler" },
      voyages = {
          { name = "Meet the Partner - Again", stats = "11,500 / 0 / 11,500", region = "Pincers" },
          { name = "In Memory of Kirau", stats = "20,000 / 0 / 0", region = "Pincers" },
          { name = "Assault on Paradise", stats = "12,000 each", region = "Pincers" },
      },
      reward = "50 Chi, 50 Ancient bones" },
    { key = "hyuji", name = "Hyu-Ji", achievement = "Eastern Adventurer: Hyu-Ji",
      members = { "biologist", "convict", "missionary" },
      voyages = {
          { name = "Hull Down On The Horizon", stats = "20,000 / 0 / 0", region = "Pincers" },
          { name = "A Concerted Effort", stats = "10,000 each", region = "Pincers" },
          { name = "The Defiance of Hyu-Ji", stats = "12,000 each", region = "Pincers" },
      },
      reward = "50 Plate, 50 Lacquer" },
    { key = "eastern", name = "Eastern Curiosities", achievement = "Eastern Adventurer: Eastern Curiosities",
      members = { "chef", "trapper", "architect" },
      voyages = {
          { name = "Reinforcement", stats = "11,500 / 11,500 / 0", region = "Pincers" },
          { name = "Once More Into the Breach", stats = "0 / 20,000 / 0", region = "Pincers" },
          { name = "Recipe Number 132: Fresh Idea", stats = "12,000 each", region = "Pincers" },
      },
      reward = "50 Koi scales, 50 Pearls" },
    { key = "guardians", name = "Guardians of the World", achievement = "Eastern Adventurer: Guardians of the World",
      members = { "tengu", "memory", "exile" },
      voyages = {
          { name = "Lament of the Sea", stats = "12,500 / 0 / 12,500", region = "Loop" },
          { name = "Gu: Warriors of the Magic Mountain", stats = "30,000 / 0 / 0", region = "Shield" },
          { name = "Guardians of the World", stats = "18,000 each", region = "Shield (6,000,000 distance)" },
      },
      reward = "50 Plate, 50 Chi" },
}

-- Pairs that share "A Joint Acquisition" voyages when both are in port.
Story.JOINT_PAIRS = {
    { "assassin", "convict" }, { "biologist", "whaler" }, { "missionary", "occultist" },
    { "biologist", "chef" }, { "architect", "missionary" }, { "assassin", "trapper" },
    { "exile", "whaler" }, { "memory", "occultist" }, { "convict", "tengu" },
}

local byKey = {}
for _, adventurer in ipairs(Story.ADVENTURERS) do
    byKey[adventurer.key] = adventurer
end

function Story.Adventurer(key)
    return byKey[key]
end

function Story.TrioFor(adventurerKey)
    for _, trio in ipairs(Story.TRIOS) do
        for _, member in ipairs(trio.members) do
            if member == adventurerKey then return trio end
        end
    end
    return nil
end

function Story.JointPartners(adventurerKey)
    local partners = {}
    for _, pair in ipairs(Story.JOINT_PAIRS) do
        if pair[1] == adventurerKey then table.insert(partners, pair[2]) end
        if pair[2] == adventurerKey then table.insert(partners, pair[1]) end
    end
    return partners
end

--------------------------------------------------------------------------------
-- Visit chance (the wiki's formula; not confirmed by Jagex)
--------------------------------------------------------------------------------

-- Each icon adds 1 to the adventurer's weight (base weight 1 for everyone
-- available). Returns the chance they appear on a one-visitor day and on a
-- two-visitor day. available: adventurers unlocked and not out on a voyage.
function Story.VisitChance(icons, available)
    available = available or 12
    if available < 1 then return 0, 0 end
    local total = available + icons
    local one = (1 + icons) / total
    if available < 2 then return one, one end
    -- Two visitors: one minus the chance neither draw picks them.
    local missFirst = (available - 1) / total
    local missSecond = (available - 2) / (total - 1)
    return one, 1 - missFirst * missSecond
end

local function percent(fraction)
    return math.floor(fraction * 100 + 0.5) .. "%"
end

--------------------------------------------------------------------------------
-- Text for the panel
--------------------------------------------------------------------------------

-- Dropdown entries: id -> label, with a key for each.
Story.TARGETS = { { id = 1, key = "icons", label = "All icons at a glance" } }
for _, adventurer in ipairs(Story.ADVENTURERS) do
    table.insert(Story.TARGETS, { id = #Story.TARGETS + 1, key = adventurer.key, label = adventurer.name })
end
for _, trio in ipairs(Story.TRIOS) do
    table.insert(Story.TARGETS, { id = #Story.TARGETS + 1, key = "trio:" .. trio.key, label = "Trio: " .. trio.name })
end
table.insert(Story.TARGETS, { id = #Story.TARGETS + 1, key = "capes", label = "Which storylines capes need" })

local function iconOverview()
    local lines = {
        colour("Port icons: build one at a pier end to make that adventurer visit more often", GOLD),
        Story.HOTSPOTS .. " hotspots; 1,000 chimes per build; removing is free. "
            .. "Needs level 90 in the skill and their first voyage (Meet the ...) done.",
    }
    for _, adventurer in ipairs(Story.ADVENTURERS) do
        table.insert(lines, adventurer.name .. ": " .. adventurer.icon .. " (" .. adventurer.skill .. ")")
    end
    local _, none = Story.VisitChance(0)
    local _, three = Story.VisitChance(3)
    table.insert(lines, colour("Icons stack: all 3 on one adventurer raises a two-visitor day from about "
        .. percent(none) .. " to " .. percent(three) .. " (wiki estimate).", GREY))
    return table.concat(lines, "<br>")
end

local function adventurerText(adventurer)
    local lines = {
        colour(adventurer.name .. " (" .. adventurer.person .. ")", GOLD),
        "Icon: " .. adventurer.icon .. " (needs 90 " .. adventurer.skill .. ")",
    }
    local chances = {}
    for icons = 0, 3 do
        local one, two = Story.VisitChance(icons)
        table.insert(chances, icons .. " icon" .. (icons == 1 and "" or "s") .. ": "
            .. percent(one) .. " / " .. percent(two))
    end
    table.insert(lines, "Visit chance on a one / two-visitor day, all 12 available:")
    table.insert(lines, chances[1] .. " | " .. chances[2])
    table.insert(lines, chances[3] .. " | " .. chances[4])
    table.insert(lines, colour("Fewer adventurers available (some out on voyages) means better odds.", GREY))
    table.insert(lines, "")
    table.insert(lines, colour("Story voyages (6, in order)", GOLD))
    local regionNames = {}
    for index = 1, 6 do
        local region = Story.REGIONS[index]
        local distance = ""
        if region.distance >= 1000000 then
            distance = string.format(" %.1fM", region.distance / 1000000)
        elseif region.distance > 0 then
            distance = string.format(" %dk", region.distance // 1000)
        end
        table.insert(regionNames, index .. ". " .. region.name .. distance)
    end
    table.insert(lines, table.concat(regionNames, ", "))
    table.insert(lines, "Each voyage needs that region unlocked (distance shown).")
    table.insert(lines, "Final: " .. adventurer.final .. " (" .. adventurer.finalStats .. "), reward "
        .. adventurer.reward)
    table.insert(lines, "")
    local trio = Story.TrioFor(adventurer.key)
    if trio then
        local others = {}
        for _, member in ipairs(trio.members) do
            if member ~= adventurer.key then table.insert(others, byKey[member].name) end
        end
        table.insert(lines, "Trio: " .. trio.name .. ", with " .. table.concat(others, " and "))
    end
    local partners = {}
    for _, key in ipairs(Story.JointPartners(adventurer.key)) do
        table.insert(partners, byKey[key].name)
    end
    if #partners > 0 then
        table.insert(lines, "Joint voyages with: " .. table.concat(partners, ", "))
    end
    return table.concat(lines, "<br>")
end

local function trioText(trio)
    local names, icons = {}, {}
    for _, member in ipairs(trio.members) do
        table.insert(names, byKey[member].name)
        table.insert(icons, byKey[member].icon)
    end
    local lines = {
        colour("Trio storyline: " .. trio.name, GOLD),
        "Members: " .. table.concat(names, ", "),
        "Unlocks when all three have finished their own 6 story voyages.",
        "Then any 2 of the 3 in port together offer the next voyage.",
        "",
        colour("Voyages (Morale / Combat / Seafaring)", GOLD),
    }
    for index, voyage in ipairs(trio.voyages) do
        table.insert(lines, index .. ". " .. voyage.name .. ": " .. voyage.stats .. " (" .. voyage.region .. ")")
    end
    table.insert(lines, "Final reward: " .. trio.reward)
    table.insert(lines, "")
    table.insert(lines, colour("Icon tip", GOLD))
    table.insert(lines, "Build 2 icons for one member and 1 for another, e.g. 2 x "
        .. icons[1] .. " and 1 x " .. icons[2] .. ". You only need any two of them on the same day.")
    table.insert(lines, "Save adventurer rerolls for a day when one member is already in port.")
    table.insert(lines, colour("Achievement: " .. trio.achievement, GREY))
    return table.concat(lines, "<br>")
end

local function capesText()
    return table.concat({
        colour("Which storylines the capes need", GOLD),
        "Completionist cape: Trip to the East, which is any one trio storyline.",
        "Master quest cape: all four trios (the Eastern Adventurer achievements).",
        "Trimmed completionist: needs the Master quest cape, so also all four.",
        "",
        "Every trio needs its three adventurers' solo storylines finished first,",
        "so all four trios means all 12 adventurers' storylines.",
        "",
        colour("Since February 2nd, 2026, Eastern Adventurer is split into four achievements "
            .. "(Quin, Hyu-Ji, Eastern Curiosities, Guardians of the World).", GREY),
    }, "<br>")
end

-- Text for the Story helper section. targetKey is a Story.TARGETS key.
function Story.HelperText(targetKey)
    if targetKey == nil or targetKey == "icons" then
        return iconOverview()
    end
    if targetKey == "capes" then
        return capesText()
    end
    local trioKey = string.match(targetKey, "^trio:(.+)$")
    if trioKey then
        for _, trio in ipairs(Story.TRIOS) do
            if trio.key == trioKey then return trioText(trio) end
        end
    end
    local adventurer = byKey[targetKey]
    if adventurer then
        return adventurerText(adventurer)
    end
    return iconOverview()
end

return Story

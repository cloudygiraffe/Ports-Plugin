-- Story helper tests: the visit-chance formula against the wiki's worked
-- example, trio and joint-pair data integrity, and every dropdown page.
-- Loaded by tests/run_tests.lua, which passes in `test` and `eq`.
local test, eq = ...
local Story = require("src/story")

local function has(text, piece)
    return string.find(text, piece, 1, true) ~= nil
end

test("Visit chance matches the wiki's worked example (3 icons, 12 adventurers)", function()
    local one, two = Story.VisitChance(3, 12)
    eq(math.floor(one * 1000 + 0.5), 267, "one visitor: 4/15")
    eq(math.floor(two * 1000 + 0.5), 476, "two visitors: 1 - 11/15 * 10/14")
    local baseOne, baseTwo = Story.VisitChance(0, 12)
    eq(math.floor(baseOne * 1000 + 0.5), 83)
    eq(math.floor(baseTwo * 1000 + 0.5), 167)
end)

test("All 12 adventurers belong to exactly one trio", function()
    local seen = {}
    for _, trio in ipairs(Story.TRIOS) do
        eq(#trio.members, 3, trio.name)
        for _, member in ipairs(trio.members) do
            assert(Story.Adventurer(member), "unknown member " .. member)
            assert(not seen[member], member .. " in two trios")
            seen[member] = true
        end
    end
    for _, adventurer in ipairs(Story.ADVENTURERS) do
        assert(seen[adventurer.key], adventurer.key .. " has no trio")
    end
end)

test("Joint voyage pairs only name real adventurers; every pair is two-way", function()
    eq(#Story.JOINT_PAIRS, 9)
    for _, pair in ipairs(Story.JOINT_PAIRS) do
        assert(Story.Adventurer(pair[1]) and Story.Adventurer(pair[2]))
    end
    local whaler = table.concat(Story.JointPartners("whaler"), ",")
    eq(whaler, "biologist,exile")
    eq(table.concat(Story.JointPartners("biologist"), ","), "whaler,chef")
end)

test("Helper text: adventurer, trio, icons and capes pages", function()
    local whaler = Story.HelperText("whaler")
    assert(has(whaler, "Whale skull trophy") and has(whaler, "90 Fishing"), whaler)
    assert(has(whaler, "Trio: Quin, with The Assassin and The Occultist"), whaler)
    assert(has(whaler, "6. Pincers 1.2M"), whaler)
    local guardians = Story.HelperText("trio:guardians")
    assert(has(guardians, "The Tengu, The Memory, The Exile"), guardians)
    assert(has(guardians, "Shield (6,000,000 distance)"), guardians)
    assert(has(Story.HelperText("icons"), "The Memory: Butterfly (Divination)"))
    assert(has(Story.HelperText(nil), "Port icons"))
    assert(has(Story.HelperText("capes"), "any one trio"))
    assert(has(Story.HelperText("nonsense"), "Port icons"), "unknown key falls back")
end)

test("Every story topic in the dropdown has a page", function()
    eq(#Story.TARGETS, 1 + 12 + 4 + 1)
    for index, target in ipairs(Story.TARGETS) do
        eq(target.id, index)
        assert(#Story.HelperText(target.key) > 40, target.key)
    end
end)

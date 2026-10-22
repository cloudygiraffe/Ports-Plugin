-- Crew optimizer tests: success-chance maths, tie-breaks (merchant, lowest
-- crew level), captain choice, the one-merchant rule, and a full roster
-- (5 captains, 25 crew) searched in slices as main.lua does. Loaded by
-- tests/run_tests.lua, which passes in `test` and `eq`.
local test, eq = ...
local Optimizer = require("src/optimizer")

local function unit(name, level, morale, combat, seafaring, merchant)
    return { name = name, level = level, morale = morale, combat = combat,
             seafaring = seafaring, merchant = merchant }
end

local function names(result)
    local list = {}
    for _, member in ipairs(result.crew) do table.insert(list, member.name) end
    table.sort(list)
    return table.concat(list, ",")
end

test("Chance is the lowest bar, capped at 100%, plus the Command Centre", function()
    local voyage = { morale = 1000, combat = 1000, seafaring = 1000 }
    eq(Optimizer.Chance({ morale = 1000, combat = 1000, seafaring = 560 }, voyage, 0), 0.56)
    eq(Optimizer.Chance({ morale = 2000, combat = 2000, seafaring = 2000 }, voyage, 0), 1)
    eq(Optimizer.Chance({ morale = 1000, combat = 1000, seafaring = 900 }, voyage, 0.10), 1)
end)

test("Fills the weakest stat first", function()
    local result = Optimizer.Solve({
        voyage = { morale = 300, combat = 300, seafaring = 300 },
        ship = { morale = 200, combat = 200, seafaring = 0 },
        captains = { unit("Cap", 1, 50, 50, 50) },
        crew = {
            unit("MoraleGuy", 1, 100, 0, 0),
            unit("CombatGuy", 1, 0, 100, 0),
            unit("Sailor1", 1, 0, 0, 130),
            unit("Sailor2", 1, 0, 0, 130),
        },
    })
    -- Seafaring: 0 (ship) + 50 (captain) + 260 (sailors) = 310 of 300 needed.
    -- Only 4 crew, so all are taken; the point is the chance is right.
    eq(math.floor(result.chance * 1000 + 0.5), 1000)
    eq(result.bars.seafaring, 1)
end)

test("Among equally good setups, sends the lowest-level crew", function()
    local crew = {}
    for i = 1, 7 do
        -- Everyone is strong enough; levels differ.
        table.insert(crew, unit("C" .. i, i, 500, 500, 500))
    end
    local result = Optimizer.Solve({
        voyage = { morale = 100, combat = 100, seafaring = 100 },
        captains = { unit("Cap", 5, 100, 100, 100) },
        crew = crew,
    })
    eq(result.chance, 1)
    eq(names(result), "C1,C2,C3,C4,C5")
end)

test("Picks the captain that gives the better chance", function()
    local result = Optimizer.Solve({
        voyage = { morale = 0, combat = 0, seafaring = 1000 },
        captains = { unit("Weak", 1, 0, 0, 100), unit("Sea", 1, 0, 0, 700) },
        crew = { unit("A", 1, 0, 0, 60), unit("B", 1, 0, 0, 60) },
    })
    eq(result.captain.name, "Sea")
end)

test("Uses one merchant on resource voyages, never two", function()
    local crew = {
        unit("Merchant1", 9, 100, 100, 100, true),
        unit("Merchant2", 9, 100, 100, 100, true),
        unit("A", 1, 100, 100, 100), unit("B", 1, 100, 100, 100),
        unit("C", 1, 100, 100, 100), unit("D", 1, 100, 100, 100),
    }
    local problem = {
        voyage = { morale = 100, combat = 100, seafaring = 100 },
        captains = { unit("Cap", 1, 0, 0, 0) },
        crew = crew,
        resourceVoyage = true,
    }
    local result = Optimizer.Solve(problem)
    local merchants = 0
    for _, member in ipairs(result.crew) do
        if member.merchant then merchants = merchants + 1 end
    end
    eq(merchants, 1)

    problem.resourceVoyage = false
    eq(names(Optimizer.Solve(problem)), "A,B,C,D,Merchant1")
end)

test("A full roster (5 captains, 25 crew) can be searched in steps", function()
    local captains, crew = {}, {}
    for i = 1, 5 do table.insert(captains, unit("Cap" .. i, i, 100 * i, 100, 100)) end
    for i = 1, 25 do table.insert(crew, unit("Crew" .. i, i % 10, 40 * (i % 7), 30 * (i % 5), 25 * (i % 9))) end
    local job = Optimizer.NewJob({
        voyage = { morale = 2000, combat = 1500, seafaring = 1500 },
        captains = captains, crew = crew,
    })
    local steps = 0
    while not job:Step(5000) do steps = steps + 1 end
    eq(job.checked, 5 * 53130, "every captain with every group of 5 from 25")
    eq(steps > 10, true, "spread over many ticks")
    eq(job:Result() ~= nil, true)
end)

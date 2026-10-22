-- optimizer.lua
-- Suggests a captain and crew for a voyage.
--
-- How Ports works (RuneScape Wiki, Player-owned port/Strategies):
--   * A voyage has a Morale, Combat and Seafaring requirement.
--   * Your ship, captain and up to 5 crew add up to a total for each stat.
--   * Each stat's bar is total / requirement (capped at 100%), and the
--     success chance is the LOWEST of the three bars. The Fort's Command
--     Centre then adds +3%, +6% or +10%.
--   * Good players fill the lowest bar first, and among setups with the same
--     chance they send their LOWEST-LEVEL crew, so those crew level up. One
--     merchant helps on resource voyages; more than one doesn't stack.
--
-- This module checks every captain and every group of crew and keeps the
-- best by those rules. It uses the stats exactly as the game shows them, so
-- it doesn't need to know trait or level formulas.
--
-- Search size: for each captain, every combination of min(5, #crew) crew,
-- i.e. captains x C(#crew, 5). A full roster of 5 captains and 25 crew is
-- 5 x 53,130 = 265,650 setups, about 0.35 s in plain Lua 5.4. The search is
-- exhaustive on purpose: the "lowest bar" rule makes greedy picks unreliable.
-- It always uses a full crew (5, or everyone if fewer): stats are never
-- negative, so leaving a slot empty can't raise the success chance.
--
-- Guidelines note: Jagex reviews "actionable recommendations" more strictly.
-- This is non-combat planning help; the player still picks and sends the
-- crew themselves.

local Optimizer = {}

local STATS = { "morale", "combat", "seafaring" }
local MAX_CREW = 5

-- Success chance (0..1) for a set of totals against a voyage. A stat the
-- voyage doesn't require (0) is ignored. Job:evaluate inlines the same maths
-- for speed; this public version is for tests and callers with totals.
--   totals     : { morale = n, combat = n, seafaring = n }
--   voyage     : { morale = n, combat = n, seafaring = n }
--   bonus      : extra chance from the Command Centre, 0..0.10
function Optimizer.Chance(totals, voyage, bonus)
    local lowest = 1
    for _, stat in ipairs(STATS) do
        local required = voyage[stat] or 0
        if required > 0 then
            local bar = (totals[stat] or 0) / required
            if bar < lowest then
                lowest = bar
            end
        end
    end
    return math.min(1, lowest + (bonus or 0))
end

-- Adds one unit's stats into a totals table.
local function add(totals, unit)
    for _, stat in ipairs(STATS) do
        totals[stat] = totals[stat] + (unit[stat] or 0)
    end
end

-- Is candidate result `a` better than `b`? Tie-breaks, in order:
--   1. higher success chance (compared to 0.1%, so float noise can't decide)
--   2. on resource voyages, having the one useful merchant
--   3. lower total crew level (so low-level crew get the experience)
--   4. lower captain level (same reason)
-- On a complete tie the first setup found is kept (`better` returns false).
local function better(a, b, wantMerchant)
    if b == nil then return true end
    -- Compare chances in whole tenths of a percent so tiny rounding
    -- differences don't decide anything.
    local chanceA = math.floor(a.chance * 1000 + 0.5)
    local chanceB = math.floor(b.chance * 1000 + 0.5)
    if chanceA ~= chanceB then return chanceA > chanceB end
    if wantMerchant and a.hasMerchant ~= b.hasMerchant then return a.hasMerchant end
    if a.crewLevels ~= b.crewLevels then return a.crewLevels < b.crewLevels end
    return a.captainLevel < b.captainLevel
end

--------------------------------------------------------------------------------
-- A search job that can be run a little at a time, so a big roster never
-- freezes the game: call job:Step(n) each tick until job.done is true.
--------------------------------------------------------------------------------

local Job = {}
Job.__index = Job

-- Creates a search job. Nothing is checked until Step() is called.
-- problem:
--   voyage   : { morale, combat, seafaring }  required stats
--   ship     : { morale, combat, seafaring }  from the ship's parts
--   captains : list of { name, level, morale, combat, seafaring }
--   crew     : list of { name, level, morale, combat, seafaring, merchant = bool }
--   bonus    : Command Centre bonus as a fraction (0, 0.03, 0.06 or 0.10)
--   resourceVoyage : true if a merchant would help
-- Job fields callers may read: done (bool), checked (setups scored so far).
function Optimizer.NewJob(problem)
    local self = setmetatable({}, Job)
    self.problem = problem
    self.crewCount = math.min(MAX_CREW, #problem.crew)
    self.captainIndex = 1
    self.indices = nil -- current crew combination (positions in problem.crew)
    self.best = nil
    self.checked = 0
    self.done = #problem.captains == 0
    return self
end

-- Moves to the next crew combination (lexicographic). Returns false when the
-- combinations for the current captain are used up.
function Job:nextCombination()
    local n, k = #self.problem.crew, self.crewCount
    if self.indices == nil then
        self.indices = {}
        for i = 1, k do self.indices[i] = i end
        return true
    end
    local i = k
    while i >= 1 and self.indices[i] == n - k + i do
        i = i - 1
    end
    if i < 1 then
        return false
    end
    self.indices[i] = self.indices[i] + 1
    for j = i + 1, k do
        self.indices[j] = self.indices[j - 1] + 1
    end
    return true
end

-- Scores the current captain and crew combination. This runs hundreds of
-- thousands of times for a full roster, so it works in plain local numbers
-- and only builds tables when it finds a new best setup.
function Job:evaluate()
    local problem = self.problem
    local captain = problem.captains[self.captainIndex]
    local ship = problem.ship or {}
    local morale = (ship.morale or 0) + (captain.morale or 0)
    local combat = (ship.combat or 0) + (captain.combat or 0)
    local seafaring = (ship.seafaring or 0) + (captain.seafaring or 0)
    local crewLevels, merchants = 0, 0
    local crew = problem.crew
    for _, position in ipairs(self.indices) do
        local member = crew[position]
        morale = morale + (member.morale or 0)
        combat = combat + (member.combat or 0)
        seafaring = seafaring + (member.seafaring or 0)
        crewLevels = crewLevels + (member.level or 0)
        if member.merchant then merchants = merchants + 1 end
    end
    -- Merchants don't stack, so a second one is a wasted slot.
    if merchants > 1 then
        return
    end

    local voyage = problem.voyage
    local lowest = 1
    if (voyage.morale or 0) > 0 then lowest = math.min(lowest, morale / voyage.morale) end
    if (voyage.combat or 0) > 0 then lowest = math.min(lowest, combat / voyage.combat) end
    if (voyage.seafaring or 0) > 0 then lowest = math.min(lowest, seafaring / voyage.seafaring) end
    local chance = math.min(1, lowest + (problem.bonus or 0))

    local candidate = {
        chance = chance,
        hasMerchant = merchants == 1,
        crewLevels = crewLevels,
        captainLevel = captain.level or 0,
    }
    if not better(candidate, self.best, problem.resourceVoyage) then
        return
    end
    local positions = {}
    for i, position in ipairs(self.indices) do
        positions[i] = position -- copy: self.indices keeps changing
    end
    candidate.captain = captain
    candidate.positions = positions
    candidate.totals = { morale = morale, combat = combat, seafaring = seafaring }
    self.best = candidate
end

-- Checks up to `budget` setups (moving to the next captain doesn't count).
-- Returns true once the whole search is finished (also sets self.done).
function Job:Step(budget)
    while budget > 0 and not self.done do
        if self:nextCombination() then
            self:evaluate()
            self.checked = self.checked + 1
            budget = budget - 1
        else
            self.captainIndex = self.captainIndex + 1
            self.indices = nil
            if self.captainIndex > #self.problem.captains then
                self.done = true
            end
        end
    end
    return self.done
end

-- The best setup found so far:
--   { chance, captain, crew = { members... }, totals, bars = { stat = 0..1 } }
-- `captain` and the crew members are the original tables from the problem.
-- `bars` are each stat's total / requirement, capped at 1 (1 if not required).
-- Returns nil if there are no captains. Safe to call mid-search.
function Job:Result()
    local best = self.best
    if best == nil then
        return nil
    end
    local crew = {}
    for _, position in ipairs(best.positions) do
        table.insert(crew, self.problem.crew[position])
    end
    local bars = {}
    for _, stat in ipairs(STATS) do
        local required = self.problem.voyage[stat] or 0
        bars[stat] = required > 0 and math.min(1, best.totals[stat] / required) or 1
    end
    return { chance = best.chance, captain = best.captain, crew = crew,
             totals = best.totals, bars = bars }
end

-- Convenience for small rosters and tests: run the whole search at once.
function Optimizer.Solve(problem)
    local job = Optimizer.NewJob(problem)
    while not job:Step(100000) do end
    return job:Result()
end

return Optimizer

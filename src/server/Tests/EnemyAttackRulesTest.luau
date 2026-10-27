--!strict
-- EnemyAttackRules tests (pure): the telegraph plan for each attack shape
-- and who it hits. Uses the real catalog entries.
-- Run in Studio (Edit or Play, server Command Bar):
--   require(game.ServerScriptService.Server.Tests.EnemyAttackRulesTest).Run()
-- Prints one line per case and a summary; returns passed, failed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enemies = require(ReplicatedStorage.Shared.Definitions.Enemies)
local EnemyAttackRules = require(script.Parent.Parent.Util.EnemyAttackRules)

local ORIGIN = Vector3.new(10, 4, 20)
local NORTH = Vector3.new(0, 0, -1)
local EAST = Vector3.new(1, 0, 0)

local function open(_origin: Vector3, _dir: Vector3, distance: number): number
	return distance
end

local function wallAt(stop: number): EnemyAttackRules.ClearFn
	return function(_origin: Vector3, _dir: Vector3, distance: number): number
		return math.min(distance, stop)
	end
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-4
end

local function at(dir: Vector3, dist: number, side: number?): Vector3
	local across = Vector3.new(-dir.Z, 0, dir.X)
	return ORIGIN + dir * dist + across * (side or 0)
end

type Case = { name: string, run: () -> (boolean, string?) }

local cases: { Case } = {
	{
		name = "burst (lantern wisp) hits within its radius round the body",
		run = function()
			local wisp = Enemies.lantern_wisp
			local r = wisp.tuning.attackHitRangeStuds
			local plan = EnemyAttackRules.Plan(wisp, ORIGIN, at(EAST, 4), open)
			local inside = EnemyAttackRules.Hits(plan, at(NORTH, r - 0.01))
			local edge = EnemyAttackRules.Hits(plan, at(EAST, r))
			local outside = EnemyAttackRules.Hits(plan, at(EAST, r + 0.01))
			return inside and edge and not outside and EnemyAttackRules.EndPosition(plan) == nil, nil
		end,
	},
	{
		name = "charge (hitodama) runs the full line when clear and ends at its far end",
		run = function()
			local def = Enemies.hitodama
			local len = def.tuning.attackHitRangeStuds
			local plan = EnemyAttackRules.Plan(def, ORIGIN, at(EAST, 3), open)
			local finish = EnemyAttackRules.EndPosition(plan)
			return near(plan.length, len) and finish ~= nil and (finish - at(EAST, len)).Magnitude < 1e-4, nil
		end,
	},
	{
		name = "charge hits along the strip only (not behind, past the end or to the side)",
		run = function()
			local def = Enemies.hitodama
			local len, half = def.tuning.attackHitRangeStuds, def.tuning.attackWidthStuds / 2
			local plan = EnemyAttackRules.Plan(def, ORIGIN, at(NORTH, 5), open)
			local checks: { { name: string, got: boolean, want: boolean } } = {
				{ name = "mid", got = EnemyAttackRules.Hits(plan, at(NORTH, len / 2)), want = true },
				{ name = "edge", got = EnemyAttackRules.Hits(plan, at(NORTH, len, half - 0.01)), want = true },
				{ name = "behind", got = EnemyAttackRules.Hits(plan, at(NORTH, -0.5)), want = false },
				{ name = "past", got = EnemyAttackRules.Hits(plan, at(NORTH, len + 0.5)), want = false },
				{ name = "side", got = EnemyAttackRules.Hits(plan, at(NORTH, len / 2, half + 0.01)), want = false },
			}
			for _, c in checks do
				if c.got ~= c.want then
					return false, c.name
				end
			end
			return true, nil
		end,
	},
	{
		name = "a wall cuts the line short and the hit area with it",
		run = function()
			local plan = EnemyAttackRules.Plan(Enemies.hitodama, ORIGIN, at(EAST, 3), wallAt(2.5))
			return near(plan.length, 2.5) and not EnemyAttackRules.Hits(plan, at(EAST, 4)), tostring(plan.length)
		end,
	},
	{
		name = "leap (karakasa) lands on a near player and slams round the landing",
		run = function()
			local def = Enemies.karakasa
			local r = def.tuning.attackWidthStuds
			local plan = EnemyAttackRules.Plan(def, ORIGIN, at(EAST, 6), open)
			local landed = (plan.center - at(EAST, 6)).Magnitude < 1e-4
			local hit = EnemyAttackRules.Hits(plan, at(EAST, 6 + r - 0.01))
			local miss = EnemyAttackRules.Hits(plan, at(EAST, 6 + r + 0.01))
			-- Stepping back out of the warning (toward the start) also escapes.
			local back = EnemyAttackRules.Hits(plan, at(EAST, 6 - r - 0.01))
			return landed and hit and not miss and not back, nil
		end,
	},
	{
		name = "leap never jumps further than its range or through a wall",
		run = function()
			local def = Enemies.karakasa
			local far = EnemyAttackRules.Plan(def, ORIGIN, at(NORTH, 50), open)
			local walled = EnemyAttackRules.Plan(def, ORIGIN, at(NORTH, 8), wallAt(3))
			return near(far.length, def.tuning.attackHitRangeStuds) and near(walled.length, 3), nil
		end,
	},
	{
		name = "lunge (shrine guard, draft) strikes a line but stays put",
		run = function()
			local plan = EnemyAttackRules.Plan(Enemies.shrine_guard, ORIGIN, at(EAST, 2), open)
			return plan.shape == "lunge" and EnemyAttackRules.EndPosition(plan) == nil and EnemyAttackRules.Hits(plan, at(EAST, 5)), nil
		end,
	},
	{
		name = "target straight above the enemy still gives a usable direction",
		run = function()
			local plan = EnemyAttackRules.Plan(Enemies.hitodama, ORIGIN, ORIGIN + Vector3.new(0, 2, 0), open)
			return near(plan.dir.Magnitude, 1) and plan.dir.Y == 0, nil
		end,
	},
	{
		name = "leash: distance left inside a circle along a direction",
		run = function()
			local c = Vector3.new(0, 0, 0)
			local fromCenter = EnemyAttackRules.DistanceInsideCircle(c, EAST, c, 20)
			local nearEdge = EnemyAttackRules.DistanceInsideCircle(Vector3.new(18, 3, 0), EAST, c, 20)
			local inward = EnemyAttackRules.DistanceInsideCircle(Vector3.new(18, 3, 0), -EAST, c, 20)
			local outside = EnemyAttackRules.DistanceInsideCircle(Vector3.new(25, 0, 0), -EAST, c, 20)
			return near(fromCenter, 20) and near(nearEdge, 2) and near(inward, 38) and outside == 0,
				string.format("%.2f %.2f %.2f %.2f", fromCenter, nearEdge, inward, outside)
		end,
	},
}

local EnemyAttackRulesTest = {}

function EnemyAttackRulesTest.Run(): (number, number)
	local passed, failed = 0, 0
	for _, case in cases do
		local ok, result, detail = pcall(case.run)
		if ok and result then
			passed += 1
			print("[EnemyAttackRulesTest] PASS", case.name, detail or "")
		else
			failed += 1
			warn("[EnemyAttackRulesTest] FAIL", case.name, if ok then detail else result)
		end
	end
	print(string.format("[EnemyAttackRulesTest] %d passed, %d failed", passed, failed))
	return passed, failed
end

return EnemyAttackRulesTest

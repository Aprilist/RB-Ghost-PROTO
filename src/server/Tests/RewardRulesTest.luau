--!strict
-- RewardRules tests (pure): who is eligible for a normal-enemy reward and
-- what one defeat pays.
-- Run in Studio (Edit or Play, server Command Bar):
--   require(game.ServerScriptService.Server.Tests.RewardRulesTest).Run()
-- Prints one line per case and a summary; returns passed, failed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enemies = require(ReplicatedStorage.Shared.Definitions.Enemies)
local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local RewardRules = require(script.Parent.Parent.Util.RewardRules)

local R = Prototype.Spirit.RewardRadiusStuds

local function check(alive: boolean, distance: number?, playerZone: string?, enemyZone: string?): (boolean, string?)
	local ok, why = RewardRules.Eligible({
		alive = alive,
		distance = distance,
		playerZoneId = playerZone,
		enemyZoneId = enemyZone,
	})
	return ok, why
end

type Case = { name: string, run: () -> (boolean, string?) }

local cases: { Case } = {
	{
		name = "alive, near, same rewarding zone is eligible",
		run = function()
			local a = check(true, 10, "p1_arena", "p1_arena")
			local b = check(true, R, "p1_arena", "p1_arena")
			return a and b, nil
		end,
	},
	{
		name = "dead or missing character is refused",
		run = function()
			local _, a = check(false, 10, "p1_arena", "p1_arena")
			local _, b = check(true, nil, "p1_arena", "p1_arena")
			return a == "dead" and b == "dead", tostring(a) .. "/" .. tostring(b)
		end,
	},
	{
		name = "beyond the reward radius is refused",
		run = function()
			local _, why = check(true, R + 0.01, "p1_arena", "p1_arena")
			return why == "far", why
		end,
	},
	{
		name = "different or unknown zone is refused",
		run = function()
			local _, a = check(true, 10, nil, "p1_arena")
			local _, b = check(true, 10, "mistwood", "p1_arena")
			local _, c = check(true, 10, nil, nil)
			return a == "zone" and b == "zone" and c == "zone", nil
		end,
	},
	{
		name = "a zone that does not pay rewards is refused",
		run = function()
			local _, why = check(true, 10, "last_lantern_village", "last_lantern_village")
			return why == "zone_closed", why
		end,
	},
	{
		name = "wisp pays its catalog reward",
		run = function()
			local w = Enemies.lantern_wisp
			local g = RewardRules.ForEnemy("lantern_wisp", false)
			return g ~= nil and g.xp == w.xpReward and g.coins == w.coinReward
				and g.essence == w.essenceReward and g.gauge == w.gaugeReward,
				nil
		end,
	},
	{
		name = "no gauge while transformed, rest unchanged",
		run = function()
			local g = RewardRules.ForEnemy("lantern_wisp", true)
			return g ~= nil and g.gauge == 0 and g.xp == Enemies.lantern_wisp.xpReward, nil
		end,
	},
	{
		name = "unknown enemy pays nothing",
		run = function()
			return RewardRules.ForEnemy("no_such_enemy", false) == nil, nil
		end,
	},
}

local RewardRulesTest = {}

function RewardRulesTest.Run(): (number, number)
	local passed, failed = 0, 0
	for _, case in cases do
		local ok, result, detail = pcall(case.run)
		if ok and result then
			passed += 1
			print("[RewardRulesTest] PASS", case.name, detail or "")
		else
			failed += 1
			warn("[RewardRulesTest] FAIL", case.name, if ok then detail else result)
		end
	end
	print(string.format("[RewardRulesTest] %d passed, %d failed", passed, failed))
	return passed, failed
end

return RewardRulesTest

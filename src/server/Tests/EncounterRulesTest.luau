--!strict
-- EncounterRules tests (pure, M2-F part 2): how the fight opens, locks and
-- falls back, and who is paid when the boss dies.
-- Run in Studio (Edit or Play, server Command Bar):
--   require(game.ServerScriptService.Server.Tests.EncounterRulesTest).Run()
-- Prints one line per case and a summary; returns passed, failed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bosses = require(ReplicatedStorage.Shared.Definitions.Bosses)
local EncounterRules = require(script.Parent.Parent.Util.EncounterRules)

local DEF = Bosses.extinguished_keeper
local F = DEF.rewardMinDamageFraction

type Case = { name: string, run: () -> (boolean, string?) }

local cases: { Case } = {
	{
		name = "idle opens when someone is in the arena, and stays idle when nobody is",
		run = function()
			return EncounterRules.Next("idle", 1, 0, nil, false, false) == "open" and EncounterRules.Next("idle", 0, 0, nil, false, false) == "idle", nil
		end,
	},
	{
		name = "open keeps the door until the deadline, then locks",
		run = function()
			local early = EncounterRules.Next("open", 2, 5, 8, false, false)
			local atDeadline = EncounterRules.Next("open", 2, 8, 8, false, false)
			local late = EncounterRules.Next("open", 1, 20, 8, false, false)
			return early == "open" and atDeadline == "fighting" and late == "fighting", nil
		end,
	},
	{
		name = "open falls back to idle when everyone steps out before the lock",
		run = function()
			return EncounterRules.Next("open", 0, 5, 8, false, false) == "idle", nil
		end,
	},
	{
		name = "fighting stays locked while it runs, whoever walks in",
		run = function()
			return EncounterRules.Next("fighting", 3, 100, nil, false, false) == "fighting" and EncounterRules.Next("fighting", 0, 100, nil, false, false) == "fighting", nil
		end,
	},
	{
		name = "a defeat always wins; a reset goes back to open or idle",
		run = function()
			local won = EncounterRules.Next("fighting", 0, 1, nil, true, false)
			local backBusy = EncounterRules.Next("won", 2, 1, nil, false, true)
			local backEmpty = EncounterRules.Next("fighting", 0, 1, nil, false, true)
			return won == "won" and backBusy == "open" and backEmpty == "idle", nil
		end,
	},
	{
		name = "won stays won until the boss resets",
		run = function()
			return EncounterRules.Next("won", 5, 1000, nil, false, false) == "won", nil
		end,
	},
	{
		name = "only a living member in the arena with 5% damage is paid",
		run = function()
			local hp = DEF.maxHp
			local line = hp * F
			local paid = EncounterRules.Payout(true, true, true, line, hp, F)
			local little = EncounterRules.Payout(true, true, true, line - 1, hp, F)
			local none = EncounterRules.Payout(true, true, true, 0, hp, F)
			local outsider = EncounterRules.Payout(false, true, true, hp, hp, F)
			local dead = EncounterRules.Payout(true, false, true, hp, hp, F)
			local left = EncounterRules.Payout(true, true, false, hp, hp, F)
			return paid == "paid" and little == "too_little" and none == "too_little" and outsider == "not_member" and dead == "dead" and left == "left",
				table.concat({ paid, little, none, outsider, dead, left }, "/")
		end,
	},
	{
		name = "not being a member beats every other reason (late joiner who did 100%)",
		run = function()
			return EncounterRules.Payout(false, false, false, DEF.maxHp, DEF.maxHp, F) == "not_member", nil
		end,
	},
}

local EncounterRulesTest = {}

function EncounterRulesTest.Run(): (number, number)
	local passed, failed = 0, 0
	for _, case in cases do
		local ok, result, detail = pcall(case.run)
		if ok and result then
			passed += 1
			print("[EncounterRulesTest] PASS", case.name, detail or "")
		else
			failed += 1
			warn("[EncounterRulesTest] FAIL", case.name, if ok then detail else result)
		end
	end
	print(string.format("[EncounterRulesTest] %d passed, %d failed", passed, failed))
	return passed, failed
end

return EncounterRulesTest

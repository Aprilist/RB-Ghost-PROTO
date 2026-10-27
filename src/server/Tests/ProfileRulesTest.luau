--!strict
-- ProfileRules tests (pure, no players needed): defaults, the level curve,
-- the cap, currency limits and validation of broken profiles.
-- Run in Studio (Edit or Play, server Command Bar):
--   require(game.ServerScriptService.Server.Tests.ProfileRulesTest).Run()
-- Prints one line per case and a summary; returns passed, failed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Definitions.Progression)
local Project = require(ReplicatedStorage.Shared.Definitions.Project)
local ProfileRules = require(script.Parent.Parent.Util.ProfileRules)

local function fresh(): ProfileRules.ProfileV1
	return ProfileRules.New(1, "blade")
end

local function total(toLevel: number): number
	local sum = 0
	for i = 1, toLevel - 1 do
		sum += Progression.XpToNext[i]
	end
	return sum
end

type Case = { name: string, run: () -> (boolean, string?) }

local cases: { Case } = {
	{
		name = "new profile is valid level 1 with the training blade",
		run = function()
			local p = fresh()
			local ok, field = ProfileRules.Validate(p)
			local weapon = p.inventory[p.equippedWeaponId]
			return ok and p.level == 1 and p.xp == 0 and p.coins == 0 and p.essence == 0
				and weapon ~= nil and weapon.definitionId == Progression.StartingWeaponId,
				field
		end,
	},
	{
		name = "EXP below the threshold does not level",
		run = function()
			local p = fresh()
			local gained = ProfileRules.AddXp(p, Progression.XpToNext[1] - 1)
			return gained == 0 and p.level == 1 and p.xp == Progression.XpToNext[1] - 1, nil
		end,
	},
	{
		name = "exact threshold levels and keeps the remainder",
		run = function()
			local p = fresh()
			local gained = ProfileRules.AddXp(p, Progression.XpToNext[1] + 7)
			return gained == 1 and p.level == 2 and p.xp == 7, string.format("L%d xp %d", p.level, p.xp)
		end,
	},
	{
		name = "one big grant steps through several levels",
		run = function()
			local p = fresh()
			local gained = ProfileRules.AddXp(p, total(4) + 3)
			return gained == 3 and p.level == 4 and p.xp == 3, string.format("L%d xp %d", p.level, p.xp)
		end,
	},
	{
		name = "at the cap xp stays 0 and the profile stays valid",
		run = function()
			local p = fresh()
			ProfileRules.AddXp(p, total(ProfileRules.LevelCap) + 999)
			local ok = ProfileRules.Validate(p)
			local more = ProfileRules.AddXp(p, 50)
			return p.level == ProfileRules.LevelCap and p.xp == 0 and more == 0 and ok
				and ProfileRules.XpToNext(p.level) == nil,
				string.format("L%d xp %d", p.level, p.xp)
		end,
	},
	{
		name = "max HP follows level and clamps outside the curve",
		run = function()
			return ProfileRules.MaxHp(1) == Progression.MaxHpByLevel[1]
				and ProfileRules.MaxHp(3) == Progression.MaxHpByLevel[3]
				and ProfileRules.MaxHp(0) == Progression.MaxHpByLevel[1]
				and ProfileRules.MaxHp(99) == Progression.MaxHpByLevel[ProfileRules.LevelCap],
				nil
		end,
	},
	{
		name = "currency stops at the cap and reports it",
		run = function()
			local p = fresh()
			p.coins = Project.CurrencyCap - 3
			local added, capped = ProfileRules.AddCurrency(p, "coins", 10)
			local added2, capped2 = ProfileRules.AddCurrency(p, "essence", 5)
			return added == 3 and capped and p.coins == Project.CurrencyCap
				and added2 == 5 and not capped2 and p.essence == 5,
				nil
		end,
	},
	{
		name = "zero or negative grants change nothing",
		run = function()
			local p = fresh()
			local a = ProfileRules.AddXp(p, -10)
			local b = ProfileRules.AddCurrency(p, "coins", -5)
			local c = ProfileRules.AddCurrency(p, "essence", 0)
			return a == 0 and b == 0 and c == 0 and p.xp == 0 and p.coins == 0 and p.essence == 0, nil
		end,
	},
	{
		name = "validation rejects broken profiles",
		run = function()
			local broken: { { field: string, breakIt: (ProfileRules.ProfileV1) -> () } } = {
				{ field = "level", breakIt = function(p) p.level = ProfileRules.LevelCap + 1 end },
				{ field = "level", breakIt = function(p) p.level = 0 end },
				{ field = "xp", breakIt = function(p) p.xp = Progression.XpToNext[1] end },
				{ field = "xp", breakIt = function(p) p.xp = 0 / 0 end },
				{ field = "coins", breakIt = function(p) p.coins = -1 end },
				{ field = "coins", breakIt = function(p) p.coins = 1.5 end },
				{ field = "essence", breakIt = function(p) p.essence = Project.CurrencyCap + 1 end },
				{ field = "essence", breakIt = function(p) p.essence = math.huge end },
				{ field = "equippedWeaponId", breakIt = function(p) p.equippedWeaponId = "missing" end },
				{ field = "inventory.w2", breakIt = function(p) p.inventory.w2 = { definitionId = "no_such_item", upgradeLevel = 0 } end },
				{ field = "quests.q", breakIt = function(p) (p.quests :: any).q = { status = "done", progress = 0 } end },
				{ field = "schemaVersion", breakIt = function(p) p.schemaVersion = 99 end },
			}
			for _, row in broken do
				local p = fresh()
				row.breakIt(p)
				local ok, field = ProfileRules.Validate(p)
				if ok or field ~= row.field then
					return false, string.format("expected %s, got %s", row.field, tostring(field))
				end
			end
			return true, string.format("%d broken profiles", #broken)
		end,
	},
	{
		name = "clone is deep",
		run = function()
			local p = fresh()
			local c = ProfileRules.Clone(p)
			c.inventory[c.equippedWeaponId].upgradeLevel = 3
			c.quests.q01 = { status = "active", progress = 0 }
			return p.inventory[p.equippedWeaponId].upgradeLevel == 0 and p.quests.q01 == nil, nil
		end,
	},
}

local ProfileRulesTest = {}

function ProfileRulesTest.Run(): (number, number)
	local passed, failed = 0, 0
	for _, case in cases do
		local ok, result, detail = pcall(case.run)
		if ok and result then
			passed += 1
			print("[ProfileRulesTest] PASS", case.name, detail or "")
		else
			failed += 1
			warn("[ProfileRulesTest] FAIL", case.name, if ok then detail else result)
		end
	end
	print(string.format("[ProfileRulesTest] %d passed, %d failed", passed, failed))
	return passed, failed
end

return ProfileRulesTest

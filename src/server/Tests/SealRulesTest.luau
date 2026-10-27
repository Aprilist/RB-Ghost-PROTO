--!strict
-- SealRules tests (pure, M2-E): buying a seal (one charge, duplicate and
-- poor-player rejections, replacing), the ember hit counter and no-stack
-- burn, the ward soul counter with cooldown, and the shield pool.
-- Run in Studio (Edit or Play, server Command Bar):
--   require(game.ServerScriptService.Server.Tests.SealRulesTest).Run()
-- Prints one line per case and a summary; returns passed, failed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Definitions = ReplicatedStorage.Shared.Definitions
local Npcs = require(Definitions.Npcs)
local Seals = require(Definitions.Seals)
local ProfileRules = require(script.Parent.Parent.Util.ProfileRules)
local SealRules = require(script.Parent.Parent.Util.SealRules)

local W = ProfileRules.StartingWeaponInstanceId

local function profileWith(essence: number): ProfileRules.ProfileV1
	local p = ProfileRules.New(1, "blade")
	p.essence = essence
	return p
end

type Case = { name: string, run: () -> (boolean, string?) }

local cases: { Case } = {
	{
		name = "applying a seal charges its cost once and marks the weapon",
		run = function()
			local p = profileWith(50)
			local code = SealRules.Apply(p, W, "ember")
			local valid = ProfileRules.Validate(p)
			return code == "OK" and p.essence == 50 - Seals.ember.essenceCost and p.inventory[W].sealId == "ember" and valid
				and SealRules.EquippedSealId(p) == "ember",
				string.format("code=%s essence=%d", code, p.essence)
		end,
	},
	{
		name = "DEC-008: a repeated apply is ALREADY_SEALED and never charges twice",
		run = function()
			local p = profileWith(100)
			local first = SealRules.Apply(p, W, "ward")
			local after = p.essence
			local second = SealRules.Apply(p, W, "ward")
			local third = SealRules.Apply(p, W, "ward")
			return first == "OK" and second == "ALREADY_SEALED" and third == "ALREADY_SEALED" and p.essence == after,
				string.format("%s/%s/%s essence=%d", first, second, third, p.essence)
		end,
	},
	{
		name = "not enough essence is rejected and changes nothing",
		run = function()
			local p = profileWith(Seals.ember.essenceCost - 1)
			local code = SealRules.Apply(p, W, "ember")
			return code == "INSUFFICIENT_ESSENCE" and p.essence == Seals.ember.essenceCost - 1 and p.inventory[W].sealId == nil, code
		end,
	},
	{
		name = "unknown seal or weapon is rejected without a charge",
		run = function()
			local p = profileWith(100)
			local a = SealRules.Apply(p, W, "no_such_seal")
			local b = SealRules.Apply(p, "w999", "ember")
			return a == "INVALID_PAYLOAD" and b == "NOT_OWNED" and p.essence == 100 and p.inventory[W].sealId == nil,
				a .. "/" .. b
		end,
	},
	{
		name = "switching seals costs the new seal and replaces the old one",
		run = function()
			local p = profileWith(100)
			SealRules.Apply(p, W, "ember")
			local code = SealRules.Apply(p, W, "ward")
			return code == "OK" and p.inventory[W].sealId == "ward" and p.essence == 100 - Seals.ember.essenceCost - Seals.ward.essenceCost,
				string.format("essence=%d", p.essence)
		end,
	},
	{
		name = "ProfileRules rejects a weapon sealed with an unknown seal",
		run = function()
			local p = profileWith(0)
			p.inventory[W].sealId = "made_up"
			local ok, field = ProfileRules.Validate(p)
			return not ok and field == "inventory." .. W .. ".sealId", tostring(field)
		end,
	},
	{
		name = "ember burns on every Nth landed hit and then restarts",
		run = function()
			local n = Seals.ember.effect.hitsToBurn
			local count, fired, at = 0, 0, {}
			for i = 1, n * 2 do
				local triggered
				count, triggered = SealRules.EmberStep(count, n)
				if triggered then
					fired += 1
					table.insert(at, i)
				end
			end
			return fired == 2 and at[1] == n and at[2] == n * 2 and count == 0, table.concat(at, ",")
		end,
	},
	{
		name = "burn never stacks or refreshes while it lasts",
		run = function()
			local a = SealRules.CanIgnite(nil, 10)
			local b = SealRules.CanIgnite(13, 10) -- still burning
			local c = SealRules.CanIgnite(13, 13) -- just ended
			return a and not b and c, nil
		end,
	},
	{
		name = "ward shields on every Nth soul, and souls during cooldown do not count",
		run = function()
			local n = Seals.ward.effect.soulsToShield
			local souls, fired = 0, 0
			for _ = 1, n do
				local triggered
				souls, triggered = SealRules.WardStep(souls, n, false)
				if triggered then
					fired += 1
				end
			end
			local afterTrigger = souls
			local cdSouls, cdFired = SealRules.WardStep(0, n, true)
			local again = 0
			for _ = 1, n - 1 do
				again = SealRules.WardStep(again, n, false)
			end
			return fired == 1 and afterTrigger == 0 and cdSouls == 0 and not cdFired and again == n - 1, nil
		end,
	},
	{
		name = "shield soaks damage first and only the rest reaches HP",
		run = function()
			local hp, ends, through = SealRules.Absorb(25, 110, 100, 10)
			local hp2, ends2, through2 = SealRules.Absorb(hp, ends, 101, 20)
			local hp3, ends3, through3 = SealRules.Absorb(hp2, ends2, 102, 7)
			return hp == 15 and ends == 110 and through == 0
				and hp2 == 0 and ends2 == nil and through2 == 5
				and hp3 == 0 and ends3 == nil and through3 == 7,
				string.format("%d/%d/%d", through, through2, through3)
		end,
	},
	{
		name = "an expired shield soaks nothing and shows as 0",
		run = function()
			local hp, ends, through = SealRules.Absorb(25, 100, 100, 9)
			return hp == 0 and ends == nil and through == 9 and SealRules.ShieldNow(25, 100, 99) == 25 and SealRules.ShieldNow(25, 100, 100) == 0
				and SealRules.ShieldNow(25, nil, 0) == 0,
				nil
		end,
	},
	{
		name = "seal catalog has the effect numbers the service reads, and a real station NPC",
		run = function()
			local e, w = Seals.ember.effect, Seals.ward.effect
			local function pos(n: number?): boolean
				return n ~= nil and n == n and n > 0 and n < math.huge
			end
			return pos(e.hitsToBurn) and pos(e.burnDps) and pos(e.burnSec)
				and pos(w.soulsToShield) and pos(w.shieldHp) and pos(w.shieldSec) and pos(w.cooldownSec)
				and w.shieldSec < w.cooldownSec and Npcs[SealRules.StationNpcId] ~= nil,
				nil
		end,
	},
}

local SealRulesTest = {}

function SealRulesTest.Run(): (number, number)
	local passed, failed = 0, 0
	for _, case in cases do
		local ok, result, detail = pcall(case.run)
		if ok and result then
			passed += 1
			print("[SealRulesTest] PASS", case.name, detail or "")
		else
			failed += 1
			warn("[SealRulesTest] FAIL", case.name, if ok then detail else result)
		end
	end
	print(string.format("[SealRulesTest] %d passed, %d failed", passed, failed))
	return passed, failed
end

return SealRulesTest

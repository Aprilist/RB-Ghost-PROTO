--!strict
-- M4 class tests: catalog, kits, the ninja's dash-strike strip and profile
-- validation of classId. Run in Studio (server Command Bar):
--   require(game.ServerScriptService.Server.Tests.ClassesTest).Run()
-- Prints one line per case and a summary; returns passed, failed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Definitions.Classes)
local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local Skills = require(ReplicatedStorage.Shared.Definitions.Skills)
local Geometry = require(script.Parent.Parent.Util.Geometry)
local ProfileRules = require(script.Parent.Parent.Util.ProfileRules)

type Case = { name: string, run: () -> (boolean, string?) }

-- Far above the world so line-of-sight never meets scene collision.
local SKY = Vector3.new(0, 5000, 0)

local cases: { Case } = {
	{
		name = "three classes with Thai names; samurai and ninja open, onmyoji not yet",
		run = function()
			local names = {}
			for _, c in Classes.List do
				table.insert(names, c.id .. "=" .. c.displayNameTH .. (if c.available then "" else "(closed)"))
			end
			local ok = #Classes.List == 3
				and Classes.Get("blade").displayNameTH == "ซามูไร"
				and Classes.Get("shade").displayNameTH == "นินจา"
				and Classes.Get("talisman").displayNameTH == "องเมียวจิ"
				and Classes.Get("blade").available
				and Classes.Get("shade").available
				and not Classes.Get("talisman").available
			return ok, table.concat(names, " ")
		end,
	},
	{
		name = "open classes name real skills of their own class",
		run = function()
			for _, c in Classes.List do
				if c.available then
					for _, id in { c.basicSkillId, c.activeSkillId } do
						local s = Skills[id]
						if not s or s.classId ~= c.id then
							return false, c.id .. " → " .. id
						end
					end
				end
			end
			return true, nil
		end,
	},
	{
		name = "samurai kit keeps the P1 numbers",
		run = function()
			local k = Classes.Kit("blade")
			local C = Prototype.Combat
			return k.basicDamage == C.BasicDamage
				and k.basicIntervalSec == C.BasicIntervalSec
				and k.basicReachStuds == C.BasicReachStuds
				and k.skill.id == Prototype.Skill.Id
				and k.skillDamage == Prototype.Skill.Damage,
				nil
		end,
	},
	{
		name = "ninja swings faster and lighter at about the same damage per second; E dashes the dash distance",
		run = function()
			local s, n = Classes.Kit("blade"), Classes.Kit("shade")
			local dpsS = s.basicDamage / s.basicIntervalSec
			local dpsN = n.basicDamage / n.basicIntervalSec
			local ok = n.basicIntervalSec < s.basicIntervalSec
				and n.basicDamage < s.basicDamage
				and math.abs(dpsN - dpsS) / dpsS < 0.05
				and n.skill.hitShape == "line"
				and n.skill.rangeStuds == Prototype.Dash.DistanceStuds
			return ok, string.format("dps %.1f vs %.1f", dpsN, dpsS)
		end,
	},
	{
		name = "unknown class falls back to the samurai kit",
		run = function()
			return Classes.Kit("nope").classId == "blade", nil
		end,
	},
	{
		name = "dash strip hits along the path only (not behind, past the end, wide or above)",
		run = function()
			local dir = Vector3.new(0, 0, -1)
			local function hit(x: number, y: number, z: number): boolean
				return Geometry.InStrip(SKY, dir, SKY + Vector3.new(x, y, z), 12, 5, 1)
			end
			local inside = hit(0, 0, -6) and hit(3, 0, -11) and hit(0, 0, -12.8)
			local outside = hit(0, 0, 2) or hit(0, 0, -14) or hit(4, 0, -6) or hit(0, 6, -6)
			return inside and not outside, nil
		end,
	},
	{
		name = "profile validation rejects an unknown classId and accepts every listed one",
		run = function()
			local p = ProfileRules.New(1, "blade")
			for _, c in Classes.List do
				p.classId = c.id
				if not ProfileRules.Validate(p) then
					return false, c.id
				end
			end
			p.classId = "pirate"
			local ok, field = ProfileRules.Validate(p)
			return not ok and field == "classId", field
		end,
	},
}

local ClassesTest = {}

function ClassesTest.Run(): (number, number)
	local passed, failed = 0, 0
	for _, case in cases do
		local ok, result, detail = pcall(case.run)
		if ok and result then
			passed += 1
			print("[ClassesTest] PASS", case.name, detail or "")
		else
			failed += 1
			warn("[ClassesTest] FAIL", case.name, if ok then detail else result)
		end
	end
	print(string.format("[ClassesTest] %d passed, %d failed", passed, failed))
	return passed, failed
end

return ClassesTest

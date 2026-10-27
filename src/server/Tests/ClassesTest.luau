--!strict
-- M4 class tests: catalog, kits, the ninja's dash-strike strip and profile
-- validation of classId. Run in Studio (server Command Bar):
--   require(game.ServerScriptService.Server.Tests.ClassesTest).Run()
-- Prints one line per case and a summary; returns passed, failed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Definitions.Classes)
local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local Skills = require(ReplicatedStorage.Shared.Definitions.Skills)
local ClassRules = require(script.Parent.Parent.Util.ClassRules)
local Geometry = require(script.Parent.Parent.Util.Geometry)
local ProfileMigrations = require(script.Parent.Parent.Util.ProfileMigrations)
local ProfileRules = require(script.Parent.Parent.Util.ProfileRules)
local SkillRules = require(ReplicatedStorage.Shared.Util.SkillRules)

type Case = { name: string, run: () -> (boolean, string?) }

-- Far above the world so line-of-sight never meets scene collision.
local SKY = Vector3.new(0, 5000, 0)

local cases: { Case } = {
	{
		name = "three classes with Thai names, all open",
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
				and Classes.Get("talisman").available
			return ok, table.concat(names, " ")
		end,
	},
	{
		name = "open classes name real skills of their own class",
		run = function()
			for _, c in Classes.List do
				if c.available then
					for _, id in { c.basicSkillId, table.unpack(c.skillIds) } do
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
		name = "onmyoji hits from about 3x samurai reach at lower damage per second; E is a circle ahead",
		run = function()
			local s, o = Classes.Kit("blade"), Classes.Kit("talisman")
			local dpsS = s.basicDamage / s.basicIntervalSec
			local dpsO = o.basicDamage / o.basicIntervalSec
			local ok = o.basicShape == "bolt"
				and o.basicReachStuds >= s.basicReachStuds * 3
				and dpsO < dpsS
				and o.skill.hitShape == "circle"
				and (o.skill.radiusStuds or 0) > 0
				and o.skill.rangeStuds > (o.skill.radiusStuds or 0)
			return ok, string.format("reach %d vs %d, dps %.1f vs %.1f", o.basicReachStuds, s.basicReachStuds, dpsO, dpsS)
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
	{
		name = "class is picked once: first pick sets it, any later pick is CLASS_LOCKED and changes nothing",
		run = function()
			local p = ProfileRules.New(1, "blade")
			local unknown = ClassRules.Choose(p, "pirate")
			local first = ClassRules.Choose(p, "shade")
			local again = ClassRules.Choose(p, "talisman")
			local same = ClassRules.Choose(p, "shade")
			local ok = unknown == "INVALID_PAYLOAD" and first == "OK" and again == "CLASS_LOCKED" and same == "CLASS_LOCKED"
				and p.classId == "shade" and p.classChosen == true
			return ok, table.concat({ unknown, first, again, same }, "/")
		end,
	},
	{
		name = "a new profile has not picked a class and has no skill points",
		run = function()
			local p = ProfileRules.New(1, "blade")
			return p.classChosen == false and p.skillPoints == 0 and next(p.skills) == nil and ProfileRules.Validate(p), nil
		end,
	},
	{
		name = "each level-up gives 2 skill points; cap is 20",
		run = function()
			local p = ProfileRules.New(1, "blade")
			local need = 0
			for level = 1, 4 do
				need += ProfileRules.XpToNext(level) :: number
			end
			ProfileRules.AddXp(p, need) -- level 1 → 5
			return p.level == 5 and p.skillPoints == 8 and ProfileRules.LevelCap == 20, string.format("L%d sp %d", p.level, p.skillPoints)
		end,
	},
	{
		name = "migration v1 → v2: class must be picked again, points match the level, no skills",
		run = function()
			local old: any = ProfileRules.New(1, "talisman")
			old.schemaVersion = 1
			old.level = 4
			old.classChosen, old.skillPoints, old.skills = nil, nil, nil
			local p = ProfileMigrations.Load(old)
			return p ~= nil and p.schemaVersion == 2 and p.classChosen == false and p.skillPoints == 6 and next(p.skills) == nil,
				p and string.format("v%d sp %d", p.schemaVersion, p.skillPoints) or "refused"
		end,
	},
	{
		name = "validation rejects bad skill data",
		run = function()
			local bad = {
				function(p) p.classChosen = "yes" end,
				function(p) p.skillPoints = -1 end,
				function(p) p.skillPoints = 0.5 end,
				function(p) p.skills = { nope = 1 } end,
				function(p) p.skills = { blade_sweep = 0 } end,
				function(p) p.skills = { blade_sweep = 99 } end,
			}
			for i, breakIt in bad do
				local p: any = ProfileRules.New(1, "blade")
				breakIt(p)
				if ProfileRules.Validate(p) then
					return false, "case " .. i
				end
			end
			local good = ProfileRules.New(1, "blade")
			good.skills = { blade_sweep = 3 }
			return ProfileRules.Validate(good), nil
		end,
	},
}


-- M4 skill system (SkillRules).
local function chosen(classId: string, level: number, points: number): any
	local p: any = ProfileRules.New(1, classId)
	p.classChosen = true
	p.level = level
	p.skillPoints = points
	return p
end

local skillCases: { Case } = {
	{
		name = "every class has 5 hotbar skills, unlocking in order within the level cap, all costing SP",
		run = function()
			for _, c in Classes.List do
				if #c.skillIds ~= 5 then
					return false, c.id .. " has " .. #c.skillIds
				end
				local last = 0
				for i, id in c.skillIds do
					local s = Skills[id]
					if s.unlockLevel < last or s.unlockLevel > ProfileRules.LevelCap or s.spCost <= 0 then
						return false, id
					end
					if i == 1 and s.unlockLevel ~= 1 then
						return false, id .. " slot 1 must unlock at 1"
					end
					last = s.unlockLevel
				end
			end
			return true, nil
		end,
	},
	{
		name = "slot 1 is known at rank 1 for free; other slots start unlearned",
		run = function()
			local p = chosen("blade", 1, 0)
			return SkillRules.Rank(p, "blade_sweep") == 1 and SkillRules.Rank(p, "blade_iai") == 0
				and SkillRules.CanCast(p, "blade_sweep") == "OK" and SkillRules.CanCast(p, "blade_iai") == "SKILL_LOCKED"
				and SkillRules.CanCast(p, "shade_step") == "NOT_OWNED",
				nil
		end,
	},
	{
		name = "learn: level gate, points, max rank, other class, unknown, not chosen",
		run = function()
			local p = chosen("blade", 3, 2)
			local low = SkillRules.Learn(chosen("blade", 2, 5), "blade_iai")
			local ok1 = SkillRules.Learn(p, "blade_iai")
			local ok2 = SkillRules.Learn(p, "blade_iai")
			local broke = SkillRules.Learn(p, "blade_iai")
			local other = SkillRules.Learn(chosen("blade", 20, 5), "shade_step")
			local unknown = SkillRules.Learn(chosen("blade", 20, 5), "nope")
			local fresh: any = ProfileRules.New(1, "blade")
			fresh.skillPoints = 5
			local notChosen = SkillRules.Learn(fresh, "blade_sweep")
			local maxed = chosen("blade", 20, 10)
			for _ = 1, 4 do
				SkillRules.Learn(maxed, "blade_sweep")
			end
			local top = SkillRules.Learn(maxed, "blade_sweep")
			local ok = low == "SKILL_LOCKED" and ok1 == "OK" and ok2 == "OK" and broke == "NO_SKILL_POINTS"
				and p.skills.blade_iai == 2 and p.skillPoints == 0 and SkillRules.CanCast(p, "blade_iai") == "OK"
				and other == "NOT_OWNED" and unknown == "INVALID_PAYLOAD" and notChosen == "NOT_READY"
				and top == "MAX_RANK" and maxed.skills.blade_sweep == 5 and maxed.skillPoints == 6
				and ProfileRules.Validate(p) and ProfileRules.Validate(maxed)
			return ok, table.concat({ low, ok1, ok2, broke, other, unknown, notChosen, top }, "/")
		end,
	},
	{
		name = "rank scales damage +15% a rank; rank 1 slot-1 damage is the P1 number",
		run = function()
			local sweep = Skills.blade_sweep
			local r1, r5 = SkillRules.Damage(sweep, 1), SkillRules.Damage(sweep, 5)
			return r1 == Prototype.Skill.Damage and r5 == math.floor(30 * 1.6 + 0.5), string.format("%d → %d", r1, r5)
		end,
	},
	{
		name = "SP: max grows with level, regenerates to the max and no further",
		run = function()
			local m1, m10 = SkillRules.MaxSp(1), SkillRules.MaxSp(10)
			local after2 = SkillRules.SpAt(10, 100, m1, 102)
			local capped = SkillRules.SpAt(10, 100, m1, 10000)
			return m1 == 60 and m10 == 105 and after2 == 10 + 2 * SkillRules.SpRegenPerSec and capped == m1,
				string.format("max %d/%d", m1, m10)
		end,
	},
}
for _, case in skillCases do
	table.insert(cases, case)
end

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

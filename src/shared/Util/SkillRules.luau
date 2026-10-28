--!strict
-- M4 skill rules (pure, shared so the client shows the same numbers the
-- server enforces). A class's hotbar skills are Classes skillIds; slot 1 is
-- known at rank 1 for free, the rest are learned with skill points once the
-- level allows. Each rank above 1 adds RankStep to damage (and a little to
-- buff time and heal). SP: max grows with level, regenerates over time.
-- Passives (M4-E) are learned the same way and add to a stat (Bonus).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Definitions.Classes)
local Skills = require(ReplicatedStorage.Shared.Definitions.Skills)

-- The profile fields these rules read (ProfileV1 v2 or a snapshot profile).
export type SkillProfile = {
	classId: string,
	classChosen: boolean,
	level: number,
	skillPoints: number,
	skills: { [string]: number },
}

export type CastCode = "OK" | "NOT_OWNED" | "SKILL_LOCKED"
export type LearnCode = "OK" | "INVALID_PAYLOAD" | "NOT_READY" | "NOT_OWNED" | "SKILL_LOCKED" | "MAX_RANK" | "NO_SKILL_POINTS"

local SkillRules = {}

SkillRules.RankStep = 0.15
SkillRules.SpBase = 60
SkillRules.SpPerLevel = 5
SkillRules.SpRegenPerSec = 3

-- Hotbar slot of `skillId` in the class, or nil if the class lacks it.
function SkillRules.Slot(classId: string, skillId: string): number?
	local class = Classes.Get(classId)
	return class and table.find(class.skillIds, skillId)
end

-- True for the class's hotbar skills and passives (what learn_skill accepts).
function SkillRules.Owns(classId: string, skillId: string): boolean
	local class = Classes.Get(classId)
	return class ~= nil and (table.find(class.skillIds, skillId) ~= nil or table.find(class.passiveIds, skillId) ~= nil)
end

-- Learned rank (0 = not learned). Slot 1 is always at least rank 1.
function SkillRules.Rank(profile: SkillProfile, skillId: string): number
	local learned = profile.skills[skillId] or 0
	if learned == 0 and SkillRules.Slot(profile.classId, skillId) == 1 then
		return 1
	end
	return learned
end

function SkillRules.Scale(rank: number): number
	return 1 + SkillRules.RankStep * (math.max(rank, 1) - 1)
end

function SkillRules.Damage(skill: Skills.SkillDef, rank: number): number
	return math.floor(Classes.WeaponBaseDamage * skill.damageMultiplier * SkillRules.Scale(rank) + 0.5)
end

function SkillRules.BuffSec(skill: Skills.SkillDef, rank: number): number
	return (skill.buffSec or 0) + (math.max(rank, 1) - 1)
end

function SkillRules.HealFraction(skill: Skills.SkillDef, rank: number): number
	return (skill.healFraction or 0) + 0.03 * (math.max(rank, 1) - 1)
end

function SkillRules.RootSec(skill: Skills.SkillDef, rank: number): number
	return (skill.rootSec or 0) + 0.25 * (math.max(rank, 1) - 1)
end

-- Sum of the class's learned passives for `stat` (0 when none learned).
function SkillRules.Bonus(profile: SkillProfile, stat: Skills.PassiveStat): number
	local class = Classes.Get(profile.classId)
	local total = 0
	for _, id in if class then class.passiveIds else {} do
		local skill = Skills[id]
		if skill.passiveStat == stat then
			total += (skill.passivePerRank or 0) * (profile.skills[id] or 0)
		end
	end
	return total
end

function SkillRules.MaxSp(level: number): number
	return SkillRules.SpBase + SkillRules.SpPerLevel * (math.max(level, 1) - 1)
end

-- SP now from the last stored value and when it was stored.
function SkillRules.SpAt(sp: number, spAt: number, maxSp: number, now: number): number
	return math.min(maxSp, sp + math.max(0, now - spAt) * SkillRules.SpRegenPerSec)
end

function SkillRules.CanCast(profile: SkillProfile, skillId: string): CastCode
	local skill = Skills[skillId]
	if not skill or not SkillRules.Slot(profile.classId, skillId) then
		return "NOT_OWNED"
	end
	if profile.level < skill.unlockLevel or SkillRules.Rank(profile, skillId) < 1 then
		return "SKILL_LOCKED"
	end
	return "OK"
end

-- Spends one skill point to raise `skillId` one rank (mutates on OK only).
function SkillRules.Learn(profile: SkillProfile, skillId: string): LearnCode
	local skill = Skills[skillId]
	if not skill then
		return "INVALID_PAYLOAD"
	end
	if not profile.classChosen then
		return "NOT_READY"
	end
	if not SkillRules.Owns(profile.classId, skillId) then
		return "NOT_OWNED"
	end
	if profile.level < skill.unlockLevel then
		return "SKILL_LOCKED"
	end
	local rank = SkillRules.Rank(profile, skillId)
	if rank >= skill.maxRank then
		return "MAX_RANK"
	end
	if profile.skillPoints < 1 then
		return "NO_SKILL_POINTS"
	end
	profile.skills[skillId] = rank + 1
	profile.skillPoints -= 1
	return "OK"
end

return SkillRules

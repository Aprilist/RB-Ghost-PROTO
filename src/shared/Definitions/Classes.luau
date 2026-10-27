--!strict
-- Class catalog (M4). IDs stay as in docs/CONTRACTS.md (blade/shade/talisman)
-- so saved profiles keep working; players see the Thai names. Each class
-- names its basic attack and hotbar skills in Definitions/Skills. Damage is the
-- weapon's baseDamage × the skill's damageMultiplier, as for the samurai.
-- All three are playable with a draft kit; art, animation and a full skill
-- set come with the full class pass.
-- Picked once on first join and locked (Director 28 Oct 2026, ClassRules).

local Items = require(script.Parent.Items)
local Progression = require(script.Parent.Progression)
local Skills = require(script.Parent.Skills)

export type ClassDef = {
	id: string,
	displayNameTH: string,
	descriptionTH: string,
	basicSkillId: string,
	-- Hotbar skills in key order 1–5 (M4 skill system); [1] is free at rank 1.
	skillIds: { string },
	available: boolean,
}

-- What combat needs for one class, worked out once.
export type Kit = {
	classId: string,
	basicDamage: number,
	basicIntervalSec: number,
	basicReachStuds: number,
	basicArcDeg: number,
	basicShape: Skills.HitShape,
	skill: Skills.SkillDef, -- hotbar slot 1 (E)
	skillDamage: number,
	skillIds: { string },
}

local Classes = {}

Classes.StationNpcId = "npc_trainer"

Classes.List = table.freeze({
	table.freeze({
		id = "blade",
		displayNameTH = "ซามูไร",
		descriptionTH = "คาตานะ ประชิด ฟันเป็นวงกว้าง สกิลหนักและบัฟ",
		basicSkillId = "blade_basic",
		skillIds = { "blade_sweep", "blade_iai", "blade_whirl", "blade_focus", "blade_cleave" },
		available = true,
	}),
	table.freeze({
		id = "shade",
		displayNameTH = "นินจา",
		descriptionTH = "ดาบสั้น ฟันเร็ว พุ่งเข้าออกไว ปาคุไนได้",
		basicSkillId = "shade_basic",
		skillIds = { "shade_step", "shade_kunai", "shade_flurry", "shade_veil", "shade_storm" },
		available = true,
	}),
	table.freeze({
		id = "talisman",
		displayNameTH = "องเมียวจิ",
		descriptionTH = "ยันต์ ตีไกล สกิลพื้นที่ และฮีลตัวเอง",
		basicSkillId = "talisman_basic",
		skillIds = { "talisman_seal", "talisman_thunder", "talisman_mend", "talisman_fox", "talisman_aura" },
		available = true,
	}),
}) :: { ClassDef }

local byId: { [string]: ClassDef } = {}
for _, c in Classes.List do
	byId[c.id] = c
end

function Classes.Get(classId: string): ClassDef?
	return byId[classId]
end

local weapon = Items[Progression.StartingWeaponId]
-- Skill damage = this × skill damageMultiplier × rank scale (Util/SkillRules).
Classes.WeaponBaseDamage = weapon.baseDamage
local kits: { [string]: Kit } = {}

-- Combat numbers for a class; an unknown id falls back to the samurai so a
-- bad value can never leave a player without attacks.
function Classes.Kit(classId: string): Kit
	local c = byId[classId] or byId.blade
	local kit = kits[c.id]
	if not kit then
		local basic = Skills[c.basicSkillId]
		local skill = Skills[c.skillIds[1]]
		kit = table.freeze({
			classId = c.id,
			basicDamage = weapon.baseDamage * basic.damageMultiplier,
			basicIntervalSec = basic.cooldownSec,
			basicReachStuds = basic.rangeStuds,
			basicArcDeg = basic.arcDeg,
			basicShape = basic.hitShape,
			skill = skill,
			skillDamage = weapon.baseDamage * skill.damageMultiplier,
			skillIds = c.skillIds,
		})
		kits[c.id] = kit
	end
	return kit
end

return Classes

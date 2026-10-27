--!strict
-- Class catalog (M4). IDs stay as in docs/CONTRACTS.md (blade/shade/talisman)
-- so saved profiles keep working; players see the Thai names. Each class
-- names its basic attack and E skill in Definitions/Skills. Damage is the
-- weapon's baseDamage × the skill's damageMultiplier, as for the samurai.
-- All three are playable with a draft kit; art, animation and a full skill
-- set come with the full class pass.
-- Classes are switched freely at the trainer NPC for now (GAME_DESIGN: try
-- classes before choosing); the level-10 trial comes later.

local Items = require(script.Parent.Items)
local Progression = require(script.Parent.Progression)
local Skills = require(script.Parent.Skills)

export type ClassDef = {
	id: string,
	displayNameTH: string,
	descriptionTH: string,
	basicSkillId: string,
	activeSkillId: string,
	available: boolean,
}

-- What combat needs for one class, worked out once.
export type Kit = {
	classId: string,
	basicDamage: number,
	basicIntervalSec: number,
	basicReachStuds: number,
	basicArcDeg: number,
	basicShape: "sector" | "line" | "bolt" | "circle",
	skill: Skills.SkillDef,
	skillDamage: number,
}

local Classes = {}

Classes.StationNpcId = "npc_trainer"

Classes.List = table.freeze({
	table.freeze({
		id = "blade",
		displayNameTH = "ซามูไร",
		descriptionTH = "คาตานะ ฟันเป็นวงกว้าง สกิล E ฟันกวาดรอบหน้า",
		basicSkillId = "blade_basic",
		activeSkillId = "blade_sweep",
		available = true,
	}),
	table.freeze({
		id = "shade",
		displayNameTH = "นินจา",
		descriptionTH = "ดาบสั้น ฟันเร็วแต่แคบ สกิล E พุ่งผ่านเงา ฟันทุกตัวตามแนว",
		basicSkillId = "shade_basic",
		activeSkillId = "shade_step",
		available = true,
	}),
	table.freeze({
		id = "talisman",
		displayNameTH = "องเมียวจิ",
		descriptionTH = "ยันต์ ปาไกลทีละตัว สกิล E วางวงยันต์ข้างหน้า โดนทุกตัวในวง",
		basicSkillId = "talisman_basic",
		activeSkillId = "talisman_seal",
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
local kits: { [string]: Kit } = {}

-- Combat numbers for a class; an unknown id falls back to the samurai so a
-- bad value can never leave a player without attacks.
function Classes.Kit(classId: string): Kit
	local c = byId[classId] or byId.blade
	local kit = kits[c.id]
	if not kit then
		local basic = Skills[c.basicSkillId]
		local skill = Skills[c.activeSkillId]
		kit = table.freeze({
			classId = c.id,
			basicDamage = weapon.baseDamage * basic.damageMultiplier,
			basicIntervalSec = basic.cooldownSec,
			basicReachStuds = basic.rangeStuds,
			basicArcDeg = basic.arcDeg,
			basicShape = basic.hitShape,
			skill = skill,
			skillDamage = weapon.baseDamage * skill.damageMultiplier,
		})
		kits[c.id] = kit
	end
	return kit
end

return Classes

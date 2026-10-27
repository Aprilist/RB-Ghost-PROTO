--!strict
-- Skill catalog (M2-A). Fields follow "Definition schema → Skill" in
-- docs/CONTRACTS.md; `arcDeg` is a proposed addition for sector hits.
-- Damage = equipped weapon baseDamage × damageMultiplier, so the P1 numbers
-- (20 / 30 / 25 with training_blade) are unchanged.

export type SkillDef = {
	id: string,
	classId: string,
	displayNameTH: string,
	cooldownSec: number,
	rangeStuds: number,
	hitShape: "sector",
	arcDeg: number,
	damageMultiplier: number,
	windupSec: number,
	recoverySec: number,
	effectNotes: string,
}

local Skills: { [string]: SkillDef } = {
	blade_basic = {
		id = "blade_basic",
		classId = "blade",
		displayNameTH = "ฟัน",
		cooldownSec = 0.5, -- combo interval
		rangeStuds = 7,
		hitShape = "sector",
		arcDeg = 100,
		damageMultiplier = 1,
		windupSec = 0,
		recoverySec = 0,
		effectNotes = "คอมโบ 3 จังหวะ ขวา→ซ้าย ซ้าย→ขวา ปิดกว้าง",
	},
	blade_sweep = {
		id = "blade_sweep",
		classId = "blade",
		displayNameTH = "ฟันกวาด",
		cooldownSec = 5,
		rangeStuds = 7,
		hitShape = "sector",
		arcDeg = 160,
		damageMultiplier = 1.5,
		windupSec = 0,
		recoverySec = 0,
		effectNotes = "วงกวาดรอบหน้า",
	},
	guardian_wave = {
		id = "guardian_wave",
		classId = "blade",
		displayNameTH = "คลื่นผู้พิทักษ์",
		cooldownSec = 0.5,
		rangeStuds = 10,
		hitShape = "sector",
		arcDeg = 90,
		damageMultiplier = 1.25,
		windupSec = 0,
		recoverySec = 0,
		effectNotes = "แทน basic attack ระหว่างแปลงร่าง",
	},
}

return Skills

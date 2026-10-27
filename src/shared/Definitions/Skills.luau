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
	-- "sector" round the player; "line" = dash forward rangeStuds and hit a
	-- strip widthStuds wide along the path (M4 ninja).
	hitShape: "sector" | "line",
	arcDeg: number,
	widthStuds: number?,
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
	-- M4 ninja (draft numbers): faster, lighter swings, same damage per second
	-- as the samurai (14 / 0.35 s ≈ 20 / 0.5 s); the skill is a dash strike.
	shade_basic = {
		id = "shade_basic",
		classId = "shade",
		displayNameTH = "ฟันดาบสั้น",
		cooldownSec = 0.35,
		rangeStuds = 6,
		hitShape = "sector",
		arcDeg = 80,
		damageMultiplier = 0.7,
		windupSec = 0,
		recoverySec = 0,
		effectNotes = "คอมโบ 3 จังหวะ เร็วแต่แคบ",
	},
	shade_step = {
		id = "shade_step",
		classId = "shade",
		displayNameTH = "พุ่งผ่านเงา",
		cooldownSec = 4,
		rangeStuds = 12, -- = Prototype.Dash.DistanceStuds; movement uses the dash authority
		hitShape = "line",
		arcDeg = 0,
		widthStuds = 5,
		damageMultiplier = 1.6,
		windupSec = 0,
		recoverySec = 0,
		effectNotes = "พุ่งไปข้างหน้า ฟันทุกตัวตามแนวที่ผ่าน",
	},
}

return Skills

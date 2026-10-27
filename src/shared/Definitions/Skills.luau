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
	-- strip widthStuds wide along the path (M4 ninja); "bolt" = the nearest
	-- one target in a narrow sector (M4 onmyoji); "circle" = every target
	-- within radiusStuds of a point rangeStuds ahead (M4 onmyoji).
	hitShape: "sector" | "line" | "bolt" | "circle",
	arcDeg: number,
	widthStuds: number?,
	radiusStuds: number?,
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
	-- M4 onmyoji (draft numbers): ranged single target at lower damage per
	-- second (18 / 0.6 s = 30) than melee (40) to pay for the range; the skill
	-- is an area seal placed ahead. Pinning enemies in place comes with the
	-- full class pass.
	talisman_basic = {
		id = "talisman_basic",
		classId = "talisman",
		displayNameTH = "ยันต์พุ่ง",
		cooldownSec = 0.6,
		rangeStuds = 22,
		hitShape = "bolt",
		arcDeg = 16,
		damageMultiplier = 0.9,
		windupSec = 0,
		recoverySec = 0,
		effectNotes = "ปายันต์ไปโดนตัวที่ใกล้ที่สุดในแนวเล็ง",
	},
	talisman_seal = {
		id = "talisman_seal",
		classId = "talisman",
		displayNameTH = "เขตยันต์ตรึง",
		cooldownSec = 6,
		rangeStuds = 14, -- centre of the circle, cut short by walls
		hitShape = "circle",
		arcDeg = 360,
		radiusStuds = 8,
		damageMultiplier = 1.5,
		windupSec = 0,
		recoverySec = 0,
		effectNotes = "วางวงยันต์ข้างหน้า ทุกตัวในวงโดน",
	},
}

return Skills

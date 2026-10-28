--!strict
-- Skill catalog (M2-A, M4). Fields follow "Definition schema → Skill" in
-- docs/CONTRACTS.md. Damage = equipped weapon baseDamage × damageMultiplier
-- × rank scale (Util/SkillRules), so the P1 numbers (20 / 30 / 25 with
-- training_blade) are unchanged at rank 1.
-- M4 skill system (GAME_DESIGN "ระบบสกิล"): each class has hotbar skills
-- (Classes.skillIds, keys 1–5) unlocked by level and learned with skill
-- points up to maxRank; every hotbar skill costs SP. Names and numbers are
-- our own draft; tune after playtest.

export type HitShape =
	"sector" -- round the player within arcDeg
	| "line" -- dash forward rangeStuds, hit a widthStuds strip along the path
	| "bolt" -- the nearest one target in a narrow sector
	| "circle" -- every target within radiusStuds of a point rangeStuds ahead (0 = on self)
	| "buff" -- damage × buffMult for buffSec
	| "heal" -- heal healFraction of max HP
	| "passive" -- never cast; each rank adds passivePerRank to passiveStat

-- What a passive raises (SkillRules.Bonus). Pct values are fractions.
export type PassiveStat = "basicDamagePct" | "skillDamagePct" | "maxHpPct" | "maxSpFlat"

export type SkillDef = {
	id: string,
	classId: string,
	displayNameTH: string,
	cooldownSec: number,
	rangeStuds: number,
	hitShape: HitShape,
	arcDeg: number,
	widthStuds: number?,
	radiusStuds: number?,
	buffMult: number?,
	buffSec: number?,
	healFraction: number?,
	rootSec: number?, -- enemies hit cannot move or start an attack (bosses immune)
	passiveStat: PassiveStat?,
	passivePerRank: number?,
	damageMultiplier: number,
	windupSec: number,
	recoverySec: number,
	-- M4: level the skill unlocks at, highest learnable rank, SP per cast.
	unlockLevel: number,
	maxRank: number,
	spCost: number,
	effectNotes: string,
}

local Skills: { [string]: SkillDef } = {}

local function add(def: { [string]: any })
	def.windupSec = def.windupSec or 0
	def.recoverySec = def.recoverySec or 0
	def.arcDeg = def.arcDeg or 0
	def.rangeStuds = def.rangeStuds or 0
	def.damageMultiplier = def.damageMultiplier or 0
	def.unlockLevel = def.unlockLevel or 1
	def.maxRank = def.maxRank or 5
	def.spCost = def.spCost or 0
	Skills[def.id] = table.freeze(def) :: any
end

-- Basic attacks and the transform wave: not on the hotbar, no SP, rank 1.
add({ id = "blade_basic", classId = "blade", displayNameTH = "ฟัน", cooldownSec = 0.5, rangeStuds = 7, hitShape = "sector", arcDeg = 100, damageMultiplier = 1, maxRank = 1,
	effectNotes = "คอมโบ 3 จังหวะ ขวา→ซ้าย ซ้าย→ขวา ปิดกว้าง" })
add({ id = "guardian_wave", classId = "blade", displayNameTH = "คลื่นผู้พิทักษ์", cooldownSec = 0.5, rangeStuds = 10, hitShape = "sector", arcDeg = 90, damageMultiplier = 1.25, maxRank = 1,
	effectNotes = "แทน basic attack ระหว่างแปลงร่าง" })
add({ id = "shade_basic", classId = "shade", displayNameTH = "ฟันดาบสั้น", cooldownSec = 0.35, rangeStuds = 6, hitShape = "sector", arcDeg = 80, damageMultiplier = 0.7, maxRank = 1,
	effectNotes = "คอมโบ 3 จังหวะ เร็วแต่แคบ" })
add({ id = "talisman_basic", classId = "talisman", displayNameTH = "ยันต์พุ่ง", cooldownSec = 0.6, rangeStuds = 22, hitShape = "bolt", arcDeg = 16, damageMultiplier = 0.9, maxRank = 1,
	effectNotes = "ปายันต์ไปโดนตัวที่ใกล้ที่สุดในแนวเล็ง" })

-- Samurai: wide melee, one dash strike, a big single hit.
add({ id = "blade_sweep", classId = "blade", displayNameTH = "ฟันกวาด", unlockLevel = 1, spCost = 10, cooldownSec = 5, rangeStuds = 7, hitShape = "sector", arcDeg = 160, damageMultiplier = 1.5,
	effectNotes = "ฟันกวาดเป็นวงหน้าตัว" })
add({ id = "blade_iai", classId = "blade", displayNameTH = "ชักดาบสายฟ้า", unlockLevel = 3, spCost = 15, cooldownSec = 8, rangeStuds = 12, hitShape = "line", widthStuds = 4, damageMultiplier = 2,
	effectNotes = "พุ่งไปข้างหน้าแล้วชักดาบฟันทุกตัวตามแนว" })
add({ id = "blade_whirl", classId = "blade", displayNameTH = "พายุใบดาบ", unlockLevel = 6, spCost = 20, cooldownSec = 10, rangeStuds = 9, hitShape = "sector", arcDeg = 360, damageMultiplier = 1.8,
	effectNotes = "หมุนตัวฟันรอบทิศ" })
add({ id = "blade_focus", classId = "blade", displayNameTH = "จิตนิ่ง", unlockLevel = 9, spCost = 20, cooldownSec = 25, hitShape = "buff", buffMult = 1.3, buffSec = 8,
	effectNotes = "ดาเมจทุกท่า +30% ชั่วครู่" })
add({ id = "blade_cleave", classId = "blade", displayNameTH = "ฟันผ่าภูผา", unlockLevel = 12, spCost = 25, cooldownSec = 12, rangeStuds = 9, hitShape = "sector", arcDeg = 60, damageMultiplier = 3.5,
	effectNotes = "ฟันแรงเดียว แคบแต่หนักที่สุด" })

-- Ninja: mobility, a ranged throw, bursts round itself.
add({ id = "shade_step", classId = "shade", displayNameTH = "พุ่งผ่านเงา", unlockLevel = 1, spCost = 10, cooldownSec = 4, rangeStuds = 12, hitShape = "line", widthStuds = 5, damageMultiplier = 1.6,
	effectNotes = "พุ่งไปข้างหน้า ฟันทุกตัวตามแนวที่ผ่าน" })
add({ id = "shade_kunai", classId = "shade", displayNameTH = "คุไนเงา", unlockLevel = 3, spCost = 8, cooldownSec = 3, rangeStuds = 18, hitShape = "bolt", arcDeg = 20, damageMultiplier = 1.3,
	effectNotes = "ปาคุไนไปโดนตัวที่ใกล้ที่สุดในแนวเล็ง" })
add({ id = "shade_flurry", classId = "shade", displayNameTH = "ฟันเงาพันคม", unlockLevel = 6, spCost = 15, cooldownSec = 8, rangeStuds = 6, hitShape = "sector", arcDeg = 120, damageMultiplier = 2.4,
	effectNotes = "ฟันรัวหน้าตัว" })
add({ id = "shade_veil", classId = "shade", displayNameTH = "ม่านเงา", unlockLevel = 9, spCost = 15, cooldownSec = 18, hitShape = "buff", buffMult = 1.25, buffSec = 6,
	effectNotes = "ดาเมจทุกท่า +25% ชั่วครู่" })
add({ id = "shade_storm", classId = "shade", displayNameTH = "พายุดาวกระจาย", unlockLevel = 12, spCost = 20, cooldownSec = 12, rangeStuds = 0, hitShape = "circle", radiusStuds = 8, damageMultiplier = 2,
	effectNotes = "ซัดดาวกระจายรอบตัว" })

-- Onmyoji: ranged and area, one heal, one buff.
add({ id = "talisman_seal", classId = "talisman", displayNameTH = "เขตยันต์ตรึง", unlockLevel = 1, spCost = 15, cooldownSec = 6, rangeStuds = 14, hitShape = "circle", radiusStuds = 8, damageMultiplier = 1.5,
	rootSec = 2.5,
	effectNotes = "วางวงยันต์ข้างหน้า ทุกตัวในวงโดนและถูกตรึงอยู่กับที่ (บอสไม่ติด)" })
add({ id = "talisman_thunder", classId = "talisman", displayNameTH = "ยันต์อัสนี", unlockLevel = 3, spCost = 12, cooldownSec = 5, rangeStuds = 20, hitShape = "sector", arcDeg = 20, damageMultiplier = 1.4,
	effectNotes = "สายฟ้าแนวยาว โดนทุกตัวในแนวเล็ง" })
add({ id = "talisman_mend", classId = "talisman", displayNameTH = "ยันต์ฟื้นกาย", unlockLevel = 6, spCost = 25, cooldownSec = 20, hitShape = "heal", healFraction = 0.25,
	effectNotes = "ฟื้น HP 25% ของสูงสุด" })
add({ id = "talisman_fox", classId = "talisman", displayNameTH = "จิ้งจอกไฟ", unlockLevel = 9, spCost = 25, cooldownSec = 12, rangeStuds = 14, hitShape = "circle", radiusStuds = 10, damageMultiplier = 2.2,
	effectNotes = "เรียกไฟจิ้งจอกลงวงใหญ่ข้างหน้า" })
add({ id = "talisman_aura", classId = "talisman", displayNameTH = "ยันต์เสริมพลัง", unlockLevel = 12, spCost = 20, cooldownSec = 25, hitShape = "buff", buffMult = 1.3, buffSec = 8,
	effectNotes = "ดาเมจทุกท่า +30% ชั่วครู่" })

-- Passives (M4-E): learned with skill points like hotbar skills, never cast,
-- no SP. Two per class: one for damage, one for staying power.
add({ id = "blade_mastery", classId = "blade", displayNameTH = "วิถีดาบ", unlockLevel = 2, cooldownSec = 0, hitShape = "passive", passiveStat = "basicDamagePct", passivePerRank = 0.06,
	effectNotes = "ติดตัว: ดาเมจโจมตีปกติเพิ่มขึ้น" })
add({ id = "blade_iron", classId = "blade", displayNameTH = "กายเหล็ก", unlockLevel = 5, cooldownSec = 0, hitShape = "passive", passiveStat = "maxHpPct", passivePerRank = 0.05,
	effectNotes = "ติดตัว: HP สูงสุดเพิ่มขึ้น" })
add({ id = "shade_vital", classId = "shade", displayNameTH = "จุดตาย", unlockLevel = 2, cooldownSec = 0, hitShape = "passive", passiveStat = "skillDamagePct", passivePerRank = 0.06,
	effectNotes = "ติดตัว: ดาเมจสกิลเพิ่มขึ้น" })
add({ id = "shade_breath", classId = "shade", displayNameTH = "ลมปราณเงา", unlockLevel = 5, cooldownSec = 0, hitShape = "passive", passiveStat = "maxSpFlat", passivePerRank = 6,
	effectNotes = "ติดตัว: SP สูงสุดเพิ่มขึ้น" })
add({ id = "talisman_focus", classId = "talisman", displayNameTH = "จิตสมาธิ", unlockLevel = 2, cooldownSec = 0, hitShape = "passive", passiveStat = "maxSpFlat", passivePerRank = 8,
	effectNotes = "ติดตัว: SP สูงสุดเพิ่มขึ้น" })
add({ id = "talisman_ward", classId = "talisman", displayNameTH = "ยันต์คุ้มกาย", unlockLevel = 5, cooldownSec = 0, hitShape = "passive", passiveStat = "maxHpPct", passivePerRank = 0.05,
	effectNotes = "ติดตัว: HP สูงสุดเพิ่มขึ้น" })

return table.freeze(Skills)

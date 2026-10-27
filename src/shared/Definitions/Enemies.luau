--!strict
-- Enemy catalog (M2-A). Fields follow "Definition schema → Enemy" in
-- docs/CONTRACTS.md. `tuning` holds AI/visual values the schema does not name
-- yet (proposed in handoff/M2_PLAN_PROPOSAL.md). `draft = true` marks entries
-- that are not implemented and still need design review.
-- lantern_wisp values are the P1 values unchanged (Director-tested).

-- How the attack resolves at the end of the telegraph (M2-C):
--   burst   circle of attackHitRangeStuds round the enemy (lantern wisp)
--   charge  rush along a line attackHitRangeStuds long, attackWidthStuds wide;
--           the enemy ends at the far end
--   leap    jump to the player's spot (at most attackHitRangeStuds away) and
--           slam a circle of radius attackWidthStuds there
--   lunge   strike along a line like charge, but the enemy stays put
export type AttackShape = "burst" | "charge" | "leap" | "lunge"

export type Tuning = {
	attackShape: AttackShape,
	attackHitRangeStuds: number, -- hit check at the end of the telegraph (see AttackShape)
	attackWidthStuds: number, -- line width (charge, lunge) or slam radius (leap)
	leashStuds: number,
	hoverHeightStuds: number,
	bodyRadiusStuds: number,
	maxAlive: number,
	groupSize: number, -- enemies per spawn marker
	steer: boolean, -- try side steps when a tree or wall blocks the way
	aiTickSec: number,
}

export type EnemyDef = {
	id: string,
	displayNameTH: string,
	zoneId: string,
	level: number,
	maxHp: number,
	attackDamage: number,
	telegraphSec: number,
	recoverSec: number,
	attackRangeStuds: number,
	detectionRangeStuds: number,
	moveSpeedStudsSec: number,
	respawnSec: number,
	xpReward: number,
	coinReward: number,
	essenceReward: number,
	gaugeReward: number,
	behaviorNotes: string,
	tuning: Tuning,
	draft: boolean,
}

local Enemies: { [string]: EnemyDef } = {
	lantern_wisp = {
		id = "lantern_wisp",
		displayNameTH = "ผีโคม",
		zoneId = "p1_arena",
		level = 1,
		maxHp = 60,
		attackDamage = 10,
		telegraphSec = 0.8,
		recoverSec = 1,
		attackRangeStuds = 5,
		detectionRangeStuds = 30,
		moveSpeedStudsSec = 8,
		respawnSec = 8,
		xpReward = 10,
		coinReward = 2,
		essenceReward = 5,
		gaugeReward = 10,
		behaviorNotes = "ลอยเข้าหา วงเตือนบนพื้นแล้วระเบิดรอบตัว",
		tuning = {
			attackShape = "burst",
			attackHitRangeStuds = 6.5,
			attackWidthStuds = 0, -- unused by burst
			leashStuds = 25,
			hoverHeightStuds = 3,
			bodyRadiusStuds = 1.5,
			maxAlive = 3,
			groupSize = 1,
			steer = false, -- P1 behaviour unchanged
			aiTickSec = 0.1,
		},
		draft = false,
	},
	-- M2-C Mistwood (Director 27 Oct 2026): basic, weak yokai first; the
	-- Hyakki Yagyō parade spirits come later. Each attack shape has its own
	-- telegraph so it reads apart from the wisp's ring round itself.
	hitodama = {
		id = "hitodama",
		displayNameTH = "ฮิโตดามะ",
		zoneId = "mistwood",
		level = 1,
		maxHp = 40,
		attackDamage = 6,
		telegraphSec = 0.7,
		recoverSec = 1,
		attackRangeStuds = 7,
		detectionRangeStuds = 28,
		moveSpeedStudsSec = 11,
		respawnSec = 8,
		xpReward = 8,
		coinReward = 1,
		essenceReward = 3,
		gaugeReward = 8,
		behaviorNotes = "ดวงไฟผีมาเป็นคู่ ลอยเร็ว ไฟลุกพร้อมแถบสั้นบนพื้น แล้วพุ่งชนตามแถบ",
		tuning = {
			attackShape = "charge",
			attackHitRangeStuds = 8, -- charge length
			attackWidthStuds = 3,
			leashStuds = 22,
			hoverHeightStuds = 3.5,
			bodyRadiusStuds = 1.1,
			maxAlive = 4,
			groupSize = 2,
			steer = true,
			aiTickSec = 0.1,
		},
		draft = false,
	},
	kodama = {
		id = "kodama",
		displayNameTH = "โคดามะ",
		zoneId = "mistwood",
		level = 1,
		maxHp = 50,
		attackDamage = 8,
		telegraphSec = 0.9,
		recoverSec = 1.2,
		attackRangeStuds = 4.5,
		detectionRangeStuds = 24,
		moveSpeedStudsSec = 6,
		respawnSec = 8,
		xpReward = 9,
		coinReward = 2,
		essenceReward = 4,
		gaugeReward = 10,
		behaviorNotes = "วิญญาณต้นไม้ตัวเล็กสีขาว เดินต้วมเตี้ยม หัวสั่นพร้อมวงบนพื้นแล้วกระแทกรอบตัว",
		tuning = {
			attackShape = "burst",
			attackHitRangeStuds = 6,
			attackWidthStuds = 0, -- unused by burst
			leashStuds = 20,
			hoverHeightStuds = 1.7,
			bodyRadiusStuds = 1.2,
			maxAlive = 2,
			groupSize = 1,
			steer = true,
			aiTickSec = 0.1,
		},
		draft = false,
	},
	karakasa = {
		id = "karakasa",
		displayNameTH = "ผีร่ม",
		zoneId = "mistwood",
		level = 2,
		maxHp = 70,
		attackDamage = 10,
		telegraphSec = 0.9,
		recoverSec = 1.3,
		attackRangeStuds = 10,
		detectionRangeStuds = 26,
		moveSpeedStudsSec = 8,
		respawnSec = 10,
		xpReward = 14,
		coinReward = 3,
		essenceReward = 5,
		gaugeReward = 10,
		behaviorNotes = "ร่มกระดาษตาเดียว ลิ้นยาว กระโดดขาเดียว วงขึ้นตรงจุดที่ผู้เล่นยืนแล้วกระโดดลงทับ",
		tuning = {
			attackShape = "leap",
			attackHitRangeStuds = 10, -- furthest landing
			attackWidthStuds = 4, -- slam radius at the landing
			leashStuds = 22,
			hoverHeightStuds = 2.8,
			bodyRadiusStuds = 1.5,
			maxAlive = 2,
			groupSize = 1,
			steer = true,
			aiTickSec = 0.1,
		},
		draft = false,
	},
	shrine_guard = {
		id = "shrine_guard",
		displayNameTH = "ผู้เฝ้ายันต์",
		zoneId = "abandoned_shrine",
		level = 3,
		maxHp = 160,
		attackDamage = 22,
		telegraphSec = 1,
		recoverSec = 1.2,
		attackRangeStuds = 8,
		detectionRangeStuds = 28,
		moveSpeedStudsSec = 7,
		respawnSec = 12,
		xpReward = 26,
		coinReward = 6,
		essenceReward = 8,
		gaugeReward = 15,
		behaviorNotes = "สูง ไร้หน้า ยันต์รอบแขน ฟาดเป็นเส้นตรงยาว",
		tuning = {
			attackShape = "lunge",
			attackHitRangeStuds = 9,
			attackWidthStuds = 3,
			leashStuds = 24,
			hoverHeightStuds = 0,
			bodyRadiusStuds = 1.8,
			maxAlive = 2,
			groupSize = 1,
			steer = true,
			aiTickSec = 0.1,
		},
		draft = true,
	},
}

return Enemies

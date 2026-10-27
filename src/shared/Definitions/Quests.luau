--!strict
-- Quest catalog (M2-D). Fields follow "Definition schema → Quest" in
-- docs/CONTRACTS.md, plus two proposed in handoff/M2D_CONTRACT_PROPOSALS.md:
-- `giverNpcId` (who starts it and pays it out, Definitions/Npcs) and
-- `objectiveTH` (one-line tracker text). Story beats follow GAME_DESIGN v0.2;
-- dialogue is placeholder for Director review. `draft = true`: the objective
-- needs a later batch (defeat_boss = M2-F), so the quest can be taken but not
-- finished yet. apply_seal (q04) is live since M2-E: the seal station is the smith.

export type ObjectiveType = "talk" | "defeat" | "collect" | "apply_seal" | "defeat_boss"

export type QuestDef = {
	id: string,
	titleTH: string,
	prerequisiteQuestId: string?,
	objectiveType: ObjectiveType,
	targetId: string,
	targetCount: number,
	rewardXp: number,
	rewardCoins: number,
	rewardEssence: number,
	dialogueStart: string,
	dialogueComplete: string,
	repeatable: boolean,
	giverNpcId: string,
	objectiveTH: string,
	draft: boolean,
}

local Quests: { [string]: QuestDef } = {
	q01_meet_keeper = {
		id = "q01_meet_keeper",
		titleTH = "พบผู้ดูแลศาล",
		prerequisiteQuestId = nil,
		objectiveType = "talk",
		targetId = "npc_shrine_keeper",
		targetCount = 1,
		rewardXp = 10,
		rewardCoins = 5,
		rewardEssence = 0,
		dialogueStart = "ม่านวิญญาณแตกแล้ว ไปหาผู้ดูแลศาลที่ศาลข้างทางเข้าป่า",
		dialogueComplete = "เจ้าคือผู้ฝึกหัดที่ส่งมาสินะ ดาบเล่มนั้นยังพอใช้ได้",
		repeatable = false,
		giverNpcId = "npc_shrine_keeper",
		objectiveTH = "คุยกับผู้ดูแลศาล (ศาลข้างทางเข้าป่า ทิศใต้ของหมู่บ้าน)",
		draft = false,
	},
	q02_first_hunt = {
		id = "q02_first_hunt",
		titleTH = "ฝึกปราบผี",
		prerequisiteQuestId = "q01_meet_keeper",
		objectiveType = "defeat",
		targetId = "hitodama",
		targetCount = 5,
		rewardXp = 30,
		rewardCoins = 10,
		rewardEssence = 10,
		dialogueStart = "ดวงไฟผีฮิโตดามะลอยวนอยู่ชายป่าฝั่งหมู่บ้าน ปราบให้ได้ห้าดวง",
		dialogueComplete = "ดีมาก รู้สึกถึงวิญญาณที่ไหลเข้าดาบไหม",
		repeatable = false,
		giverNpcId = "npc_shrine_keeper",
		objectiveTH = "ปราบฮิโตดามะในป่าม่านหมอก",
		draft = false,
	},
	q03_gather_traces = {
		id = "q03_gather_traces",
		titleTH = "สะสมร่องรอย",
		prerequisiteQuestId = "q02_first_hunt",
		objectiveType = "collect",
		targetId = "veil_trace",
		targetCount = 3,
		rewardXp = 40,
		rewardCoins = 15,
		rewardEssence = 15,
		dialogueStart = "เศษม่านที่แตกตกอยู่ตามลานโล่งในป่าม่านหมอก มันเรืองแสงสีฟ้า เก็บมาสามชิ้น",
		dialogueComplete = "รอยเหล่านี้ชี้ไปที่ศาลเจ้าร้าง",
		repeatable = false,
		giverNpcId = "npc_shrine_keeper",
		objectiveTH = "เก็บเศษม่านเรืองแสงในลานโล่งกลางป่าม่านหมอก",
		draft = false,
	},
	q04_try_seal = {
		id = "q04_try_seal",
		titleTH = "ทดลองผนึก",
		prerequisiteQuestId = "q03_gather_traces",
		objectiveType = "apply_seal",
		targetId = "any",
		targetCount = 1,
		rewardXp = 20,
		rewardCoins = 10,
		rewardEssence = 0,
		dialogueStart = "ไปหาช่างตีดาบที่แผงในหมู่บ้าน แล้วใช้แก่นวิญญาณผนึกดาบก่อนไปเผชิญหน้ามัน",
		dialogueComplete = "ผนึกติดแน่นแล้ว ไปที่ศาลเจ้าร้างเถอะ",
		repeatable = false,
		giverNpcId = "npc_shrine_keeper",
		objectiveTH = "ผนึกดาบที่ช่างตีดาบ (แผงร้านตีบวกในหมู่บ้าน)",
		draft = false,
	},
	q05_defeat_keeper = {
		id = "q05_defeat_keeper",
		titleTH = "ปราบผู้เฝ้าโคมดับ",
		prerequisiteQuestId = "q04_try_seal",
		objectiveType = "defeat_boss",
		targetId = "extinguished_keeper",
		targetCount = 1,
		rewardXp = 100,
		rewardCoins = 50,
		rewardEssence = 30,
		dialogueStart = "ผู้เฝ้าโคมดับรออยู่ที่ลานศาลเจ้า ปลายป่าม่านหมอก",
		dialogueComplete = "โคมดวงสุดท้ายกลับมาสว่างแล้ว",
		repeatable = false,
		giverNpcId = "npc_shrine_keeper",
		objectiveTH = "ปราบผู้เฝ้าโคมดับที่ลานศาลเจ้า (บอสยังไม่เปิด)",
		draft = true,
	},
}

return Quests

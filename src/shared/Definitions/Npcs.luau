--!strict
-- Village NPCs (M2-D). Schema proposed in handoff/M2D_CONTRACT_PROPOSALS.md.
-- Positions come from World.Village so they follow the layout: the keeper
-- stands between the lanterns in front of the keeper's shrine, the four
-- stall keepers stand behind their counters round the sacred tree. All are
-- friendly; only the shrine keeper gives quests (Quests.giverNpcId).
-- `idleLinesTH` is what they say when they have no quest business with you;
-- one line is picked in turn per talk. Text is placeholder for Director review.

local World = require(script.Parent.World)

export type NpcDef = {
	id: string,
	displayNameTH: string,
	x: number,
	z: number,
	-- Way the NPC faces, in degrees: 0 = south (-Z), 90 = east (+X).
	angle: number,
	-- Server accepts a talk only within this flat distance (prompt range too).
	talkRangeStuds: number,
	robeColor: Color3,
	idleLinesTH: { string },
}

local V = World.Village

-- Same angle convention as Scene/Village: 0 = south (-Z), 90 = east (+X).
local function heading(angle: number): (number, number)
	local a = math.rad(angle)
	return math.sin(a), -math.cos(a)
end

-- Behind the counter of the stall at `angle`, facing out over it.
local function atStall(stallId: string): (number, number, number)
	for _, s in V.stalls do
		if s.id == stallId then
			local hx, hz = heading(s.angle)
			local r = V.stallRadius - 1
			return V.center.x + hx * r, V.center.z + hz * r, s.angle
		end
	end
	error("unknown stall " .. stallId)
end

local TALK_RANGE = 10

local function npc(id: string, name: string, x: number, z: number, angle: number, robe: Color3, lines: { string }): NpcDef
	return table.freeze({
		id = id,
		displayNameTH = name,
		x = x,
		z = z,
		angle = angle,
		talkRangeStuds = TALK_RANGE,
		robeColor = robe,
		idleLinesTH = table.freeze(lines),
	})
end

local Npcs: { [string]: NpcDef } = {}

-- Keeper's shrine faces west (270) toward the fork; stand 5 studs in front.
Npcs.npc_shrine_keeper = npc("npc_shrine_keeper", "ผู้ดูแลศาล", V.keeperShrine.x - 5, V.keeperShrine.z, 270, Color3.fromRGB(236, 232, 222), {
	"ม่านวิญญาณยังสั่นไหวอยู่ ระวังตัวในป่าด้วย",
	"ผีส่วนใหญ่ไม่ได้ชั่วร้าย พวกมันแค่หลงทาง",
})

-- M4 class trainer: on the lawn beside the village spawn, facing it, so a
-- new player sees them first. Talking opens the class menu.
Npcs.npc_trainer = npc("npc_trainer", "ครูฝึกวิชา", V.spawn.x + 12, V.spawn.z + 4, 270, Color3.fromRGB(58, 58, 72), {
	"ลองวิชาให้ครบก่อน แล้วค่อยเลือกทางของเจ้า",
})

local sx, sz, sa = atStall("smith")
Npcs.npc_smith = npc("npc_smith", "ช่างตีดาบ", sx, sz, sa, Color3.fromRGB(96, 70, 56), {
	"ดาบฝึกหัดเล่มนั้นยังใช้ได้อีกนาน",
	"ไม่นานข้าจะผนึกแก่นวิญญาณลงดาบให้ได้ ตอนนี้เตาเพิ่งติดไฟ",
})

sx, sz, sa = atStall("shop")
Npcs.npc_shopkeeper = npc("npc_shopkeeper", "แม่ค้าร้านของชำ", sx, sz, sa, Color3.fromRGB(70, 92, 150), {
	"ร้านยังไม่เปิดจ้ะ เก็บเหรียญไว้ก่อนนะ",
	"ข้าวปั้นกับชาร้อนจะมาเร็ว ๆ นี้",
})

sx, sz, sa = atStall("talisman")
Npcs.npc_talisman_seller = npc("npc_talisman_seller", "คนขายยันต์", sx, sz, sa, Color3.fromRGB(170, 60, 56), {
	"เศษม่านที่แตกชอบตกอยู่ตามลานโล่งในป่า มันเรืองแสงสีฟ้า",
	"ยันต์จับผียังเขียนไม่เสร็จ รออีกหน่อย",
})

sx, sz, sa = atStall("teahouse")
Npcs.npc_tea_master = npc("npc_tea_master", "เจ้าของร้านน้ำชา", sx, sz, sa, Color3.fromRGB(110, 130, 84), {
	"ป่าม่านหมอกอยู่ทางใต้ เดินตามทางโคมไปเรื่อย ๆ",
	"ปลายป่าคือลานศาลเจ้าเก่า ได้ยินว่ามีบางอย่างเฝ้าอยู่",
})

return table.freeze(Npcs)

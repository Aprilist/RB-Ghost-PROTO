--!strict
-- Where the quest guide arrow points (M2-D). Pure: takes the quests map and
-- the player's position, returns the next place to go. The client draws the
-- arrow; the server is never asked, and nothing here grants anything.
--   ready quest            → its giver NPC
--   talk quest             → that NPC
--   defeat quest           → nearest Mistwood spawn of that enemy
--   collect (veil trace)   → nearest veil trace
--   apply_seal             → the smith (seals arrive in M2-E)
--   defeat_boss            → the boss courtyard (origin)
-- The first unclaimed quest in story order wins, so one arrow at a time.

local Definitions = script.Parent.Parent.Definitions
local Npcs = require(Definitions.Npcs)
local Quests = require(Definitions.Quests)
local World = require(Definitions.World)
local QuestRules = require(script.Parent.QuestRules)

export type Target = { x: number, z: number, label: string }

local QuestGuide = {}

local function nearest(points: { { x: number, z: number } }, fromX: number, fromZ: number): { x: number, z: number }?
	local best, bestD = nil, math.huge
	for _, p in points do
		local d = (p.x - fromX) ^ 2 + (p.z - fromZ) ^ 2
		if d < bestD then
			best, bestD = p, d
		end
	end
	return best
end

local function npcTarget(npcId: string): Target?
	local npc = Npcs[npcId]
	return if npc then { x = npc.x, z = npc.z, label = npc.displayNameTH } else nil
end

function QuestGuide.Target(quests: QuestRules.QuestMap, fromX: number, fromZ: number): Target?
	for _, id in QuestRules.Order() do
		local record = quests[id]
		local def = Quests[id]
		if record and record.status == "ready" then
			return npcTarget(def.giverNpcId)
		elseif record and record.status == "active" then
			local t = def.objectiveType
			if t == "talk" then
				return npcTarget(def.targetId)
			elseif t == "defeat" then
				local spawns = {}
				for _, s in World.Mistwood.enemySpawns do
					if s.enemy == def.targetId then
						table.insert(spawns, s)
					end
				end
				local p = nearest(spawns, fromX, fromZ)
				return if p then { x = p.x, z = p.z, label = "ป่าม่านหมอก" } else nil
			elseif t == "collect" then
				local p = nearest(World.Mistwood.veilTraces :: any, fromX, fromZ)
				return if p then { x = p.x, z = p.z, label = "เศษม่าน" } else nil
			elseif t == "apply_seal" then
				return npcTarget("npc_smith")
			elseif t == "defeat_boss" then
				return { x = 0, z = 0, label = "ลานศาลเจ้า" }
			end
		end
	end
	return nil
end

return QuestGuide

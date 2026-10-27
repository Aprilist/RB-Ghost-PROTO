--!strict
-- M2-D world checks: quests point at real NPCs/enemies/pickups, NPCs stand
-- in the village off the roads and plots, veil traces sit in tree-free
-- clearings inside Mistwood, and (when the world is built) the NPC and
-- trace props exist with F-key prompts and no collision.
-- Data cases run anywhere; the last case needs the world built (Play):
--   require(game.ServerScriptService.Server.Tests.QuestWorldTest).Run()
-- Prints one line per case and a summary; returns passed, failed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Definitions = ReplicatedStorage.Shared.Definitions
local Enemies = require(Definitions.Enemies)
local Npcs = require(Definitions.Npcs)
local Prototype = require(Definitions.Prototype)
local Quests = require(Definitions.Quests)
local World = require(Definitions.World)
local Zones = require(Definitions.Zones)
local Village = require(script.Parent.Parent.Scene.Village)
local SealRules = require(script.Parent.Parent.Util.SealRules)

local V, M = World.Village, World.Mistwood
-- Mistwood keeps trees 11 studs from every enemy spawn (Scene/Mistwood).
local CLEARING_RADIUS = 11
local TRACE_MARGIN = 2

local function inZone(zoneId: string, x: number, z: number): boolean
	for _, v in Zones[zoneId].volumes do
		if math.abs(x - v.center.X) <= v.size.X / 2 and math.abs(z - v.center.Z) <= v.size.Z / 2 then
			return true
		end
	end
	return false
end

local function snake(s: string): boolean
	return string.match(s, "^[a-z][a-z0-9_]*$") ~= nil
end

type Case = { name: string, run: () -> (boolean, string?) }

local cases: { Case } = {
	{
		name = "quests point at real NPCs, enemies and pickups",
		run = function()
			for id, q in Quests do
				local giver = Npcs[q.giverNpcId]
				if not giver then
					return false, id .. " giver " .. q.giverNpcId
				end
				if q.objectiveTH == "" then
					return false, id .. " objectiveTH"
				end
				local t = q.objectiveType
				if t == "talk" and Npcs[q.targetId] == nil then
					return false, id .. " talk target"
				elseif t == "defeat" then
					local e = Enemies[q.targetId]
					if not e or e.draft then
						return false, id .. " defeat target"
					end
				elseif t == "collect" and (q.targetId ~= "veil_trace" or #M.veilTraces < q.targetCount) then
					return false, id .. " collect target/count"
				elseif t == "defeat_boss" and not q.draft then
					return false, id .. " needs a later batch, must stay draft"
				elseif t == "apply_seal" and Npcs[SealRules.StationNpcId] == nil then
					return false, id .. " seal station NPC"
				end
			end
			return true, nil
		end,
	},
	{
		name = "q02's enemy really spawns in Mistwood, enough for the count",
		run = function()
			local q = Quests.q02_first_hunt
			local markers = 0
			for _, s in M.enemySpawns do
				if s.enemy == q.targetId then
					markers += 1
				end
			end
			local e = Enemies[q.targetId]
			return markers > 0 and e ~= nil and Zones[e.zoneId].rewardEligible, string.format("%d markers", markers)
		end,
	},
	{
		name = "NPC ids are snake_case and match their keys",
		run = function()
			for key, npc in Npcs do
				if not snake(key) or npc.id ~= key or #npc.idleLinesTH == 0 then
					return false, key
				end
				if npc.talkRangeStuds <= 0 or npc.talkRangeStuds > 15 then
					return false, key .. " talk range"
				end
			end
			return true, nil
		end,
	},
	{
		name = "NPCs stand in the village, off roads and plots, apart",
		run = function()
			for id, npc in Npcs do
				if not inZone("last_lantern_village", npc.x, npc.z) then
					return false, id .. " outside the village zone"
				end
				local road = Village.DistanceToRoad(npc.x, npc.z)
				if road < 1 then
					return false, string.format("%s on a road (%.1f)", id, road)
				end
				for i, plot in V.plots do
					local p = Village.PlotFrame(plot):PointToObjectSpace(Vector3.new(npc.x, 0, npc.z))
					if math.abs(p.X) <= V.plotSize.x / 2 and math.abs(p.Z) <= V.plotSize.z / 2 then
						return false, id .. " inside plot " .. i
					end
				end
				for other, o in Npcs do
					if other ~= id and (npc.x - o.x) ^ 2 + (npc.z - o.z) ^ 2 < 9 then
						return false, id .. " too close to " .. other
					end
				end
			end
			return true, nil
		end,
	},
	{
		name = "veil traces sit in tree-free clearings inside Mistwood",
		run = function()
			for i, t in M.veilTraces do
				if not inZone("mistwood", t.x, t.z) then
					return false, "trace " .. i .. " outside the zone"
				end
				local inClearing = false
				for _, s in M.enemySpawns do
					if (t.x - s.x) ^ 2 + (t.z - s.z) ^ 2 <= (CLEARING_RADIUS - TRACE_MARGIN) ^ 2 then
						inClearing = true
					end
				end
				if not inClearing then
					return false, "trace " .. i .. " not in a clearing"
				end
				for j, o in M.veilTraces do
					if j ~= i and (t.x - o.x) ^ 2 + (t.z - o.z) ^ 2 < 20 * 20 then
						return false, string.format("traces %d and %d closer than 20", i, j)
					end
				end
			end
			return true, string.format("%d traces", #M.veilTraces)
		end,
	},
	{
		name = "built props: one NPC each with an F prompt, traces, no collision",
		run = function()
			local root = workspace:FindFirstChild(Prototype.WorldNamespace)
			local folder = root and root:FindFirstChild("QuestWorld")
			if not folder then
				return false, "QuestWorld folder missing (world not built?)"
			end
			local npcFolder = folder:FindFirstChild("Npcs")
			for id in Npcs do
				local m = npcFolder and npcFolder:FindFirstChild(id)
				local prompt = m and m:FindFirstChildWhichIsA("ProximityPrompt", true)
				if not prompt or prompt.KeyboardKeyCode ~= Enum.KeyCode.F then
					return false, id .. " model/prompt"
				end
			end
			local traces = folder:FindFirstChild("VeilTraces")
			local count = 0
			for _, d in if traces then traces:GetChildren() else {} do
				if d:IsA("BasePart") and d:FindFirstChildWhichIsA("ProximityPrompt") then
					count += 1
				end
			end
			if count ~= #M.veilTraces then
				return false, string.format("%d traces built", count)
			end
			for _, d in folder:GetDescendants() do
				if d:IsA("BasePart") and d.CanCollide then
					return false, d:GetFullName() .. " collides"
				end
			end
			return true, nil
		end,
	},
}

local QuestWorldTest = {}

function QuestWorldTest.Run(): (number, number)
	local passed, failed = 0, 0
	for _, case in cases do
		local ok, result, detail = pcall(case.run)
		if ok and result then
			passed += 1
			print("[QuestWorldTest] PASS", case.name, detail or "")
		else
			failed += 1
			warn("[QuestWorldTest] FAIL", case.name, if ok then detail else result)
		end
	end
	print(string.format("[QuestWorldTest] %d passed, %d failed", passed, failed))
	return passed, failed
end

return QuestWorldTest

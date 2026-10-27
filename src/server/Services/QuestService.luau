--!strict
-- Quests (M2-D). Server owns every quest change: progress comes only from
-- server-side domain events (a granted enemy reward, a talk or pickup the
-- server checked for range), never from a client claim of progress. All
-- changes go through ProfileService.Mutate on the ProfileV1 `quests` map
-- using the pure Util/QuestRules. claim_quest pays the quest reward in the
-- same mutation that marks it claimed, so a quest pays once even after the
-- requestId cache expires. Dialogue lines are sent to the talking player
-- only (StateEvent kind "dialogue"); short feedback uses kind "notice".
--
-- Hooks for later batches: QuestService.Record(player, "apply_seal", sealId)
-- (M2-E) and QuestService.Record(player, "defeat_boss", bossId) (M2-F).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)
local Npcs = require(ReplicatedStorage.Shared.Definitions.Npcs)
local Quests = require(ReplicatedStorage.Shared.Definitions.Quests)
local QuestRules = require(ReplicatedStorage.Shared.Util.QuestRules)
local ProfileRules = require(script.Parent.Parent.Util.ProfileRules)

type ProfileV1 = ProfileRules.ProfileV1

type Network = {
	Handle: (string, (Player, { [string]: any }) -> Contracts.ResultCode) -> (),
	SendState: (Player, Contracts.StateEvent) -> (),
	EmitFx: (string, Vector3, number?, string?) -> (),
}

type Profiles = {
	Load: (Player) -> ProfileV1,
	Get: (Player) -> ProfileV1?,
	Mutate: (Player, (ProfileV1) -> ()) -> boolean,
}

type PlayerState = {
	IsAlive: (Player) -> boolean,
	GetRoot: (Player) -> BasePart?,
}

type Rewards = {
	OnGranted: ((Player, string) -> ()) -> (),
}

-- Slack over the NPC's talk range for claim_quest, so a player who steps
-- back while reading can still press the button.
local CLAIM_RANGE_SLACK = 6
local VEIL_TRACE_ID = "veil_trace"

local QuestService = {}

local network: Network
local profiles: Profiles
local playerState: PlayerState
local rewards: Rewards
-- Session only: which veil traces each player picked up for q03, so one
-- trace counts once. Lost on leave, like the memory profile.
local collected: { [Player]: { [number]: boolean } } = {}
local idleTurn: { [Player]: number } = {}

local function flatDistance(a: Vector3, x: number, z: number): number
	return math.sqrt((a.X - x) ^ 2 + (a.Z - z) ^ 2)
end

-- Within `npc` talk range (plus slack), alive and with a character.
function QuestService.InRange(player: Player, npc: Npcs.NpcDef, slack: number): boolean
	local root = playerState.GetRoot(player)
	if not root or not playerState.IsAlive(player) then
		return false
	end
	return flatDistance(root.Position, npc.x, npc.z) <= npc.talkRangeStuds + slack
end

local function notice(player: Player, text: string)
	network.SendState(player, { kind = "notice", textTH = text })
end

local function dialogue(player: Player, npc: Npcs.NpcDef, lines: { string }, questId: string?, claimQuestId: string?)
	network.SendState(player, {
		kind = "dialogue",
		npcId = npc.id,
		speakerTH = npc.displayNameTH,
		lines = lines,
		questId = questId,
		claimQuestId = claimQuestId,
	})
end

-- Counts an objective event for `player`. Skips the mutation when no active
-- quest wants it. Returns the ids that became ready. A talk that finishes a
-- quest gets no "go back" notice: the giver's dialogue follows at once.
function QuestService.Record(player: Player, objectiveType: string, targetId: string, amount: number?): { string }
	local profile = profiles.Get(player)
	if not profile or not QuestRules.Wants(profile.quests, objectiveType, targetId) then
		return {}
	end
	local nowReady: { string } = {}
	profiles.Mutate(player, function(p)
		local _, ready = QuestRules.Record(p.quests, objectiveType, targetId, amount or 1)
		nowReady = ready
	end)
	if objectiveType == "talk" then
		return nowReady
	end
	for _, id in nowReady do
		notice(player, "เควสสำเร็จ: " .. Quests[id].titleTH .. " — กลับไปหา" .. Npcs[Quests[id].giverNpcId].displayNameTH)
	end
	return nowReady
end

local function startQuest(player: Player, questId: string): boolean
	local code: QuestRules.StartCode = "UNKNOWN"
	profiles.Mutate(player, function(p)
		code = QuestRules.Start(p.quests, questId)
	end)
	return code == "OK"
end

local function progressLine(questId: string, profile: ProfileV1): string
	local def = Quests[questId]
	local record = profile.quests[questId]
	local progress = if record then record.progress else 0
	if def.targetCount > 1 then
		return string.format("%s (%d/%d)", def.objectiveTH, progress, def.targetCount)
	end
	return def.objectiveTH
end

-- Talk to an NPC (the caller has checked range). Order: count the talk
-- (q01), then pay out / offer / remind, else an idle line. `slack` is the
-- range allowance over the NPC's talk range (default 2).
function QuestService.Talk(player: Player, npcId: string, slack: number?)
	local npc = Npcs[npcId]
	if not npc or not QuestService.InRange(player, npc, slack or 2) then
		return
	end
	QuestService.Record(player, "talk", npcId, 1)
	local profile = profiles.Get(player)
	if not profile then
		return
	end
	local state, questId = QuestRules.GiverState(profile.quests, npcId)
	if state == "claim" and questId then
		dialogue(player, npc, { Quests[questId].dialogueComplete }, questId, questId)
		return
	elseif state == "offer" and questId then
		if startQuest(player, questId) then
			local def = Quests[questId]
			dialogue(player, npc, { def.dialogueStart, "เควสใหม่: " .. def.titleTH }, questId, nil)
			return
		end
	elseif state == "waiting" and questId then
		dialogue(player, npc, { "เป็นอย่างไรบ้าง", progressLine(questId, profile) }, questId, nil)
		return
	end
	local turn = (idleTurn[player] or 0) % #npc.idleLinesTH + 1
	idleTurn[player] = turn
	dialogue(player, npc, { npc.idleLinesTH[turn] }, nil, nil)
end

-- Pick up veil trace `index` (World.Mistwood.veilTraces; the caller has
-- checked range). Counts once per trace per player, only while q03 wants it.
function QuestService.CollectTrace(player: Player, index: number)
	local profile = profiles.Get(player)
	if not profile or not playerState.IsAlive(player) then
		return
	end
	if not QuestRules.Wants(profile.quests, "collect", VEIL_TRACE_ID) then
		notice(player, "เศษม่านเรืองแสงจาง ๆ ผู้ดูแลศาลน่าจะรู้ว่ามันคืออะไร")
		return
	end
	local mine = collected[player]
	if not mine then
		mine = {}
		collected[player] = mine
	end
	if mine[index] then
		notice(player, "เก็บชิ้นนี้ไปแล้ว ลองหาลานโล่งอื่น")
		return
	end
	mine[index] = true
	local ready = QuestService.Record(player, "collect", VEIL_TRACE_ID, 1)
	if #ready == 0 then
		local after = profiles.Get(player)
		for id, record in if after then after.quests else {} do
			if Quests[id].objectiveType == "collect" and record.status == "active" then
				notice(player, string.format("เก็บเศษม่าน %d/%d", record.progress, Quests[id].targetCount))
			end
		end
	end
end

local function claim(player: Player, payload: { [string]: any }): Contracts.ResultCode
	local questId = payload.questId :: string
	local def = Quests[questId]
	if not def then
		return "INVALID_PAYLOAD"
	end
	local profile = profiles.Get(player)
	if not profile then
		return "NOT_READY"
	end
	local pre = QuestRules.CanClaim(profile.quests, questId)
	if pre ~= "OK" then
		return if pre == "UNKNOWN" then "INVALID_PAYLOAD" else pre :: any
	end
	local giver = Npcs[def.giverNpcId]
	if not playerState.IsAlive(player) then
		return "DEAD"
	end
	if not giver or not QuestService.InRange(player, giver, CLAIM_RANGE_SLACK) then
		return "OUT_OF_RANGE"
	end

	local code: QuestRules.ClaimCode = "QUEST_NOT_READY"
	local levelsGained = 0
	local capped = false
	local committed = profiles.Mutate(player, function(p)
		code = QuestRules.Claim(p.quests, questId)
		if code ~= "OK" then
			return
		end
		levelsGained = ProfileRules.AddXp(p, def.rewardXp)
		local _, coinsCapped = ProfileRules.AddCurrency(p, "coins", def.rewardCoins)
		local _, essenceCapped = ProfileRules.AddCurrency(p, "essence", def.rewardEssence)
		capped = coinsCapped or essenceCapped
	end)
	if not committed then
		return "INTERNAL_ERROR"
	end
	if code ~= "OK" then
		return if code == "UNKNOWN" then "INVALID_PAYLOAD" else code :: any
	end
	if capped then
		warn("[QuestService] currency cap reached for", player.UserId)
	end
	local root = playerState.GetRoot(player)
	if root and levelsGained > 0 then
		network.EmitFx("level_up", root.Position, player.UserId, nil)
	end
	notice(player, string.format("ได้รับ EXP %d · เหรียญ %d · แก่นวิญญาณ %d", def.rewardXp, def.rewardCoins, def.rewardEssence))
	-- Same conversation: offer the giver's next quest straight away.
	task.defer(QuestService.Talk, player, giver.id, CLAIM_RANGE_SLACK)
	return "OK"
end

function QuestService.Init(deps: { Network: Network, Profiles: Profiles, PlayerState: PlayerState, Rewards: Rewards })
	network = deps.Network
	profiles = deps.Profiles
	playerState = deps.PlayerState
	rewards = deps.Rewards
end

local function onPlayer(player: Player)
	profiles.Load(player) -- idempotent; the profile normally exists already
	local profile = profiles.Get(player)
	if not profile then
		return
	end
	-- Mutate only if a first quest (no prerequisite) is not started yet.
	for id, def in Quests do
		if def.prerequisiteQuestId == nil and profile.quests[id] == nil then
			profiles.Mutate(player, function(p)
				QuestRules.AutoStart(p.quests)
			end)
			return
		end
	end
end

function QuestService.Start()
	network.Handle("claim_quest", claim)
	-- Kills count only when the kill paid this player a reward (same
	-- eligibility as rewards: alive, near, same zone).
	rewards.OnGranted(function(player, definitionId)
		QuestService.Record(player, "defeat", definitionId, 1)
	end)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		collected[player] = nil
		idleTurn[player] = nil
	end)
end

return QuestService

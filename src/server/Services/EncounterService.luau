--!strict
-- The boss encounter (M2-F part 2): who is in the fight and who is paid.
--   idle → open        a living player steps into the arena; for joinWindowSec
--                      others may still walk in and become members
--   open → fighting    the window ends: the members are locked, the boss engages
--   fighting           a member who dies or leaves the arena is out for the
--                      round (and can never get back in); nobody joins late.
--                      No living member for resetAfterEmptySec → BossService
--                      resets the boss, no reward (we hear it as OnReset)
--   fighting → won     the boss dies: each member still alive in the arena who
--                      dealt ≥ 5% of its max HP gets the reward once, and
--                      QuestService hears defeat_boss for them. Everyone else
--                      gets nothing. The boss is back after respawnSec.
-- Players hear it as StateEvent kind "encounter" (docs/CONTRACTS.md). All
-- decisions are in Util/EncounterRules; this service only reads the world and
-- acts. A player outside the member set cannot damage the boss (BossService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bosses = require(ReplicatedStorage.Shared.Definitions.Bosses)
local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)
local BossRules = require(script.Parent.Parent.Util.BossRules)
local EncounterRules = require(script.Parent.Parent.Util.EncounterRules)

type State = EncounterRules.State

type Defeat = {
	bossId: string,
	runtimeId: string,
	position: Vector3,
	maxHp: number,
	damageBy: { [number]: number },
}

type Network = {
	SendState: (Player, Contracts.StateEvent) -> (),
}

type PlayerState = {
	IsAlive: (Player) -> boolean,
	GetRoot: (Player) -> BasePart?,
}

type Boss = {
	SetAutoEngage: (boolean) -> (),
	SetMembers: ({ [Player]: boolean }?) -> (),
	Engage: () -> (),
	Reset: () -> (),
	OnDefeated: ((Defeat) -> ()) -> (),
	OnReset: (() -> ()) -> (),
}

type Rewards = {
	GrantFixed: (Player, string, number, number, number) -> boolean,
}

type Quests = {
	Record: (Player, string, string, number?) -> { string },
}

local DEF = Bosses.extinguished_keeper
local TICK_SEC = 0.25

local EncounterService = {}

local network: Network
local playerState: PlayerState
local boss: Boss
local rewards: Rewards
local quests: Quests

local state: State = "idle"
local joinDeadline: number? = nil
local round = 0
-- Live members: the table BossService filters by. A player removed here
-- (died, left the arena, left the game) never returns this round.
local members: { [Player]: boolean } = {}
-- Everyone who was ever a member this round, so the end-of-fight message
-- still reaches someone who just died.
local roundPlayers: { [Player]: boolean } = {}
local out: { [Player]: boolean } = {}
local toldLate: { [Player]: boolean } = {}

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function encounterId(): string
	return DEF.id .. ":" .. round
end

local function send(player: Player, eventState: Contracts.EncounterState, joined: boolean, endsAt: number?)
	network.SendState(player, {
		kind = "encounter",
		encounterId = encounterId(),
		state = eventState,
		endsAt = endsAt,
		joined = joined,
	})
end

local function notice(player: Player, text: string)
	network.SendState(player, { kind = "notice", textTH = text })
end

-- Living players inside the arena right now.
local function present(): { Player }
	local list: { Player } = {}
	for _, player in Players:GetPlayers() do
		local root = if playerState.IsAlive(player) then playerState.GetRoot(player) else nil
		if root and BossRules.InArena(root.Position, DEF) then
			table.insert(list, player)
		end
	end
	return list
end

local function inArena(player: Player): boolean
	local root = playerState.GetRoot(player)
	return root ~= nil and BossRules.InArena(root.Position, DEF)
end

local function memberCount(): number
	local n = 0
	for _ in members do
		n += 1
	end
	return n
end

-- Players who should hear a state change: members this round and anyone
-- standing in the arena.
local function audience(): { Player }
	local seen: { [Player]: boolean } = {}
	local list: { Player } = {}
	for player in roundPlayers do
		if player.Parent and not seen[player] then
			seen[player] = true
			table.insert(list, player)
		end
	end
	for _, player in present() do
		if not seen[player] then
			seen[player] = true
			table.insert(list, player)
		end
	end
	return list
end

local function broadcast(eventState: Contracts.EncounterState, endsAt: number?)
	for _, player in audience() do
		send(player, eventState, members[player] == true, endsAt)
	end
end

local function clearRound()
	table.clear(members)
	table.clear(roundPlayers)
	table.clear(out)
	table.clear(toldLate)
	joinDeadline = nil
end

local function join(player: Player)
	if members[player] or out[player] then
		return
	end
	members[player] = true
	roundPlayers[player] = true
end

local function dropMember(player: Player)
	if members[player] then
		members[player] = nil
		out[player] = true
	end
end

------------------------------------------------------------------------------
-- The fight ends
------------------------------------------------------------------------------

local function pay(defeat: Defeat)
	for player in members do
		local verdict = EncounterRules.Payout(
			members[player] == true,
			playerState.IsAlive(player),
			inArena(player),
			defeat.damageBy[player.UserId] or 0,
			defeat.maxHp,
			DEF.rewardMinDamageFraction
		)
		if verdict == "paid" then
			if rewards.GrantFixed(player, defeat.runtimeId, DEF.rewardXp, DEF.rewardCoins, DEF.rewardEssence) then
				notice(player, string.format("ปราบ%s สำเร็จ! EXP %d · เหรียญ %d · แก่นวิญญาณ %d", DEF.displayNameTH, DEF.rewardXp, DEF.rewardCoins, DEF.rewardEssence))
				quests.Record(player, "defeat_boss", defeat.bossId, 1)
			end
		elseif verdict == "too_little" then
			notice(player, string.format("ทำดาเมจไม่ถึง %d%% ของเลือดบอส จึงไม่ได้รางวัลรอบนี้", math.floor(DEF.rewardMinDamageFraction * 100 + 0.5)))
		end
	end
end

local function onDefeated(defeat: Defeat)
	if state ~= "fighting" then
		return
	end
	pay(defeat)
	state = "won"
	broadcast("won", nil)
	task.delay(DEF.respawnSec, function()
		boss.Reset()
	end)
end

-- The boss service reset itself (abandoned fight) or came back after a defeat.
local function onBossReset()
	if state == "fighting" then
		-- Abandoned: tell the people who were in it before the round clears.
		broadcast("reset", nil)
	end
	state = "idle"
	clearRound()
end

------------------------------------------------------------------------------
-- Tick
------------------------------------------------------------------------------

local function tick()
	local list = present()
	local now = serverNow()

	if state == "idle" then
		if #list > 0 then
			round += 1
			clearRound()
			for _, player in list do
				join(player)
			end
			joinDeadline = now + DEF.joinWindowSec
			state = "open"
			broadcast("open", joinDeadline)
		end
	elseif state == "open" then
		for _, player in list do
			if not members[player] then
				join(player)
				send(player, "open", true, joinDeadline)
			end
		end
		-- Before the lock, stepping out is free: you can walk back in.
		for player in members do
			if not table.find(list, player) then
				members[player] = nil
				roundPlayers[player] = nil
			end
		end
		local nextState = EncounterRules.Next("open", memberCount(), now, joinDeadline, false, false)
		if nextState == "idle" then
			state = "idle"
			clearRound()
		elseif nextState == "fighting" then
			state = "fighting"
			boss.Engage()
			broadcast("fighting", nil)
		end
	elseif state == "fighting" then
		for player in members do
			if not playerState.IsAlive(player) or not inArena(player) then
				dropMember(player)
				notice(player, "ออกจากศึกกับ" .. DEF.displayNameTH .. "แล้ว รอรอบหน้า")
				send(player, "fighting", false, nil)
			end
		end
		-- Anyone walking in now is told once that the fight has started without them.
		for _, player in list do
			if not members[player] and not toldLate[player] then
				toldLate[player] = true
				notice(player, "ศึกกับ" .. DEF.displayNameTH .. "กำลังดำเนินอยู่ รอรอบหน้า")
				send(player, "fighting", false, nil)
			end
		end
	end
end

function EncounterService.State(): State
	return state
end

function EncounterService.Init(deps: { Network: Network, PlayerState: PlayerState, Boss: Boss, Rewards: Rewards, Quests: Quests })
	network = deps.Network
	playerState = deps.PlayerState
	boss = deps.Boss
	rewards = deps.Rewards
	quests = deps.Quests
end

function EncounterService.Start()
	-- The encounter decides when the boss fights and who it fights.
	boss.SetAutoEngage(false)
	boss.SetMembers(members)
	boss.OnDefeated(onDefeated)
	boss.OnReset(onBossReset)
	Players.PlayerRemoving:Connect(function(player)
		members[player] = nil
		roundPlayers[player] = nil
		out[player] = nil
		toldLate[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(TICK_SEC)
			tick()
		end
	end)
end

return EncounterService

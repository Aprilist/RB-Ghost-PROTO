--!strict
-- Seals (M2-E). Server owns every seal decision.
--   apply_seal   buy a seal for a weapon at the seal station NPC: ownership,
--                distance, essence and "already carries it" are all checked
--                and the essence is charged inside one ProfileService.Mutate
--                (SealRules.Apply), so a repeat can never charge twice.
--   ember        every Nth landed basic attack sets the enemies it hit on
--                fire: damage over time, never stacking (CombatService.OnBasicHit).
--   ward         every Nth soul absorbed (a reward actually granted to the
--                player) gives a shield with a cooldown (RewardService.OnGranted).
-- Counters, burns and shields are session state, lost on leave like the
-- memory profile. The client only ever sees pictures of these (combat_fx
-- "burn" / "ward_shield") and the snapshot's shield and seal fields.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)
local Npcs = require(ReplicatedStorage.Shared.Definitions.Npcs)
local Seals = require(ReplicatedStorage.Shared.Definitions.Seals)
local ProfileRules = require(script.Parent.Parent.Util.ProfileRules)
local SealRules = require(script.Parent.Parent.Util.SealRules)

type ResultCode = Contracts.ResultCode
type ProfileV1 = ProfileRules.ProfileV1

type Network = {
	Handle: (string, (Player, { [string]: any }) -> ResultCode) -> (),
	SendState: (Player, Contracts.StateEvent) -> (),
	EmitFx: (string, Vector3, number?, string?) -> (),
}

type Profiles = {
	Get: (Player) -> ProfileV1?,
	Mutate: (Player, (ProfileV1) -> ()) -> boolean,
}

type PlayerState = {
	IsAlive: (Player) -> boolean,
	GetRoot: (Player) -> BasePart?,
	CooldownReady: (Player, string) -> boolean,
	StartCooldown: (Player, string, number) -> (),
	GrantShield: (Player, number, number) -> (),
	OnDied: ((Player) -> ()) -> (),
}

type EnemyRecord = { id: string, body: BasePart }

type Enemies = {
	GetAlive: () -> { EnemyRecord },
	Damage: (string, number, Player) -> boolean,
}

type Combat = {
	OnBasicHit: ((Player, { string }) -> ()) -> (),
}

type Rewards = {
	OnGranted: ((Player, string) -> ()) -> (),
}

type Quests = {
	Record: (Player, string, string, number?) -> { string },
}

type Burn = { endsAt: number, dps: number, attacker: Player }

local BURN_TICK_SEC = 0.5
local WARD_COOLDOWN_KEY = "ward"

local SealService = {}

local network: Network
local profiles: Profiles
local playerState: PlayerState
local enemies: Enemies
local combat: Combat
local rewards: Rewards
local quests: Quests
-- Session only, per player: landed basic attacks since the last ember burn and
-- souls since the last ward shield. Reset when the seal changes or on death.
local hitCount: { [Player]: number } = {}
local soulCount: { [Player]: number } = {}
local burns: { [string]: Burn } = {}

local function notice(player: Player, text: string)
	network.SendState(player, { kind = "notice", textTH = text })
end

local function equippedSeal(player: Player): string?
	local profile = profiles.Get(player)
	return if profile then SealRules.EquippedSealId(profile) else nil
end

local function resetCounters(player: Player)
	hitCount[player] = nil
	soulCount[player] = nil
end

------------------------------------------------------------------------------
-- apply_seal
------------------------------------------------------------------------------

-- The player is close enough to the seal station (alive, same flat distance
-- rule as quest claims).
local function nearStation(player: Player): boolean
	local station = Npcs[SealRules.StationNpcId]
	local root = playerState.GetRoot(player)
	if not station or not root then
		return false
	end
	local dx, dz = root.Position.X - station.x, root.Position.Z - station.z
	return math.sqrt(dx * dx + dz * dz) <= station.talkRangeStuds + SealRules.RangeSlackStuds
end

local function applySeal(player: Player, payload: { [string]: any }): ResultCode
	local itemInstanceId = payload.itemInstanceId :: string
	local sealId = payload.sealId :: string
	local seal = Seals[sealId]
	if not seal then
		return "INVALID_PAYLOAD"
	end
	local profile = profiles.Get(player)
	if not profile then
		return "NOT_READY"
	end
	if not playerState.IsAlive(player) then
		return "DEAD"
	end
	if not nearStation(player) then
		return "OUT_OF_RANGE"
	end

	-- Dry run on a copy: a rejected request never touches the profile or bumps
	-- its revision. Mutate then repeats the same rule as the authoritative check
	-- and charge, so the answer cannot change between the two.
	local dry = SealRules.Apply(ProfileRules.Clone(profile), itemInstanceId, sealId)
	if dry ~= "OK" then
		return dry :: ResultCode
	end
	local code: SealRules.ApplyCode = "INVALID_PAYLOAD"
	local committed = profiles.Mutate(player, function(p)
		code = SealRules.Apply(p, itemInstanceId, sealId)
	end)
	if not committed then
		return "INTERNAL_ERROR"
	end
	if code ~= "OK" then
		return code :: ResultCode
	end

	resetCounters(player)
	local root = playerState.GetRoot(player)
	if root then
		network.EmitFx("seal_apply", root.Position, player.UserId, nil)
	end
	notice(player, string.format("ผนึกดาบด้วย%s แล้ว (ใช้แก่นวิญญาณ %d)", seal.displayNameTH, seal.essenceCost))
	quests.Record(player, "apply_seal", sealId, 1)
	return "OK"
end

------------------------------------------------------------------------------
-- ember
------------------------------------------------------------------------------

local function igniteAll(player: Player, enemyIds: { string }, effect: { [string]: number })
	local now = os.clock()
	for _, id in enemyIds do
		local current = burns[id]
		if SealRules.CanIgnite(if current then current.endsAt else nil, now) then
			burns[id] = { endsAt = now + effect.burnSec, dps = effect.burnDps, attacker = player }
		end
	end
end

local function onBasicHit(player: Player, enemyIds: { string })
	if equippedSeal(player) ~= "ember" then
		return
	end
	local effect = Seals.ember.effect
	local count, triggered = SealRules.EmberStep(hitCount[player] or 0, effect.hitsToBurn)
	hitCount[player] = count
	if triggered then
		igniteAll(player, enemyIds, effect)
	end
end

-- One loop for every burning enemy: damage dps × tick through the normal
-- enemy damage path (so kills reward as usual), then drop finished burns.
local function burnLoop()
	while true do
		task.wait(BURN_TICK_SEC)
		if next(burns) == nil then
			continue
		end
		local now = os.clock()
		local positions: { [string]: Vector3 } = {}
		for _, enemy in enemies.GetAlive() do
			positions[enemy.id] = enemy.body.Position
		end
		for id, burn in burns do
			local position = positions[id]
			if now >= burn.endsAt or position == nil or burn.attacker.Parent == nil then
				burns[id] = nil
			else
				network.EmitFx("burn", position, burn.attacker.UserId, id)
				if not enemies.Damage(id, burn.dps * BURN_TICK_SEC, burn.attacker) then
					burns[id] = nil
				end
			end
		end
	end
end

------------------------------------------------------------------------------
-- ward
------------------------------------------------------------------------------

local function onSoul(player: Player, _definitionId: string)
	if equippedSeal(player) ~= "ward" or not playerState.IsAlive(player) then
		return
	end
	local effect = Seals.ward.effect
	local onCooldown = not playerState.CooldownReady(player, WARD_COOLDOWN_KEY)
	local souls, triggered = SealRules.WardStep(soulCount[player] or 0, effect.soulsToShield, onCooldown)
	soulCount[player] = souls
	if not triggered then
		return
	end
	playerState.StartCooldown(player, WARD_COOLDOWN_KEY, effect.cooldownSec)
	playerState.GrantShield(player, effect.shieldHp, effect.shieldSec)
	local root = playerState.GetRoot(player)
	if root then
		network.EmitFx("ward_shield", root.Position, player.UserId, nil)
	end
	notice(player, string.format("ผนึกปราการ: ได้โล่ %d (นาน %d วินาที)", effect.shieldHp, effect.shieldSec))
end

------------------------------------------------------------------------------

-- Opens the seal menu for `player` (the caller, NpcService, has checked range).
function SealService.OpenMenu(player: Player)
	local station = Npcs[SealRules.StationNpcId]
	if not station or not playerState.IsAlive(player) then
		return
	end
	network.SendState(player, { kind = "seal_menu", npcId = station.id, speakerTH = station.displayNameTH })
end

function SealService.Init(deps: {
	Network: Network,
	Profiles: Profiles,
	PlayerState: PlayerState,
	Enemies: Enemies,
	Combat: Combat,
	Rewards: Rewards,
	Quests: Quests,
})
	network = deps.Network
	profiles = deps.Profiles
	playerState = deps.PlayerState
	enemies = deps.Enemies
	combat = deps.Combat
	rewards = deps.Rewards
	quests = deps.Quests
end

function SealService.Start()
	network.Handle("apply_seal", applySeal)
	combat.OnBasicHit(onBasicHit)
	rewards.OnGranted(onSoul)
	playerState.OnDied(resetCounters)
	task.spawn(burnLoop)
	Players.PlayerRemoving:Connect(function(player)
		resetCounters(player)
	end)
end

return SealService

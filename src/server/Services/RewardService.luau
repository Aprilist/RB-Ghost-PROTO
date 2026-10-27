--!strict
-- Rewards for enemy defeats (M2-A, moved out of SpiritService).
-- Rewards come only from EnemyService's single death transition; a ledger
-- keyed enemyRuntimeId + userId blocks any second grant for the same kill,
-- and is marked before the grant. EXP, coins and essence go to the profile
-- through ProfileService.Mutate; the gauge is session state. The orb and
-- level-up a client sees are pictures of this grant, never a request for it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local ProfileRules = require(script.Parent.Parent.Util.ProfileRules)
local RewardRules = require(script.Parent.Parent.Util.RewardRules)

type Network = {
	EmitFx: (string, Vector3, number?, string?) -> (),
}

type State = {
	spiritGauge: number,
}

type PlayerState = {
	Get: (Player) -> State?,
	IsAlive: (Player) -> boolean,
	IsTransformed: (Player) -> boolean,
	GetRoot: (Player) -> BasePart?,
	Commit: (Player) -> (),
}

type Profiles = {
	Mutate: (Player, (ProfileRules.ProfileV1) -> ()) -> boolean,
}

type Defeat = { enemyId: string, definitionId: string, position: Vector3, contributors: { number } }

type Enemies = {
	OnDefeated: ((Defeat) -> ()) -> (),
}

type Zones = {
	ZoneAt: (Vector3) -> string?,
}

local RewardService = {}

local network: Network
local playerState: PlayerState
local profiles: Profiles
local enemies: Enemies
local zones: Zones
local ledger: { [string]: boolean } = {}

local function grant(player: Player, defeat: Defeat, enemyZoneId: string?)
	local key = defeat.enemyId .. ":" .. player.UserId
	if ledger[key] then
		return
	end
	-- Mark before granting so a re-entrant or duplicated call cannot pass twice.
	ledger[key] = true

	local state = playerState.Get(player)
	local root = playerState.GetRoot(player)
	local eligible = RewardRules.Eligible({
		alive = state ~= nil and playerState.IsAlive(player),
		distance = if root then (root.Position - defeat.position).Magnitude else nil,
		playerZoneId = if root then zones.ZoneAt(root.Position) else nil,
		enemyZoneId = enemyZoneId,
	})
	local reward = RewardRules.ForEnemy(defeat.definitionId, playerState.IsTransformed(player))
	if not eligible or not state or not root or not reward then
		return
	end

	state.spiritGauge = math.min(Prototype.Spirit.GaugeMax, state.spiritGauge + reward.gauge)
	local levelsGained = 0
	local capped = false
	-- Mutate's change listener pushes the snapshot (gauge included).
	local committed = profiles.Mutate(player, function(profile)
		levelsGained = ProfileRules.AddXp(profile, reward.xp)
		local _, coinsCapped = ProfileRules.AddCurrency(profile, "coins", reward.coins)
		local _, essenceCapped = ProfileRules.AddCurrency(profile, "essence", reward.essence)
		capped = coinsCapped or essenceCapped
	end)
	if not committed then
		playerState.Commit(player)
		return
	end
	if capped then
		warn("[RewardService] currency cap reached for", player.UserId)
	end
	network.EmitFx("soul_orb", defeat.position, player.UserId, defeat.enemyId)
	if levelsGained > 0 then
		network.EmitFx("level_up", root.Position, player.UserId, nil)
	end
end

local function onDefeated(defeat: Defeat)
	local enemyZoneId = zones.ZoneAt(defeat.position)
	for _, userId in defeat.contributors do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			grant(player, defeat, enemyZoneId)
		end
	end
end

function RewardService.Init(deps: {
	Network: Network,
	PlayerState: PlayerState,
	Profiles: Profiles,
	Enemies: Enemies,
	Zones: Zones,
})
	network = deps.Network
	playerState = deps.PlayerState
	profiles = deps.Profiles
	enemies = deps.Enemies
	zones = deps.Zones
end

function RewardService.Start()
	enemies.OnDefeated(onDefeated)
end

return RewardService

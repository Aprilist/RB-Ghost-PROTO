--!strict
-- Server-authoritative P1 combat: basic 3-step combo (a wave while
-- transformed), the class E skill and dash. M4: reach, cadence, damage and
-- the E skill come from the player's class (Definitions/Classes); the
-- samurai's numbers are the P1 ones.
-- The client sends only intent (sequence/aim/move direction). Hits are
-- found here from the real character position with reach, arc, height band
-- and line of sight; the client never names targets or damage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Definitions.Classes)
local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)
local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local Geometry = require(script.Parent.Parent.Util.Geometry)

type ResultCode = Contracts.ResultCode

type Network = {
	Handle: (string, (Player, { [string]: any }) -> ResultCode) -> (),
	ValidateDirection: (any) -> Vector3?,
	EmitFx: (string, Vector3, number?, string?) -> (),
}

type PlayerState = {
	IsAlive: (Player) -> boolean,
	IsTransformed: (Player) -> boolean,
	GetRoot: (Player) -> BasePart?,
	CooldownReady: (Player, string) -> boolean,
	StartCooldown: (Player, string, number) -> (),
	Commit: (Player) -> (),
}

type EnemyRecord = { id: string, body: BasePart, bodyRadius: number }

type Enemies = {
	GetAlive: () -> { EnemyRecord },
	Damage: (string, number, Player) -> boolean,
}

local C = Prototype.Combat

type Movement = {
	BeginDash: (Player, Vector3) -> number,
	GetAnchor: (Player) -> Vector3?,
}

type Profiles = {
	Get: (Player) -> { classId: string }?,
}

local CombatService = {}

local network: Network
local playerState: PlayerState
local enemies: Enemies
local movement: Movement
local profiles: Profiles

local function kitOf(player: Player): Classes.Kit
	local profile = profiles.Get(player)
	return Classes.Kit(if profile then profile.classId else Prototype.ClassId)
end
local lastSwing: { [Player]: number } = {}

local basicHitListeners: { (Player, { string }) -> () } = {}

-- Hears each basic attack that landed: (player, runtime ids of enemies hit).
-- Skills do not fire it. M2-E ember counts hits through this.
function CombatService.OnBasicHit(callback: (Player, { string }) -> ())
	table.insert(basicHitListeners, callback)
end

-- Applies `damage` to every live enemy in the sector; returns the runtime ids
-- that took damage.
local function strike(player: Player, origin: Vector3, aim: Vector3, reach: number, arcDeg: number, damage: number): { string }
	local hit: { string } = {}
	for _, enemy in enemies.GetAlive() do
		local target = enemy.body.Position
		if Geometry.InSector(origin, aim, target, reach, arcDeg, enemy.bodyRadius) then
			if enemies.Damage(enemy.id, damage, player) then
				table.insert(hit, enemy.id)
				network.EmitFx("slash_hit", target, player.UserId, enemy.id)
			end
		end
	end
	return hit
end

local function basicAttack(player: Player, payload: { [string]: any }): ResultCode
	if not playerState.IsAlive(player) then
		return "DEAD"
	end
	local sequence = payload.sequence :: number
	if sequence < 1 or sequence > C.BasicComboSteps then
		return "INVALID_PAYLOAD"
	end
	local kit = kitOf(player)
	local now = os.clock()
	local last = lastSwing[player]
	if last and now - last < kit.basicIntervalSec * C.CadenceTolerance then
		return "COOLDOWN"
	end
	lastSwing[player] = now

	local root = playerState.GetRoot(player) :: BasePart
	local aim = network.ValidateDirection(payload.aimDirection) :: Vector3
	local hit: { string }
	if playerState.IsTransformed(player) then
		-- Guardian form: short wave, longer reach, same hit pipeline.
		local S = Prototype.Spirit
		network.EmitFx("wave", root.Position + aim * (S.TransformAttackReachStuds / 2), player.UserId, nil)
		hit = strike(player, root.Position, aim, S.TransformAttackReachStuds, S.TransformAttackArcDeg, S.TransformAttackDamage)
	else
		network.EmitFx("slash", root.Position + aim * 3, player.UserId, nil)
		hit = strike(player, root.Position, aim, kit.basicReachStuds, kit.basicArcDeg, kit.basicDamage)
	end
	if #hit > 0 then
		for _, callback in basicHitListeners do
			task.spawn(callback, player, hit)
		end
	end
	return "OK"
end

-- Ninja dash strike: moves through the dash authority (same distance and
-- reconcile rules as dash), then hits everything along the travelled strip.
local function strikeLine(player: Player, origin: Vector3, dir: Vector3, length: number, width: number, damage: number)
	for _, enemy in enemies.GetAlive() do
		local target = enemy.body.Position
		if Geometry.InStrip(origin, dir, target, length, width, enemy.bodyRadius) then
			if enemies.Damage(enemy.id, damage, player) then
				network.EmitFx("slash_hit", target, player.UserId, enemy.id)
			end
		end
	end
end

local function castSkill(player: Player, payload: { [string]: any }): ResultCode
	local kit = kitOf(player)
	local skill = kit.skill
	if payload.skillId ~= skill.id then
		return "NOT_OWNED"
	end
	if not playerState.IsAlive(player) then
		return "DEAD"
	end
	if not playerState.CooldownReady(player, skill.id) then
		return "COOLDOWN"
	end
	playerState.StartCooldown(player, skill.id, skill.cooldownSec)

	local root = playerState.GetRoot(player) :: BasePart
	local aim = network.ValidateDirection(payload.aimDirection) :: Vector3
	if skill.hitShape == "line" then
		local origin = movement.GetAnchor(player) or root.Position
		local allowed = movement.BeginDash(player, aim)
		network.EmitFx("dash", origin + aim * (allowed / 2), player.UserId, nil)
		strikeLine(player, origin, aim, allowed, skill.widthStuds or 4, kit.skillDamage)
	else
		network.EmitFx("sweep", root.Position + aim * 2, player.UserId, nil)
		strike(player, root.Position, aim, skill.rangeStuds, skill.arcDeg, kit.skillDamage)
	end
	playerState.Commit(player)
	return "OK"
end

-- The owning client moves the character (it has network ownership) for
-- responsiveness; the server owns the cooldown and, through MovementService,
-- the allowed distance, path and time window. Travel beyond that, or any
-- predicted dash the server rejects, is reconciled back by MovementService.
local function dash(player: Player, payload: { [string]: any }): ResultCode
	if not playerState.IsAlive(player) then
		return "DEAD"
	end
	if not playerState.CooldownReady(player, "dash") then
		return "COOLDOWN"
	end
	local dir = network.ValidateDirection(payload.moveDirection) :: Vector3
	playerState.StartCooldown(player, "dash", Prototype.Dash.CooldownSec)
	local allowed = movement.BeginDash(player, dir)
	local origin = movement.GetAnchor(player) or (playerState.GetRoot(player) :: BasePart).Position
	network.EmitFx("dash", origin + dir * (allowed / 2), player.UserId, nil)
	playerState.Commit(player)
	return "OK"
end

function CombatService.Init(deps: { Network: Network, PlayerState: PlayerState, Enemies: Enemies, Movement: Movement, Profiles: Profiles })
	network = deps.Network
	playerState = deps.PlayerState
	enemies = deps.Enemies
	movement = deps.Movement
	profiles = deps.Profiles
end

function CombatService.Start()
	network.Handle("basic_attack", basicAttack)
	network.Handle("cast_skill", castSkill)
	network.Handle("dash", dash)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)
end

return CombatService

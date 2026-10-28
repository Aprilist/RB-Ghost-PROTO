--!strict
-- Server-authoritative P1 combat: basic 3-step combo (a wave while
-- transformed), the class E skill and dash. M4: reach, cadence, damage and
-- the E skill come from the player's class (Definitions/Classes); the
-- samurai's numbers are the P1 ones. Shapes: sector (samurai), dash strip
-- (ninja E), nearest-target bolt and circle ahead (onmyoji).
-- The client sends only intent (sequence/aim/move direction). Hits are
-- found here from the real character position with reach, arc, height band
-- and line of sight; the client never names targets or damage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Definitions.Classes)
local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)
local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local Geometry = require(script.Parent.Parent.Util.Geometry)
local SkillRules = require(ReplicatedStorage.Shared.Util.SkillRules)
local Skills = require(ReplicatedStorage.Shared.Definitions.Skills)

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
	SpendSp: (Player, number) -> boolean,
	SpNow: (Player) -> number,
	Heal: (Player, number) -> (),
	GrantDamageBuff: (Player, number, number) -> (),
	DamageMult: (Player) -> number,
	Get: (Player) -> { maxHp: number }?,
}

type EnemyRecord = { id: string, body: BasePart, bodyRadius: number }

type Enemies = {
	GetAlive: () -> { EnemyRecord },
	Damage: (string, number, Player) -> boolean,
	Root: (string, number) -> (),
}

local C = Prototype.Combat

type Movement = {
	BeginDash: (Player, Vector3) -> number,
	GetAnchor: (Player) -> Vector3?,
}

type Profiles = {
	Get: (Player) -> SkillRules.SkillProfile?,
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

-- Buff × learned passive for `stat` (M4-E).
local function damageMult(player: Player, stat: "basicDamagePct" | "skillDamagePct"): number
	local profile = profiles.Get(player)
	return playerState.DamageMult(player) * (1 + (if profile then SkillRules.Bonus(profile, stat) else 0))
end
local lastSwing: { [Player]: number } = {}

local basicHitListeners: { (Player, { string }) -> () } = {}

-- Hears each basic attack that landed: (player, runtime ids of enemies hit).
-- Skills do not fire it. M2-E ember counts hits through this.
function CombatService.OnBasicHit(callback: (Player, { string }) -> ())
	table.insert(basicHitListeners, callback)
end

-- Applies `damage` to every live enemy in the sector (only the nearest one
-- when `nearestOnly`, M4 onmyoji bolt); returns the runtime ids that took
-- damage.
local function strike(player: Player, origin: Vector3, aim: Vector3, reach: number, arcDeg: number, damage: number, nearestOnly: boolean?): { string }
	local targets: { EnemyRecord } = {}
	local nearest: EnemyRecord?, nearestDist = nil, math.huge
	for _, enemy in enemies.GetAlive() do
		if Geometry.InSector(origin, aim, enemy.body.Position, reach, arcDeg, enemy.bodyRadius) then
			table.insert(targets, enemy)
			local d = (enemy.body.Position - origin).Magnitude
			if d < nearestDist then
				nearest, nearestDist = enemy, d
			end
		end
	end
	if nearestOnly then
		targets = if nearest then { nearest } else {}
	end
	local hit: { string } = {}
	for _, enemy in targets do
		if enemies.Damage(enemy.id, damage, player) then
			table.insert(hit, enemy.id)
			network.EmitFx("slash_hit", enemy.body.Position, player.UserId, enemy.id)
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
	local mult = damageMult(player, "basicDamagePct")
	local hit: { string }
	if playerState.IsTransformed(player) then
		-- Guardian form: short wave, longer reach, same hit pipeline.
		local S = Prototype.Spirit
		network.EmitFx("wave", root.Position + aim * (S.TransformAttackReachStuds / 2), player.UserId, nil)
		hit = strike(player, root.Position, aim, S.TransformAttackReachStuds, S.TransformAttackArcDeg, S.TransformAttackDamage * mult)
	elseif kit.basicShape == "bolt" then
		hit = strike(player, root.Position, aim, kit.basicReachStuds, kit.basicArcDeg, kit.basicDamage * mult, true)
		network.EmitFx("talisman_bolt", root.Position + aim * (kit.basicReachStuds / 2), player.UserId, nil)
	else
		network.EmitFx("slash", root.Position + aim * 3, player.UserId, nil)
		hit = strike(player, root.Position, aim, kit.basicReachStuds, kit.basicArcDeg, kit.basicDamage * mult)
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

-- M4: any hotbar skill of the player's class that is unlocked and learned
-- (SkillRules), paid in SP. Damage = weapon × multiplier × rank scale × buff.
-- combat_fx "skill:<id>" at the cast point lets clients draw it from the
-- catalog (the caster predicts sector/bolt/line visuals itself).
local function castSkill(player: Player, payload: { [string]: any }): ResultCode
	local skill = Skills[payload.skillId :: string]
	local profile = profiles.Get(player)
	if not skill or not profile then
		return if profile then "NOT_OWNED" else "NOT_READY"
	end
	local code = SkillRules.CanCast(profile, skill.id)
	if code ~= "OK" then
		return code :: ResultCode
	end
	if not playerState.IsAlive(player) then
		return "DEAD"
	end
	if not playerState.CooldownReady(player, skill.id) then
		return "COOLDOWN"
	end
	if not playerState.SpendSp(player, skill.spCost) then
		return "NO_SP"
	end
	playerState.StartCooldown(player, skill.id, skill.cooldownSec)

	local rank = SkillRules.Rank(profile, skill.id)
	local damage = SkillRules.Damage(skill, rank) * damageMult(player, "skillDamagePct")
	local root = playerState.GetRoot(player) :: BasePart
	local aim = network.ValidateDirection(payload.aimDirection) :: Vector3
	local fx = "skill:" .. skill.id
	if skill.hitShape == "line" then
		local origin = movement.GetAnchor(player) or root.Position
		local allowed = movement.BeginDash(player, aim)
		network.EmitFx(fx, origin + aim * (allowed / 2), player.UserId, nil)
		strikeLine(player, origin, aim, allowed, skill.widthStuds or 4, damage)
	elseif skill.hitShape == "circle" then
		-- A circle ahead (or on self at range 0), its centre stopped short of walls.
		local centre = root.Position + aim * Geometry.ClearDistance(root.Position, aim, skill.rangeStuds, 1)
		network.EmitFx(fx, centre, player.UserId, nil)
		local hit = strike(player, centre, aim, skill.radiusStuds or 6, 360, damage)
		if skill.rootSec then
			for _, id in hit do
				enemies.Root(id, SkillRules.RootSec(skill, rank))
			end
		end
	elseif skill.hitShape == "bolt" then
		network.EmitFx(fx, root.Position + aim * (skill.rangeStuds / 2), player.UserId, nil)
		strike(player, root.Position, aim, skill.rangeStuds, skill.arcDeg, damage, true)
	elseif skill.hitShape == "buff" then
		network.EmitFx(fx, root.Position, player.UserId, nil)
		playerState.GrantDamageBuff(player, skill.buffMult or 1, SkillRules.BuffSec(skill, rank))
	elseif skill.hitShape == "heal" then
		network.EmitFx(fx, root.Position, player.UserId, nil)
		local state = playerState.Get(player)
		if state then
			playerState.Heal(player, math.floor(state.maxHp * SkillRules.HealFraction(skill, rank) + 0.5))
		end
	else
		network.EmitFx(fx, root.Position + aim * 2, player.UserId, nil)
		strike(player, root.Position, aim, skill.rangeStuds, skill.arcDeg, damage)
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

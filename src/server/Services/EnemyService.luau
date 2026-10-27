--!strict
-- Normal enemies (P1 lantern wisp + M2-C Mistwood yokai). Each EnemySpawn
-- marker names its catalog entry with attribute EnemyType (lantern_wisp when
-- missing) and spawns `groupSize` of it, up to `maxAlive` per type. Enemies
-- chase within a leash, telegraph → attack → recover, die once, and respawn
-- after a delay with a new runtime ID. Server-owned anchored models.
-- The attack area is fixed when the telegraph starts (EnemyAttackRules), so
-- the warning on the ground is exactly what the hit checks.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enemies = require(ReplicatedStorage.Shared.Definitions.Enemies)
local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local VisualPalette = require(ReplicatedStorage.Shared.Definitions.VisualPalette)
local Geometry = require(script.Parent.Parent.Util.Geometry)
local EnemyAttackRules = require(script.Parent.Parent.Util.EnemyAttackRules)
local Models = require(script.Parent.Parent.Enemies.Models)

type EnemyDef = Enemies.EnemyDef
type Plan = EnemyAttackRules.Plan

type EnemyState = "idle" | "telegraph" | "recover" | "dead"

export type Enemy = {
	id: string,
	def: EnemyDef,
	spawnPoint: Vector3, -- ground point under the hover position
	model: Model,
	body: BasePart,
	bodyRadius: number, -- CombatService hit tolerance
	tints: { Models.Tint },
	ring: BasePart,
	ringFill: BasePart,
	fill: Frame,
	hp: number,
	state: EnemyState,
	stateUntil: number,
	plan: Plan?,
	contributors: { [number]: boolean },
}

export type Defeat = {
	enemyId: string, -- runtime ID
	definitionId: string, -- catalog ID (Definitions/Enemies)
	position: Vector3,
	contributors: { number },
	-- M2-F: helpers a boss summons pay no reward and never respawn.
	noReward: boolean,
}

type Network = {
	EmitFx: (string, Vector3, number?, string?) -> (),
}

type PlayerState = {
	IsAlive: (Player) -> boolean,
	GetRoot: (Player) -> BasePart?,
	Damage: (Player, number) -> (),
}

local DEFAULT_TYPE = "lantern_wisp"
local GROUP_SPACING_STUDS = 3
-- SpawnId of enemies a boss summoned (SpawnAdd): no reward, no respawn.
local ADD_SPAWN_ID = "boss_add"

local EnemyService = {}

local network: Network
local playerState: PlayerState
local enemies: { [string]: Enemy } = {}
local runtimeCounter = 0
local defeatedListeners: { (Defeat) -> () } = {}

local UPRIGHT = Models.UPRIGHT
local visualPart = Models.VisualPart

local function runtimeFolder(): Instance?
	local root = workspace:FindFirstChild(Prototype.WorldNamespace)
	if not root then
		return nil
	end
	local folder = root:FindFirstChild("Runtime")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Runtime"
		folder.Parent = root
	end
	return folder
end

local function isLine(def: EnemyDef): boolean
	return def.tuning.attackShape == "charge" or def.tuning.attackShape == "lunge"
end

-- Ground warning: a bright rim under a darker fill, so the edge of the attack
-- area reads as an outline (shape + pulse, not colour alone) and stays
-- distinct from amber lantern light. Discs for burst/leap, strips for lines.
-- Burst sits under the body and moves with it; the others are placed when a
-- telegraph starts.
local function buildTelegraph(model: Model, def: EnemyDef, at: CFrame): (BasePart, BasePart)
	local t = def.tuning
	local ring: Part, ringFill: Part
	if isLine(def) then
		ring = visualPart(model, "TelegraphRing", Vector3.new(t.attackWidthStuds, 0.12, t.attackHitRangeStuds), VisualPalette.DangerRim, Enum.Material.Neon)
		ringFill = visualPart(model, "TelegraphFill", Vector3.new(math.max(0.2, t.attackWidthStuds - 0.9), 0.12, math.max(0.2, t.attackHitRangeStuds - 0.9)), VisualPalette.DangerFill, Enum.Material.SmoothPlastic)
	else
		local d = (if t.attackShape == "leap" then t.attackWidthStuds else t.attackHitRangeStuds) * 2
		ring = visualPart(model, "TelegraphRing", Vector3.new(0.12, d, d), VisualPalette.DangerRim, Enum.Material.Neon)
		ring.Shape = Enum.PartType.Cylinder
		ringFill = visualPart(model, "TelegraphFill", Vector3.new(0.12, d - 0.9, d - 0.9), VisualPalette.DangerFill, Enum.Material.SmoothPlastic)
		ringFill.Shape = Enum.PartType.Cylinder
		local ringCf = at * CFrame.new(0, -t.hoverHeightStuds + 0.12, 0) * UPRIGHT
		ring.CFrame = ringCf
		ringFill.CFrame = ringCf * CFrame.new(0.05, 0, 0)
	end
	ring.CastShadow = false
	ring.Transparency = 1
	ringFill.CastShadow = false
	ringFill.Transparency = 1
	return ring, ringFill
end

local function buildHpBar(body: BasePart, offset: number): Frame
	local gui = Instance.new("BillboardGui")
	gui.Name = "HpBar"
	gui.Size = UDim2.fromOffset(70, 8)
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 60
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(30, 28, 40)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 170, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	gui.Parent = body
	return fill
end

-- Put a leap or line warning on the ground for `plan` (burst rides the body).
local function placeTelegraph(enemy: Enemy, plan: Plan)
	local groundY = enemy.spawnPoint.Y + 0.12
	if plan.shape == "burst" then
		return
	elseif plan.shape == "leap" then
		local cf = CFrame.new(plan.center.X, groundY, plan.center.Z) * UPRIGHT
		enemy.ring.CFrame = cf
		enemy.ringFill.CFrame = cf * CFrame.new(0.05, 0, 0)
	else
		local from = Vector3.new(plan.origin.X, groundY, plan.origin.Z)
		local mid = from + plan.dir * (plan.length / 2)
		local cf = CFrame.lookAt(mid, mid + plan.dir)
		local w = plan.width
		enemy.ring.Size = Vector3.new(w, 0.12, math.max(0.2, plan.length))
		enemy.ringFill.Size = Vector3.new(math.max(0.2, w - 0.9), 0.12, math.max(0.2, plan.length - 0.9))
		enemy.ring.CFrame = cf
		enemy.ringFill.CFrame = cf * CFrame.new(0, 0.05, 0)
	end
end

local function setState(enemy: Enemy, state: EnemyState, duration: number)
	enemy.state = state
	enemy.stateUntil = os.clock() + duration
	enemy.model:SetAttribute("State", state)
	local telegraph = state == "telegraph"
	enemy.ring.Transparency = if telegraph then 0.45 else 1
	enemy.ringFill.Transparency = if telegraph then 0.5 else 1
	for _, tint in enemy.tints do
		tint.part.Color = if telegraph then tint.angry else tint.calm
	end
	if not telegraph then
		enemy.plan = nil
	end
end

local function spawnAt(spawnId: string, ground: Vector3, def: EnemyDef): string?
	local folder = runtimeFolder()
	if not folder then
		return nil
	end
	runtimeCounter += 1
	local id = def.id .. "#" .. runtimeCounter
	local at = CFrame.new(ground + Vector3.new(0, def.tuning.hoverHeightStuds, 0))
	local built = Models.Build(def.id, at)
	local model = built.model
	model:SetAttribute("EnemyId", id)
	model:SetAttribute("EnemyType", def.id)
	model:SetAttribute("Placeholder", true)
	local ring, ringFill = buildTelegraph(model, def, at)
	local fill = buildHpBar(built.body, built.hpBarOffsetStuds)
	CollectionService:AddTag(model, "Enemy")
	model:SetAttribute("SpawnId", spawnId)
	model:SetAttribute("MaxHp", def.maxHp)
	model:SetAttribute("Hp", def.maxHp)
	model.Parent = folder

	local enemy: Enemy = {
		id = id,
		def = def,
		spawnPoint = ground,
		model = model,
		body = built.body,
		bodyRadius = def.tuning.bodyRadiusStuds,
		tints = built.tints,
		ring = ring,
		ringFill = ringFill,
		fill = fill,
		hp = def.maxHp,
		state = "idle",
		stateUntil = 0,
		plan = nil,
		contributors = {},
	}
	enemies[id] = enemy
	setState(enemy, "idle", 0)
	return id
end

local function aliveCount(definitionId: string): number
	local n = 0
	for _, enemy in enemies do
		if enemy.state ~= "dead" and enemy.def.id == definitionId then
			n += 1
		end
	end
	return n
end

local function die(enemy: Enemy, spawnId: string)
	-- Single transition: Damage() refuses dead enemies, so this runs once per runtime ID.
	enemy.state = "dead"
	enemy.model:SetAttribute("State", "dead")
	local position = enemy.body.Position
	local def = enemy.def

	local contributors = {}
	for userId in enemy.contributors do
		table.insert(contributors, userId)
	end
	local defeat: Defeat = {
		enemyId = enemy.id,
		definitionId = def.id,
		position = position,
		contributors = contributors,
		noReward = spawnId == ADD_SPAWN_ID,
	}
	for _, callback in defeatedListeners do
		task.spawn(callback, defeat)
	end
	network.EmitFx("enemy_death", position, nil, enemy.id)

	task.delay(0.35, function()
		enemy.model:Destroy()
		enemies[enemy.id] = nil
	end)
	if spawnId == ADD_SPAWN_ID then
		return
	end
	task.delay(def.respawnSec, function()
		if aliveCount(def.id) < def.tuning.maxAlive then
			spawnAt(spawnId, enemy.spawnPoint, def)
		end
	end)
end

-- A boss's helper: a normal enemy of `definitionId` on the ground at `ground`
-- that pays no reward and does not respawn. Returns its runtime id, or nil
-- when the id is unknown/draft or the world is not built.
function EnemyService.SpawnAdd(definitionId: string, ground: Vector3): string?
	local def = Enemies[definitionId]
	if not def or def.draft or not Models.Has(definitionId) then
		return nil
	end
	return spawnAt(ADD_SPAWN_ID, ground, def)
end

-- Removes an enemy at once with no defeat, reward or respawn (boss reset).
function EnemyService.Despawn(enemyId: string)
	local enemy = enemies[enemyId]
	if not enemy then
		return
	end
	enemy.state = "dead"
	enemies[enemyId] = nil
	enemy.model:Destroy()
end

-- Returns true when damage applied. Unknown or dead enemies are ignored.
function EnemyService.Damage(enemyId: string, amount: number, attacker: Player): boolean
	local enemy = enemies[enemyId]
	if not enemy or enemy.state == "dead" or amount <= 0 then
		return false
	end
	enemy.hp = math.max(0, enemy.hp - amount)
	enemy.contributors[attacker.UserId] = true
	enemy.model:SetAttribute("Hp", enemy.hp)
	enemy.fill.Size = UDim2.fromScale(enemy.hp / enemy.def.maxHp, 1)
	if enemy.hp <= 0 then
		die(enemy, enemy.model:GetAttribute("SpawnId") :: string)
	end
	return true
end

function EnemyService.GetAlive(): { Enemy }
	local list = {}
	for _, enemy in enemies do
		if enemy.state ~= "dead" then
			table.insert(list, enemy)
		end
	end
	return list
end

function EnemyService.OnDefeated(callback: (Defeat) -> ())
	table.insert(defeatedListeners, callback)
end

local function nearestTarget(enemy: Enemy): (Player?, BasePart?, number)
	local def = enemy.def
	local best: Player?, bestRoot: BasePart?, bestDist = nil, nil, math.huge
	local pos = enemy.body.Position
	for _, player in game:GetService("Players"):GetPlayers() do
		local root = playerState.IsAlive(player) and playerState.GetRoot(player)
		if root and math.abs(root.Position.Y - pos.Y) <= Prototype.Combat.MaxHeightDiffStuds then
			local dist = Geometry.Flat(root.Position - pos).Magnitude
			local fromSpawn = Geometry.Flat(root.Position - enemy.spawnPoint).Magnitude
			if dist < bestDist and dist <= def.detectionRangeStuds and fromSpawn <= def.tuning.leashStuds + def.attackRangeStuds then
				best, bestRoot, bestDist = player, root, dist
			end
		end
	end
	return best, bestRoot, bestDist
end

-- How far the body may travel: walls (Collision) and, for shapes that move
-- the enemy, the leash circle round its spawn point.
local function clearFor(enemy: Enemy): EnemyAttackRules.ClearFn
	local def = enemy.def
	local moves = def.tuning.attackShape == "charge" or def.tuning.attackShape == "leap"
	return function(origin: Vector3, dir: Vector3, distance: number): number
		local d = Geometry.ClearDistance(origin, dir, distance, def.tuning.bodyRadiusStuds * 0.8)
		if moves then
			d = math.min(d, EnemyAttackRules.DistanceInsideCircle(origin, dir, enemy.spawnPoint, def.tuning.leashStuds))
		end
		return d
	end
end

local function startTelegraph(enemy: Enemy, target: Vector3)
	local pos = enemy.body.Position
	local plan = EnemyAttackRules.Plan(enemy.def, pos, target, clearFor(enemy))
	if plan.shape ~= "burst" then
		-- Face the attack. Burst (the wisp) keeps its P1 behaviour: no turn.
		enemy.model:PivotTo(CFrame.lookAt(pos, pos + plan.dir))
	end
	setState(enemy, "telegraph", enemy.def.telegraphSec)
	enemy.plan = plan
	placeTelegraph(enemy, plan)
	network.EmitFx("enemy_telegraph", if plan.shape == "burst" then pos else plan.center, nil, enemy.id)
end

local function resolveAttack(enemy: Enemy)
	local plan = enemy.plan
	if not plan then
		return
	end
	local finish = EnemyAttackRules.EndPosition(plan)
	if finish then
		enemy.model:PivotTo(CFrame.lookAt(finish, finish + plan.dir))
	end
	-- Burst checks from the body as in P1; a leap from where it lands; lines
	-- from where the rush or strike started.
	local from = if plan.shape == "burst" then enemy.body.Position else plan.center
	local sightFrom = if plan.shape == "charge" or plan.shape == "lunge" then plan.origin else from
	network.EmitFx("enemy_attack", from, nil, enemy.id)
	for _, player in game:GetService("Players"):GetPlayers() do
		local root = playerState.IsAlive(player) and playerState.GetRoot(player)
		if root then
			if
				EnemyAttackRules.Hits(plan, root.Position)
				and math.abs(root.Position.Y - from.Y) <= Prototype.Combat.MaxHeightDiffStuds
				and Geometry.LineOfSight(sightFrom, root.Position)
			then
				playerState.Damage(player, enemy.def.attackDamage)
				network.EmitFx("player_hit", root.Position, player.UserId, enemy.id)
			end
		end
	end
end

local STEER_ANGLES = { 0, 45, -45, 90, -90 }

local function moveToward(enemy: Enemy, goal: Vector3, dt: number, t: number)
	local def = enemy.def
	local pos = enemy.body.Position
	local flat = Geometry.Flat(goal - pos)
	local hoverY = enemy.spawnPoint.Y + def.tuning.hoverHeightStuds + Models.Bob(def.id, t)
	local nextPos = Vector3.new(pos.X, hoverY, pos.Z)
	local look = enemy.body.CFrame.LookVector
	if flat.Magnitude > 0.5 then
		local want = math.min(flat.Magnitude, def.moveSpeedStudsSec * dt)
		local radius = def.tuning.bodyRadiusStuds * 0.8
		look = flat.Unit
		if not def.tuning.steer then
			-- P1 rule: straight on, as far as walls allow, inside the leash.
			local step = math.min(want, Geometry.ClearDistance(pos, look, want, radius))
			local candidate = nextPos + look * step
			if Geometry.Flat(candidate - enemy.spawnPoint).Magnitude <= def.tuning.leashStuds then
				nextPos = candidate
			end
		else
			-- Straight on first, then side steps round a trunk or wall.
			for _, deg in STEER_ANGLES do
				local dir = CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(flat.Unit)
				local step = math.min(want, Geometry.ClearDistance(pos, dir, want, radius))
				local candidate = nextPos + dir * step
				if step >= want * 0.5 and Geometry.Flat(candidate - enemy.spawnPoint).Magnitude <= def.tuning.leashStuds then
					nextPos = candidate
					look = dir
					break
				end
			end
		end
	end
	enemy.model:PivotTo(CFrame.lookAt(nextPos, nextPos + look))
end

local function tick(dt: number)
	local now = os.clock()
	for _, enemy in enemies do
		if enemy.state == "dead" then
			continue
		end
		local def = enemy.def
		if enemy.state == "telegraph" then
			-- Pulse the warning so it is readable without colour.
			local k = 1 - math.max(0, enemy.stateUntil - now) / def.telegraphSec
			enemy.ring.Transparency = 0.7 - 0.4 * k
			enemy.ringFill.Transparency = 0.5 - 0.2 * k
			if now >= enemy.stateUntil then
				resolveAttack(enemy)
				setState(enemy, "recover", def.recoverSec)
			end
		elseif enemy.state == "recover" then
			if now >= enemy.stateUntil then
				setState(enemy, "idle", 0)
			end
		else
			local _, root, dist = nearestTarget(enemy)
			if root and dist <= def.attackRangeStuds and Geometry.LineOfSight(enemy.body.Position, root.Position) then
				startTelegraph(enemy, root.Position)
			elseif root then
				moveToward(enemy, root.Position, dt, now)
			else
				moveToward(enemy, enemy.spawnPoint, dt, now)
			end
		end
	end
end

function EnemyService.Init(deps: { Network: Network, PlayerState: PlayerState })
	network = deps.Network
	playerState = deps.PlayerState
end

function EnemyService.Start()
	local root = workspace:FindFirstChild(Prototype.WorldNamespace)
	for _, marker in CollectionService:GetTagged("EnemySpawn") do
		if not (marker:IsA("BasePart") and root and marker:IsDescendantOf(root)) then
			continue
		end
		local typeId = (marker:GetAttribute("EnemyType") :: string?) or DEFAULT_TYPE
		local def = Enemies[typeId]
		if not def or def.draft or not Models.Has(typeId) then
			warn("[EnemyService] skipping spawn", marker:GetFullName(), "unknown or draft enemy", typeId)
			continue
		end
		local spawnId = marker:GetAttribute("EnemySpawnId") :: string
		local ground = marker.Position - Vector3.new(0, 0.1, 0)
		for i = 1, def.tuning.groupSize do
			if aliveCount(typeId) >= def.tuning.maxAlive then
				break
			end
			-- Group members stand side by side round the marker.
			local offset = (i - (def.tuning.groupSize + 1) / 2) * GROUP_SPACING_STUDS
			spawnAt(spawnId, ground + Vector3.new(offset, 0, 0), def)
		end
	end
	-- One AI loop for every type, at the P1 tick (CatalogTest keeps all equal).
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Prototype.Enemy.AiTickSec)
			local now = os.clock()
			tick(now - last)
			last = now
		end
	end)
end

return EnemyService

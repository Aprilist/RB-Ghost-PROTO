--!strict
-- The Extinguished Keeper (M2-F). One boss, server-owned. It walks after the
-- nearest player in the arena and loops through its moves (Definitions/Bosses):
--   sweep   a wide arc in front of it            (fan warning on the ground)
--   ring    three circles, on players first      (disc warnings)
--   summon  two helper spirits, then it opens up (ring of lantern light)
-- Every move shows its warning on the ground for the whole telegraph and the
-- hit at the end checks exactly that area (Util/BossRules). After the summon
-- the boss stands still and takes extra damage for a few seconds.
-- Player attacks reach it through TargetService (same strike/damage path as
-- normal enemies); this service owns its HP and who dealt how much.
-- Engage/Reset/OnDefeated are the hooks the encounter (part 2) uses; until it
-- takes over, the boss engages itself when a player walks into the arena.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Bosses = require(ReplicatedStorage.Shared.Definitions.Bosses)
local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local VisualPalette = require(ReplicatedStorage.Shared.Definitions.VisualPalette)
local BossModel = require(script.Parent.Parent.Enemies.BossModel)
local Models = require(script.Parent.Parent.Enemies.Models)
local BossRules = require(script.Parent.Parent.Util.BossRules)
local Geometry = require(script.Parent.Parent.Util.Geometry)

type BossDef = Bosses.BossDef
type MoveId = Bosses.MoveId

type BossState = "idle" | "telegraph" | "recover" | "open" | "dead"

export type Defeat = {
	bossId: string,
	runtimeId: string,
	position: Vector3,
	maxHp: number,
	damageBy: { [number]: number },
}

type Boss = {
	runtimeId: string,
	def: BossDef,
	model: Model,
	body: BasePart,
	tints: { Models.Tint },
	openTints: { Models.Tint },
	fill: Frame,
	hp: number,
	state: BossState,
	stateUntil: number,
	moveIndex: number,
	move: MoveId?,
	arcOrigin: Vector3,
	arcDir: Vector3,
	spots: { Vector3 },
	telegraph: Folder?,
	rims: { BasePart },
	fills: { BasePart },
	damageBy: { [number]: number },
	adds: { string },
	engaged: boolean,
	emptySince: number?,
}

type Network = {
	EmitFx: (string, Vector3, number?, string?) -> (),
}

type PlayerState = {
	IsAlive: (Player) -> boolean,
	GetRoot: (Player) -> BasePart?,
	Damage: (Player, number) -> (),
}

type EnemyRecord = { id: string, body: BasePart }

type Enemies = {
	GetAlive: () -> { EnemyRecord },
	SpawnAdd: (string, Vector3) -> string?,
	Despawn: (string) -> (),
}

local BossService = {}

local network: Network
local playerState: PlayerState
local enemies: Enemies
local boss: Boss? = nil
local runtimeCounter = 0
local autoEngage = true
local defeatedListeners: { (Defeat) -> () } = {}
local resetListeners: { () -> () } = {}
-- When set (by EncounterService), only these players are fought and only
-- their hits count. The table is the encounter's own and changes in place.
local members: { [Player]: boolean }? = nil

local UPRIGHT = Models.UPRIGHT
local DEF: BossDef = Bosses.extinguished_keeper
local FAN_STRIPS = 9

local function groundY(): number
	return Prototype.Arena.FloorTopY
end

------------------------------------------------------------------------------
-- Players in the arena
------------------------------------------------------------------------------

type Present = { player: Player, root: BasePart }

local function presentPlayers(def: BossDef): { Present }
	local list: { Present } = {}
	local filter = members
	for _, player in Players:GetPlayers() do
		local root = if playerState.IsAlive(player) then playerState.GetRoot(player) else nil
		if root and BossRules.InArena(root.Position, def) and (filter == nil or filter[player] == true) then
			table.insert(list, { player = player, root = root })
		end
	end
	return list
end

local function nearest(list: { Present }, from: Vector3): (Present?, number)
	local best: Present?, bestDist = nil, math.huge
	for _, p in list do
		local d = (Vector3.new(p.root.Position.X, 0, p.root.Position.Z) - from).Magnitude
		if d < bestDist then
			best, bestDist = p, d
		end
	end
	return best, bestDist
end

------------------------------------------------------------------------------
-- Look and warnings
------------------------------------------------------------------------------

local function paint(b: Boss)
	for _, tint in b.tints do
		tint.part.Color = tint.calm
	end
	if b.state == "telegraph" then
		for _, tint in b.tints do
			tint.part.Color = tint.angry
		end
	elseif b.state == "open" then
		for _, tint in b.openTints do
			tint.part.Color = tint.angry
		end
	elseif b.state == "dead" then
		for _, tint in b.tints do
			tint.part.Color = Color3.fromRGB(70, 68, 76)
		end
	end
end

local function setState(b: Boss, state: BossState, duration: number)
	b.state = state
	b.stateUntil = os.clock() + duration
	b.model:SetAttribute("State", state)
	b.model:SetAttribute("Open", state == "open")
	paint(b)
end

local function clearTelegraph(b: Boss)
	if b.telegraph then
		b.telegraph:Destroy()
	end
	b.telegraph = nil
	b.rims = {}
	b.fills = {}
end

local function telegraphFolder(b: Boss): Folder
	clearTelegraph(b)
	local folder = Instance.new("Folder")
	folder.Name = "Telegraph"
	folder.Parent = b.model
	b.telegraph = folder
	return folder
end

-- Flat warning disc on the ground (rim over a darker fill, like enemy warnings).
local function addDisc(b: Boss, center: Vector3, radius: number, rim: Color3, fill: Color3)
	local folder = b.telegraph :: Folder
	local d = radius * 2
	local y = groundY() + 0.12
	local ring = Models.VisualPart(folder, "TelegraphRing", Vector3.new(0.12, d, d), rim, Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.CastShadow = false
	ring.CFrame = CFrame.new(center.X, y, center.Z) * UPRIGHT
	local inner = Models.VisualPart(folder, "TelegraphFill", Vector3.new(0.12, math.max(0.2, d - 1.2), math.max(0.2, d - 1.2)), fill, Enum.Material.SmoothPlastic)
	inner.Shape = Enum.PartType.Cylinder
	inner.CastShadow = false
	inner.CFrame = CFrame.new(center.X, y + 0.05, center.Z) * UPRIGHT
	ring.Transparency = 0.7
	inner.Transparency = 0.55
	table.insert(b.rims, ring)
	table.insert(b.fills, inner)
end

-- Flat fan warning for the sweep: strips side by side over the arc, with a
-- bright strip on each edge so the boundary reads by shape, not colour only.
local function addFan(b: Boss, origin: Vector3, dir: Vector3, reach: number, arcDeg: number)
	local folder = b.telegraph :: Folder
	local y = groundY() + 0.12
	local step = math.rad(arcDeg) / FAN_STRIPS
	local width = reach * step * 1.08
	for i = 0, FAN_STRIPS - 1 do
		local offset = -math.rad(arcDeg) / 2 + (i + 0.5) * step
		local d = CFrame.Angles(0, offset, 0):VectorToWorldSpace(dir)
		local mid = Vector3.new(origin.X, y + i * 0.004, origin.Z) + d * (reach / 2)
		local strip = Models.VisualPart(folder, "TelegraphFill", Vector3.new(width, 0.12, reach), VisualPalette.DangerFill, Enum.Material.SmoothPlastic)
		strip.CastShadow = false
		strip.CFrame = CFrame.lookAt(mid, mid + d)
		strip.Transparency = 0.55
		table.insert(b.fills, strip)
	end
	for _, sign in { -1, 1 } do
		local d = CFrame.Angles(0, sign * math.rad(arcDeg) / 2, 0):VectorToWorldSpace(dir)
		local mid = Vector3.new(origin.X, y + 0.06, origin.Z) + d * (reach / 2)
		local edge = Models.VisualPart(folder, "TelegraphEdge", Vector3.new(0.6, 0.12, reach), VisualPalette.DangerRim, Enum.Material.Neon)
		edge.CastShadow = false
		edge.CFrame = CFrame.lookAt(mid, mid + d)
		edge.Transparency = 0.7
		table.insert(b.rims, edge)
	end
end

local function buildHpBar(b: Boss): Frame
	local gui = Instance.new("BillboardGui")
	gui.Name = "BossHpBar"
	gui.Size = UDim2.fromOffset(220, 34)
	gui.StudsOffset = Vector3.new(0, 17 - BossModel.HitboxHeightStuds, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 22)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.4
	title.Text = b.def.displayNameTH
	title.Parent = gui
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 24)
	back.Size = UDim2.new(1, 0, 0, 10)
	back.BackgroundColor3 = Color3.fromRGB(30, 28, 40)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 170, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	gui.Parent = b.body
	return fill
end

------------------------------------------------------------------------------
-- Build / reset
------------------------------------------------------------------------------

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

local function build(def: BossDef): Boss?
	local folder = runtimeFolder()
	if not folder then
		warn("[BossService] scene root missing; boss not built")
		return nil
	end
	runtimeCounter += 1
	local runtimeId = def.id .. "#" .. runtimeCounter
	local at = CFrame.new(def.spawnX, groundY() + BossModel.HitboxHeightStuds, def.spawnZ)
	local built = BossModel.Build(at)
	local model = built.model
	model:SetAttribute("EnemyId", runtimeId)
	model:SetAttribute("EnemyType", def.id)
	model:SetAttribute("Placeholder", true)
	model:SetAttribute("MaxHp", def.maxHp)
	model:SetAttribute("Hp", def.maxHp)
	CollectionService:AddTag(model, "Enemy") -- client soft aim reads the tag
	local b: Boss = {
		runtimeId = runtimeId,
		def = def,
		model = model,
		body = built.body,
		tints = built.tints,
		openTints = built.openTints,
		fill = nil :: any,
		hp = def.maxHp,
		state = "idle",
		stateUntil = 0,
		moveIndex = 1,
		move = nil,
		arcOrigin = Vector3.zero,
		arcDir = Vector3.new(0, 0, 1),
		spots = {},
		telegraph = nil,
		rims = {},
		fills = {},
		damageBy = {},
		adds = {},
		engaged = false,
		emptySince = nil,
	}
	b.fill = buildHpBar(b)
	model.Parent = folder
	setState(b, "idle", 0)
	return b
end

local function despawnAdds(b: Boss)
	for _, id in b.adds do
		enemies.Despawn(id)
	end
	b.adds = {}
end

-- Back to a fresh boss at full HP, waiting for the next fight.
function BossService.Reset()
	local old = boss
	if old then
		clearTelegraph(old)
		despawnAdds(old)
		if old.model.Parent then
			old.model:Destroy()
		end
	end
	boss = build(DEF)
	for _, callback in resetListeners do
		task.spawn(callback)
	end
end

-- Hears every reset: an abandoned fight, a defeat's respawn and the first build.
function BossService.OnReset(callback: () -> ())
	table.insert(resetListeners, callback)
end

function BossService.SetMembers(set: { [Player]: boolean }?)
	members = set
end

function BossService.Engage()
	local b = boss
	if b and not b.engaged and b.state == "idle" then
		b.engaged = true
		b.emptySince = nil
		b.moveIndex = 1
	end
end

------------------------------------------------------------------------------
-- Moves
------------------------------------------------------------------------------

local function moveTimes(def: BossDef, move: MoveId): (number, number)
	if move == "sweep" then
		return def.sweep.telegraphSec, def.sweep.recoverSec
	elseif move == "ring" then
		return def.ring.telegraphSec, def.ring.recoverSec
	end
	return def.summon.telegraphSec, def.summon.recoverSec
end

local function face(b: Boss, dir: Vector3)
	local pos = b.body.Position
	b.model:PivotTo(CFrame.lookAt(pos, pos + dir))
end

local function startMove(b: Boss, move: MoveId, targets: { Present })
	local def = b.def
	local pos = b.body.Position
	local flat = Vector3.new(pos.X, 0, pos.Z)
	telegraphFolder(b)
	b.move = move
	local fxAt = pos
	if move == "sweep" then
		local target = nearest(targets, flat)
		local offset = if target then Vector3.new(target.root.Position.X, 0, target.root.Position.Z) - flat else Vector3.new(0, 0, 1)
		local dir = if offset.Magnitude > 1e-3 then offset.Unit else Vector3.new(0, 0, 1)
		b.arcOrigin = pos
		b.arcDir = dir
		face(b, dir)
		addFan(b, pos, dir, def.sweep.reachStuds, def.sweep.arcDeg)
	elseif move == "ring" then
		local at: { Vector3 } = {}
		for _, p in targets do
			table.insert(at, p.root.Position)
		end
		b.spots = BossRules.RingSpots(at, def)
		for _, spot in b.spots do
			addDisc(b, spot, def.ring.radiusStuds, VisualPalette.DangerRim, VisualPalette.DangerFill)
		end
	else
		-- Summon: a calm ember ring, not danger colours: it hurts nobody.
		addDisc(b, flat, def.summon.spreadStuds + 2, VisualPalette.Ember, VisualPalette.BossLanternDim)
	end
	local telegraphSec = moveTimes(def, move)
	setState(b, "telegraph", telegraphSec)
	network.EmitFx("enemy_telegraph", fxAt, nil, b.runtimeId)
end

local function hurt(player: Player, root: BasePart, amount: number)
	playerState.Damage(player, amount)
	network.EmitFx("player_hit", root.Position, player.UserId, nil)
end

local function liveAddCount(b: Boss): number
	local alive: { [string]: boolean } = {}
	for _, e in enemies.GetAlive() do
		alive[e.id] = true
	end
	local kept: { string } = {}
	for _, id in b.adds do
		if alive[id] then
			table.insert(kept, id)
		end
	end
	b.adds = kept
	return #kept
end

local function resolveMove(b: Boss)
	local def = b.def
	local move = b.move
	local band = Prototype.Combat.MaxHeightDiffStuds
	if move == "sweep" then
		local s = def.sweep
		network.EmitFx("enemy_attack", b.arcOrigin + b.arcDir * (s.reachStuds / 2), nil, b.runtimeId)
		for _, p in presentPlayers(def) do
			if
				math.abs(p.root.Position.Y - b.arcOrigin.Y) <= band + BossModel.HitboxHeightStuds
				and BossRules.InArc(b.arcOrigin, b.arcDir, p.root.Position, s.reachStuds, s.arcDeg)
			then
				hurt(p.player, p.root, s.damage)
			end
		end
	elseif move == "ring" then
		for _, spot in b.spots do
			network.EmitFx("enemy_attack", Vector3.new(spot.X, groundY() + 1, spot.Z), nil, b.runtimeId)
		end
		for _, p in presentPlayers(def) do
			for _, spot in b.spots do
				if BossRules.InCircle(spot, p.root.Position, def.ring.radiusStuds) then
					hurt(p.player, p.root, def.ring.damage)
					break -- one hit per player per cast, even where circles overlap
				end
			end
		end
	elseif move == "summon" then
		local room = def.summon.maxAlive - liveAddCount(b)
		local want = math.min(def.summon.count, room)
		if want > 0 then
			for _, spot in BossRules.SummonSpots(b.body.Position, want, def) do
				local id = enemies.SpawnAdd(def.summon.addId, Vector3.new(spot.X, groundY(), spot.Z))
				if id then
					table.insert(b.adds, id)
				end
			end
		end
	end
	clearTelegraph(b)
	b.move = nil
	local _, recoverSec = moveTimes(def, move or "summon")
	if move == def.openAfter then
		setState(b, "open", def.openWindowSec)
	else
		setState(b, "recover", recoverSec + def.gapSec)
	end
end

------------------------------------------------------------------------------
-- Movement and the AI loop
------------------------------------------------------------------------------

local STEER_ANGLES = { 0, 45, -45, 90, -90 }

local function moveToward(b: Boss, goal: Vector3, dt: number)
	local def = b.def
	local pos = b.body.Position
	local offset = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
	if offset.Magnitude < 0.5 then
		return
	end
	local want = math.min(offset.Magnitude, def.moveSpeedStudsSec * dt)
	local radius = def.bodyRadiusStuds * 0.8
	local look = offset.Unit
	local nextPos = pos
	for _, deg in STEER_ANGLES do
		local dir = CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(offset.Unit)
		local step = math.min(want, Geometry.ClearDistance(pos, dir, want, radius))
		if step >= want * 0.5 then
			nextPos = BossRules.Clamp(pos + dir * step, def, def.bodyRadiusStuds)
			look = dir
			break
		end
	end
	nextPos = Vector3.new(nextPos.X, pos.Y, nextPos.Z)
	b.model:PivotTo(CFrame.lookAt(nextPos, nextPos + look))
end

local function tick(dt: number)
	local b = boss
	if not b or b.state == "dead" then
		return
	end
	local def = b.def
	local now = os.clock()
	local present = presentPlayers(def)

	if not b.engaged then
		if autoEngage and #present > 0 then
			BossService.Engage()
		end
		return
	end

	-- Nobody alive in the arena for a while: the fight is over, start fresh.
	if #present == 0 then
		b.emptySince = b.emptySince or now
		if now - (b.emptySince :: number) >= def.resetAfterEmptySec then
			BossService.Reset()
			return
		end
	else
		b.emptySince = nil
	end

	if b.state == "telegraph" then
		local telegraphSec = moveTimes(def, b.move or "summon")
		-- Pulse so the warning is readable without colour.
		local k = 1 - math.max(0, b.stateUntil - now) / telegraphSec
		for _, part in b.rims do
			part.Transparency = 0.7 - 0.4 * k
		end
		for _, part in b.fills do
			part.Transparency = 0.55 - 0.2 * k
		end
		if now >= b.stateUntil then
			resolveMove(b)
		end
	elseif b.state == "recover" or b.state == "open" then
		if now >= b.stateUntil then
			setState(b, "idle", 0)
		end
	else
		local target, dist = nearest(present, Vector3.new(b.body.Position.X, 0, b.body.Position.Z))
		if not target then
			return
		end
		local move = BossRules.NextMove(def.sequence, b.moveIndex)
		if move == "sweep" and dist > def.sweep.startRangeStuds then
			moveToward(b, target.root.Position, dt)
		else
			local _, nextIndex = BossRules.NextMove(def.sequence, b.moveIndex)
			b.moveIndex = nextIndex
			startMove(b, move, present)
		end
	end
end

------------------------------------------------------------------------------
-- Damage from players, defeat
------------------------------------------------------------------------------

local function die(b: Boss)
	b.engaged = false
	clearTelegraph(b)
	despawnAdds(b)
	setState(b, "dead", 0)
	local position = b.body.Position
	local damageBy: { [number]: number } = {}
	for userId, amount in b.damageBy do
		damageBy[userId] = amount
	end
	local defeat: Defeat = { bossId = b.def.id, runtimeId = b.runtimeId, position = position, maxHp = b.def.maxHp, damageBy = damageBy }
	for _, callback in defeatedListeners do
		task.spawn(callback, defeat)
	end
	network.EmitFx("enemy_death", position, nil, b.runtimeId)
	-- Corpse fades after a few seconds; the next boss comes after respawnSec.
	task.delay(4, function()
		if boss == b and b.model.Parent then
			b.model:Destroy()
		end
	end)
	if autoEngage then
		task.delay(b.def.respawnSec, function()
			if boss == b then
				BossService.Reset()
			end
		end)
	end
end

-- Runtime id of the current boss: how TargetService knows a hit is for it.
function BossService.Owns(enemyId: string): boolean
	return boss ~= nil and boss.runtimeId == enemyId
end

-- Same shape as EnemyService.Damage. Refused while the boss is not in a fight
-- or is already down, so it cannot be worn down before it engages.
function BossService.Damage(enemyId: string, amount: number, attacker: Player): boolean
	local b = boss
	if not b or b.runtimeId ~= enemyId or not b.engaged or b.state == "dead" or amount <= 0 then
		return false
	end
	if members ~= nil and members[attacker] ~= true then
		return false -- not in this fight (late joiner, or out after dying/leaving)
	end
	local newHp, applied = BossRules.ApplyDamage(b.hp, amount, b.state == "open", b.def.openDamageMultiplier)
	if applied <= 0 then
		return false
	end
	b.hp = newHp
	b.damageBy[attacker.UserId] = (b.damageBy[attacker.UserId] or 0) + applied
	b.model:SetAttribute("Hp", newHp)
	b.fill.Size = UDim2.fromScale(newHp / b.def.maxHp, 1)
	if newHp <= 0 then
		die(b)
	end
	return true
end

-- The boss as a hit target while a fight is on (same record as an enemy).
function BossService.GetTargets(): { { id: string, body: BasePart, bodyRadius: number } }
	local b = boss
	if not b or not b.engaged or b.state == "dead" then
		return {}
	end
	return { { id = b.runtimeId, body = b.body, bodyRadius = b.def.bodyRadiusStuds } }
end

function BossService.OnDefeated(callback: (Defeat) -> ())
	table.insert(defeatedListeners, callback)
end

function BossService.SetAutoEngage(on: boolean)
	autoEngage = on
end

function BossService.GetState(): string
	return if boss then boss.state else "none"
end

function BossService.IsEngaged(): boolean
	return boss ~= nil and boss.engaged
end

function BossService.Init(deps: { Network: Network, PlayerState: PlayerState, Enemies: Enemies })
	network = deps.Network
	playerState = deps.PlayerState
	enemies = deps.Enemies
end

function BossService.Start()
	BossService.Reset()
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

return BossService

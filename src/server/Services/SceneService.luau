--!strict
-- Builds the P1 styled-greybox arena under Workspace/SpiritWardPrototype,
-- and since M2-B the regions around it (Scene/Regions: Mistwood, village).
-- Idempotent: only the namespace folder and its own named Atmosphere,
-- Bloom and Grade effects are replaced;
-- nothing else in Workspace or Lighting is cleared.
--
-- Layout inside the namespace folder:
--   Collision/  gameplay geometry (floor, tier, wall, cover, bounds, prop proxies)
--   Decor/      visual-only placeholders (CanCollide/CanQuery/CanTouch off)
--   Markers/    tagged spawn, checkpoint and enemy spawn points
-- Visuals can be swapped later without touching Collision or Markers.
-- VB-01: Decor visuals come from Scene/ShrineCourtyard; the collision proxies
-- for the torii and lanterns stay here unchanged.
--
-- Rebuild in Edit mode from the Studio command bar:
--   require(game.ServerScriptService.Server.Services.SceneService).Build()

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local World = require(ReplicatedStorage.Shared.Definitions.World)
local Regions = require(script.Parent.Parent.Scene.Regions)
local ShrineCourtyard = require(script.Parent.Parent.Scene.ShrineCourtyard)

local NAMESPACE = Prototype.WorldNamespace
local ATMOSPHERE_NAME = NAMESPACE .. "Atmosphere"
local HALF = Prototype.Arena.SizeStuds / 2
local FLOOR_Y = Prototype.Arena.FloorTopY

local Palette = {
	Stone = Color3.fromRGB(96, 98, 112),
	StoneDark = Color3.fromRGB(70, 72, 86),
	Wall = Color3.fromRGB(84, 88, 108),
	Amber = Color3.fromRGB(255, 176, 84),
	Marker = Color3.fromRGB(120, 170, 255),
}

local SceneService = {}

type PartProps = {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	Transparency: number?,
	Shape: ("Block" | "Wedge")?,
}

local function makePart(parent: Instance, props: PartProps): BasePart
	local part: BasePart
	if props.Shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		part = Instance.new("Part")
	end
	part.Name = props.Name
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Anchored = true
	part.Color = props.Color or Palette.Stone
	part.Material = props.Material or Enum.Material.Slate
	part.Transparency = props.Transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function collider(parent: Instance, props: PartProps): BasePart
	local part = makePart(parent, props)
	part.CanCollide = true
	part.CanQuery = true
	return part
end

local function invisibleProxy(parent: Instance, name: string, size: Vector3, cf: CFrame): BasePart
	return collider(parent, {
		Name = name,
		Size = size,
		CFrame = cf,
		Transparency = 1,
	})
end

local function marker(parent: Instance, name: string, position: Vector3, tag: string, idAttr: string, id: string): BasePart
	local part = makePart(parent, {
		Name = name,
		Size = Vector3.new(2, 0.2, 2),
		CFrame = CFrame.new(position),
		Color = Palette.Marker,
		Material = Enum.Material.Neon,
		Transparency = 0.6,
	})
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part:SetAttribute(idAttr, id)
	CollectionService:AddTag(part, tag)
	return part
end

local function onFloor(x: number, height: number, z: number): CFrame
	return CFrame.new(x, FLOOR_Y + height / 2, z)
end

local function buildGround(collision: Instance)
	collider(collision, {
		Name = "Floor",
		Size = Vector3.new(HALF * 2, 1, HALF * 2),
		CFrame = CFrame.new(0, FLOOR_Y - 0.5, 0),
		Color = Palette.Stone,
		Material = Enum.Material.Slate,
	})

	-- Low tier: one raised area with a ramp, used later to test height checks.
	local tierHeight = 5
	collider(collision, {
		Name = "LowTier",
		Size = Vector3.new(20, tierHeight, 16),
		CFrame = onFloor(28, tierHeight, 18),
		Color = Palette.StoneDark,
		Material = Enum.Material.Cobblestone,
	})
	collider(collision, {
		Name = "LowTierRamp",
		Size = Vector3.new(12, tierHeight, 8),
		-- A wedge rises toward its local +Z; turn it so it climbs toward +X onto the tier.
		CFrame = onFloor(14, tierHeight, 18) * CFrame.Angles(0, math.rad(90), 0),
		Color = Palette.StoneDark,
		Material = Enum.Material.Cobblestone,
		Shape = "Wedge",
	})

	collider(collision, {
		Name = "TestWall",
		Size = Vector3.new(24, 10, 1.5),
		CFrame = onFloor(-18, 10, -6),
		Color = Palette.Wall,
		Material = Enum.Material.Brick,
	})

	collider(collision, {
		Name = "Cover",
		Size = Vector3.new(6, 4, 2),
		CFrame = onFloor(10, 4, -16),
		Color = Palette.Wall,
		Material = Enum.Material.Rock,
	})

	-- Invisible bounds so players stay in the arena.
	local h = 30
	invisibleProxy(collision, "BoundNorth", Vector3.new(HALF * 2, h, 1), onFloor(0, h, -HALF - 0.5))
	-- M2-B: the south bound has a gate for the sandō from Mistwood; the two
	-- halves stop at the gate edges (reviewed collision change).
	local gate = World.CourtyardGateHalfWidth
	local southLen = HALF - gate
	invisibleProxy(collision, "BoundSouthWest", Vector3.new(southLen, h, 1), onFloor(-(gate + southLen / 2), h, HALF + 0.5))
	invisibleProxy(collision, "BoundSouthEast", Vector3.new(southLen, h, 1), onFloor(gate + southLen / 2, h, HALF + 0.5))
	invisibleProxy(collision, "BoundWest", Vector3.new(1, h, HALF * 2), onFloor(-HALF - 0.5, h, 0))
	invisibleProxy(collision, "BoundEast", Vector3.new(1, h, HALF * 2), onFloor(HALF + 0.5, h, 0))
end

local function buildTorii(decorFolder: Instance, collision: Instance, origin: CFrame)
	local pillarHeight = 14
	local halfSpan = 7
	ShrineCourtyard.Torii(decorFolder, origin, halfSpan, pillarHeight)
	for _, side in { -1, 1 } do
		local pillarCf = origin * CFrame.new(side * halfSpan, FLOOR_Y + pillarHeight / 2, 0)
		invisibleProxy(collision, "ToriiPillarProxy", Vector3.new(1.6, pillarHeight, 1.6), pillarCf)
	end
end

local function buildLantern(decorFolder: Instance, collision: Instance, x: number, z: number)
	ShrineCourtyard.StoneLantern(decorFolder, x, z)
	invisibleProxy(collision, "LanternProxy", Vector3.new(2, 5.7, 2), onFloor(x, 5.7, z))
end

local function buildDecor(decorFolder: Instance, collision: Instance)
	-- Japanese props sit on the arena edge so they never block the fight space or camera.
	buildTorii(decorFolder, collision, CFrame.new(0, 0, -HALF + 3))
	for _, pos in { { -40, -44 }, { 40, -44 }, { -46, 0 }, { 46, -10 }, { -40, 44 }, { 40, 44 } } do
		buildLantern(decorFolder, collision, pos[1], pos[2])
	end
	ShrineCourtyard.Build(decorFolder)
	ShrineCourtyard.DressCollision(decorFolder, collision)
end

local function buildMarkers(markers: Instance)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.CFrame = CFrame.new(0, FLOOR_Y + 0.1, 38)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Palette.Marker
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.5
	spawn.CanCollide = false
	spawn:SetAttribute("SpawnId", "p1_start")
	spawn.Parent = markers

	local checkpoint = Instance.new("SpawnLocation")
	checkpoint.Name = "Checkpoint"
	checkpoint.Size = Vector3.new(6, 0.2, 6)
	checkpoint.CFrame = CFrame.new(-36, FLOOR_Y + 0.1, 20)
	checkpoint.Anchored = true
	checkpoint.Neutral = true
	checkpoint.Duration = 0
	checkpoint.Color = Palette.Amber
	checkpoint.Material = Enum.Material.Neon
	checkpoint.Transparency = 0.5
	checkpoint.CanCollide = false
	checkpoint:SetAttribute("CheckpointId", "p1_checkpoint")
	CollectionService:AddTag(checkpoint, "Checkpoint")
	checkpoint.Parent = markers

	marker(markers, "EnemySpawn1", Vector3.new(-26, FLOOR_Y + 0.1, -26), "EnemySpawn", "EnemySpawnId", "p1_enemy_1")
	marker(markers, "EnemySpawn2", Vector3.new(22, FLOOR_Y + 0.1, -28), "EnemySpawn", "EnemySpawnId", "p1_enemy_2")
	-- On the low tier, to exercise height checks in P1-B.
	marker(markers, "EnemySpawn3", Vector3.new(30, FLOOR_Y + 5.1, 18), "EnemySpawn", "EnemySpawnId", "p1_enemy_3")
end

-- Replaces one of our own named Lighting children; never touches others.
local function ownLightingChild(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local child = Instance.new(className)
	child.Name = name
	return child
end

-- VB-01 dusk look: warm lantern key (Neon + PointLights in Decor) against a
-- cool indigo fill. The fill is kept bright enough that dark avatar outfits
-- and the katana still read from the combat camera.
local function applyLighting()
	Lighting.ClockTime = 18.4
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(58, 60, 96)
	Lighting.OutdoorAmbient = Color3.fromRGB(104, 110, 156)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 196, 150)
	Lighting.ColorShift_Bottom = Color3.fromRGB(60, 70, 120)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.25

	local atmosphere = ownLightingChild("Atmosphere", ATMOSPHERE_NAME) :: Atmosphere
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(104, 106, 168)
	atmosphere.Decay = Color3.fromRGB(46, 42, 96)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting

	-- High threshold: only Neon (lanterns, combat FX) blooms, not lit stone.
	local bloom = ownLightingChild("BloomEffect", NAMESPACE .. "Bloom") :: BloomEffect
	bloom.Intensity = 0.55
	bloom.Size = 22
	bloom.Threshold = 1.5
	bloom.Parent = Lighting

	local grade = ownLightingChild("ColorCorrectionEffect", NAMESPACE .. "Grade") :: ColorCorrectionEffect
	grade.Brightness = 0.02
	grade.Contrast = 0.1
	grade.Saturation = 0.06
	grade.TintColor = Color3.fromRGB(242, 244, 255)
	grade.Parent = Lighting
end

function SceneService.Build(): Folder
	local existing = workspace:FindFirstChild(NAMESPACE)
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = NAMESPACE
	root:SetAttribute("Placeholder", true)
	root:SetAttribute("BuiltBy", "SceneService")

	local collision = Instance.new("Folder")
	collision.Name = "Collision"
	collision.Parent = root
	local decorFolder = Instance.new("Folder")
	decorFolder.Name = "Decor"
	decorFolder.Parent = root
	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = root

	buildGround(collision)
	buildDecor(decorFolder, collision)
	buildMarkers(markers)
	applyLighting()
	-- M2-B: Mistwood and the village around the courtyard.
	Regions.Build(root)

	root.Parent = workspace
	return root
end

-- New players start in the village (M2-B); the courtyard spawn is a fallback.
function SceneService.GetSpawn(): SpawnLocation?
	local root = workspace:FindFirstChild(NAMESPACE)
	if not root then
		return nil
	end
	for _, name in { "VillageSpawn", "PlayerSpawn" } do
		local found = root:FindFirstChild(name, true)
		if found and found:IsA("SpawnLocation") then
			return found
		end
	end
	return nil
end

function SceneService.Init() end

function SceneService.Start()
	SceneService.Build()
end

return SceneService

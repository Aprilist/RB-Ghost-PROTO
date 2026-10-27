--!strict
-- VB-01 visual benchmark: shrine-courtyard dressing for the P1 arena.
-- Visual only. Every part here is Decor (CanCollide/CanQuery/CanTouch off),
-- so hit checks, dash probes and movement authority never see it. Gameplay
-- geometry, collision proxies and markers stay in SceneService.
--
-- Camera rule: the default camera does not pop in front of non-colliding
-- parts, so anything taller than the low wall sits at least
-- Camera.MaxZoomStuds + margin outside the arena bounds. Inside that band
-- only flat ground dressing and low garden edges are allowed.
--
-- Layout is deterministic (fixed Random seed) so every rebuild is identical.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local World = require(ReplicatedStorage.Shared.Definitions.World)

local HALF = Prototype.Arena.SizeStuds / 2
local FLOOR_Y = Prototype.Arena.FloorTopY
local CAMERA_CLEAR = Prototype.Camera.MaxZoomStuds + 4
-- Tall props (bamboo, trees, buildings) start this far from the arena centre.
local TALL_RING = HALF + CAMERA_CLEAR
-- Low garden edge: wall and shrubs between the bounds and the tall ring.
local LOW_EDGE_MAX_HEIGHT = 3.5
local SEED = 20261027
-- M2-B: the sandō leaves through a gate in the south wall to Mistwood. Gaps
-- below still draw from the Random stream so every other piece keeps the
-- placement the Director approved in VB-01.
local GATE_HALF = World.CourtyardGateHalfWidth
local BAMBOO_CORRIDOR_HALF = World.Mistwood.corridorHalfWidth + 6

local Palette = {
	Gravel = Color3.fromRGB(92, 94, 110),
	PathStone = Color3.fromRGB(128, 126, 134),
	Curb = Color3.fromRGB(62, 62, 74),
	OuterGround = Color3.fromRGB(46, 58, 54),
	Moss = Color3.fromRGB(76, 98, 66),
	Shrub = Color3.fromRGB(40, 64, 50),
	StoneLantern = Color3.fromRGB(84, 86, 98),
	WallStone = Color3.fromRGB(74, 76, 90),
	WallCap = Color3.fromRGB(52, 50, 60),
	ToriiRed = Color3.fromRGB(158, 52, 44),
	ToriiBlack = Color3.fromRGB(34, 30, 32),
	PlaqueGold = Color3.fromRGB(196, 164, 92),
	Rope = Color3.fromRGB(196, 170, 112),
	Paper = Color3.fromRGB(238, 234, 222),
	Amber = Color3.fromRGB(255, 176, 84),
	AmberDeep = Color3.fromRGB(232, 132, 58),
	Bamboo = Color3.fromRGB(88, 120, 78),
	BambooDark = Color3.fromRGB(60, 88, 62),
	BambooLeaf = Color3.fromRGB(56, 92, 60),
	Cedar = Color3.fromRGB(32, 50, 44),
	CedarTrunk = Color3.fromRGB(70, 48, 40),
	HallWood = Color3.fromRGB(78, 46, 40),
	HallPlaster = Color3.fromRGB(206, 200, 186),
	HallRoof = Color3.fromRGB(44, 52, 60),
	Mountain = Color3.fromRGB(38, 40, 72),
	MountainFar = Color3.fromRGB(48, 50, 92),
}

-- "Ball" is an ellipsoid filling Size (sphere mesh); "Cylinder" runs along local X.
type Shape = "Block" | "Wedge" | "Cylinder" | "Ball"

local ShrineCourtyard = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Shape?
): BasePart
	local p: BasePart
	if shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		local block = Instance.new("Part")
		if shape == "Cylinder" then
			block.Shape = Enum.PartType.Cylinder
		elseif shape == "Ball" then
			-- A Ball part is forced uniform; a sphere mesh fills the box instead,
			-- so shrubs and leaf clumps can be squashed ellipsoids.
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = block
		end
		p = block
	end
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("Placeholder", true)
	p.Parent = parent
	return p
end

-- Upright cylinder: Roblox cylinders run along local X, so tip it onto Y.
local function column(parent: Instance, name: string, height: number, diameter: number, base: Vector3, color: Color3, material: Enum.Material): BasePart
	return part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		"Cylinder"
	)
end

-- Two boxes 45° apart read as an octagon from the combat camera.
local function octagon(parent: Instance, name: string, width: number, height: number, centre: Vector3, color: Color3, material: Enum.Material)
	local cf = CFrame.new(centre)
	part(parent, name, Vector3.new(width, height, width), cf, color, material)
	part(parent, name, Vector3.new(width, height, width) * Vector3.new(0.92, 1, 0.92), cf * CFrame.Angles(0, math.rad(45), 0), color, material)
end

local function glow(holder: BasePart, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = Palette.Amber
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = holder
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function jitter(rng: Random, color: Color3, amount: number): Color3
	local k = 1 + rng:NextNumber(-amount, amount)
	return Color3.new(math.clamp(color.R * k, 0, 1), math.clamp(color.G * k, 0, 1), math.clamp(color.B * k, 0, 1))
end

------------------------------------------------------------------------------
-- Landmarks rebuilt in place of the P1 greybox (SceneService keeps the proxies)
------------------------------------------------------------------------------

-- Myōjin-style torii. Pillar centres and height match ToriiPillarProxy.
function ShrineCourtyard.Torii(parent: Instance, origin: CFrame, pillarHalfSpan: number, pillarHeight: number)
	local m = model(parent, "Torii")
	local y = FLOOR_Y
	local function at(x: number, py: number, z: number): CFrame
		return origin * CFrame.new(x, py, z)
	end

	for _, side in { -1, 1 } do
		local x = side * pillarHalfSpan
		local base = at(x, y, 0).Position
		column(m, "Hashira", pillarHeight, 1.6, base, Palette.ToriiRed, Enum.Material.Wood)
		column(m, "Kamaki", 1.3, 2.1, base, Palette.ToriiBlack, Enum.Material.Wood)
		column(m, "Daiishi", 0.3, 2.6, base - Vector3.new(0, 0.05, 0), Palette.StoneLantern, Enum.Material.Slate)
	end

	part(m, "Nuki", Vector3.new(pillarHalfSpan * 2 + 4, 0.9, 0.8), at(0, y + pillarHeight - 3, 0), Palette.ToriiRed, Enum.Material.Wood)
	part(m, "Gakuzuka", Vector3.new(0.8, 1.9, 0.7), at(0, y + pillarHeight - 1.6, 0), Palette.ToriiRed, Enum.Material.Wood)
	-- Plaque faces the courtyard (+Z of origin) so it reads from spawn.
	part(m, "Gaku", Vector3.new(2.2, 2.8, 0.3), at(0, y + pillarHeight - 1.4, 0.5), Palette.ToriiBlack, Enum.Material.Wood)
	part(m, "GakuInset", Vector3.new(1.6, 2.2, 0.06), at(0, y + pillarHeight - 1.4, 0.68), Palette.PlaqueGold, Enum.Material.Metal)
	part(m, "Shimaki", Vector3.new(pillarHalfSpan * 2 + 5, 0.8, 1.5), at(0, y + pillarHeight - 0.2, 0), Palette.ToriiRed, Enum.Material.Wood)
	part(m, "Kasagi", Vector3.new(pillarHalfSpan * 2 + 6, 1.1, 2.3), at(0, y + pillarHeight + 0.75, 0), Palette.ToriiBlack, Enum.Material.Wood)
	-- Upturned ends: a wedge on each end rising outward (wedges rise toward local +Z).
	local kasagiTop = y + pillarHeight + 1.3
	local tipX = pillarHalfSpan + 3
	for _, side in { -1, 1 } do
		part(
			m,
			"Sorimashi",
			Vector3.new(2.3, 0.9, 3),
			at(side * (tipX - 1.5), kasagiTop + 0.45, 0) * CFrame.Angles(0, math.rad(90 * side), 0),
			Palette.ToriiBlack,
			Enum.Material.Wood,
			"Wedge"
		)
	end

	-- Shimenawa rope with shide paper, hung between the pillars above head height.
	local ropeY = y + pillarHeight - 4.2
	local inner = pillarHalfSpan * 2 - 1.6
	part(m, "Shimenawa", Vector3.new(inner, 0.75, 0.75), at(0, ropeY, 0.1), Palette.Rope, Enum.Material.Fabric, "Cylinder")
	for _, x in { -pillarHalfSpan * 0.55, 0, pillarHalfSpan * 0.55 } do
		part(m, "Shide", Vector3.new(0.5, 0.7, 0.05), at(x, ropeY - 0.75, 0.15), Palette.Paper, Enum.Material.SmoothPlastic)
		part(m, "Shide", Vector3.new(0.5, 0.7, 0.05), at(x + 0.15, ropeY - 1.35, 0.15), Palette.Paper, Enum.Material.SmoothPlastic)
	end
end

-- Stone tōrō. Footprint 2×2 and total height 5.7 match LanternProxy.
function ShrineCourtyard.StoneLantern(parent: Instance, x: number, z: number, rng: Random?)
	local m = model(parent, "StoneLantern")
	local stone = if rng then jitter(rng, Palette.StoneLantern, 0.06) else Palette.StoneLantern
	local function p(height: number): Vector3
		return Vector3.new(x, FLOOR_Y + height, z)
	end

	octagon(m, "Kiso", 2, 0.5, p(0.25), stone, Enum.Material.Slate)
	column(m, "Sao", 2.4, 0.9, p(0.5), stone, Enum.Material.Slate)
	octagon(m, "Chudai", 1.9, 0.45, p(3.12), stone, Enum.Material.Slate)

	local fire = part(m, "Hibukuro", Vector3.new(1.05, 1.2, 1.05), CFrame.new(p(3.95)), Palette.Amber, Enum.Material.Neon)
	glow(fire, 1.8, 16)
	for _, c in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		part(m, "Frame", Vector3.new(0.32, 1.2, 0.32), CFrame.new(p(3.95) + Vector3.new(c[1] * 0.55, 0, c[2] * 0.55)), stone, Enum.Material.Slate)
	end

	octagon(m, "Kasa", 2.6, 0.35, p(4.72), stone, Enum.Material.Slate)
	octagon(m, "KasaTop", 1.6, 0.3, p(5.05), stone, Enum.Material.Slate)
	part(m, "Moss", Vector3.new(1.5, 0.08, 1.1), CFrame.new(p(4.93) + Vector3.new(0.3, 0, -0.4)), Palette.Moss, Enum.Material.Grass)
	part(m, "Hoju", Vector3.new(0.55, 0.55, 0.55), CFrame.new(p(5.42)), stone, Enum.Material.Slate, "Ball")
end

------------------------------------------------------------------------------
-- Ground: gravel overlay, flagstone sandō, stepping stones, outer ground
------------------------------------------------------------------------------

-- Flat dressing just above the floor top. Feet sink by at most this much.
local OVERLAY_TOP = 0.03
local PATH_TOP = 0.07

local function slab(parent: Instance, name: string, sizeXZ: Vector2, top: number, x: number, z: number, color: Color3, material: Enum.Material, yaw: number?): BasePart
	local thickness = 0.2
	local cf = CFrame.new(x, FLOOR_Y + top - thickness / 2, z)
	if yaw then
		cf *= CFrame.Angles(0, yaw, 0)
	end
	return part(parent, name, Vector3.new(sizeXZ.X, thickness, sizeXZ.Y), cf, color, material)
end

-- Rows of irregular flagstones filling [x0, x1] × [z0, z1].
local function flagstones(parent: Instance, rng: Random, x0: number, x1: number, z0: number, z1: number)
	local gap = 0.14
	local z = z0
	while z < z1 - 0.5 do
		local depth = math.min(rng:NextNumber(1.6, 2.4), z1 - z)
		local x = x0
		while x < x1 - 0.5 do
			local width = math.min(rng:NextNumber(1.5, 3.1), x1 - x)
			if x1 - (x + width) < 0.9 then
				width = x1 - x
			end
			slab(
				parent,
				"Flagstone",
				Vector2.new(width - gap, depth - gap),
				PATH_TOP,
				x + width / 2,
				z + depth / 2,
				jitter(rng, Palette.PathStone, 0.08),
				Enum.Material.Slate
			)
			x += width
		end
		z += depth
	end
end

local function buildGround(parent: Instance, rng: Random)
	local ground = folder(parent, "Ground")

	-- Outer ground hides the void past the arena; its top sits under the floor top.
	part(ground, "OuterGround", Vector3.new(520, 2, 520), CFrame.new(0, FLOOR_Y - 1.1, 0), Palette.OuterGround, Enum.Material.Grass)
	slab(ground, "Gravel", Vector2.new(HALF * 2, HALF * 2), OVERLAY_TOP, 0, 0, Palette.Gravel, Enum.Material.Pebble)

	-- Main sandō: spawn (south) straight through the torii to the hall (north).
	local pathHalf = 3
	local pathFolder = folder(ground, "Sando")
	flagstones(pathFolder, rng, -pathHalf, pathHalf, -(TALL_RING + 6), HALF - 2)
	for _, side in { -1, 1 } do
		local length = HALF - 2 + TALL_RING + 6
		slab(pathFolder, "Curb", Vector2.new(0.45, length), PATH_TOP - 0.01, side * (pathHalf + 0.25), (HALF - 2 - TALL_RING - 6) / 2, Palette.Curb, Enum.Material.Slate)
	end
	-- Paved apron in front of the torii where the path meets the gate.
	flagstones(pathFolder, rng, -10, -pathHalf - 0.5, -HALF + 0.5, -HALF + 6)
	flagstones(pathFolder, rng, pathHalf + 0.5, 10, -HALF + 0.5, -HALF + 6)

	-- Stepping stones: sandō → checkpoint (west) and sandō → ramp (east).
	local stones = folder(ground, "Tobiishi")
	local function steppingLine(fromX: number, toX: number, z: number)
		local dir = if toX > fromX then 1 else -1
		local x = fromX
		while (toX - x) * dir > 1 do
			local d = rng:NextNumber(1.8, 2.4)
			part(
				stones,
				"Tobiishi",
				Vector3.new(0.2, d, d * rng:NextNumber(0.8, 1)),
				CFrame.new(x, FLOOR_Y + PATH_TOP - 0.1, z + rng:NextNumber(-0.5, 0.5)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(90)),
				jitter(rng, Palette.PathStone, 0.1),
				Enum.Material.Slate,
				"Cylinder"
			)
			x += dir * rng:NextNumber(2.7, 3.2)
		end
	end
	steppingLine(-pathHalf - 1.5, -32.5, 20)
	steppingLine(pathHalf + 1.5, 9.5, 18)

	-- Moss patches in the gravel at the arena corners, away from the paths.
	for _, c in { { -42, -36 }, { 42, -32 }, { -44, 32 }, { 44, 34 }, { -14, 44 }, { 16, 44 } } do
		for _ = 1, 3 do
			slab(
				ground,
				"MossPatch",
				Vector2.new(rng:NextNumber(3, 6), rng:NextNumber(2.5, 5)),
				OVERLAY_TOP + 0.015,
				c[1] + rng:NextNumber(-3, 3),
				c[2] + rng:NextNumber(-3, 3),
				jitter(rng, Palette.Moss, 0.1),
				Enum.Material.Grass,
				rng:NextNumber(0, math.pi)
			)
		end
	end
end

------------------------------------------------------------------------------
-- Low garden edge (between bounds and the tall ring)
------------------------------------------------------------------------------

local function buildEdge(parent: Instance, rng: Random)
	local edge = folder(parent, "GardenEdge")
	local wallOffset = HALF + 3.5
	local wallHeight = 2.2
	local segment = 6

	-- Stone wall on west, east and south; north stays open to the hall.
	-- `gap` leaves |along| < gap open (the south gate, M2-B).
	local function wallRun(fixed: number, alongX: boolean, from: number, to: number, gap: number?)
		local a = from
		while a < to - 0.01 do
			local len = math.min(segment, to - a)
			local mid = a + len / 2
			local pos = if alongX then Vector3.new(mid, 0, fixed) else Vector3.new(fixed, 0, mid)
			local size = if alongX then Vector3.new(len - 0.1, wallHeight, 1.3) else Vector3.new(1.3, wallHeight, len - 0.1)
			local capSize = if alongX then Vector3.new(len, 0.35, 1.7) else Vector3.new(1.7, 0.35, len)
			local color = jitter(rng, Palette.WallStone, 0.07)
			if not gap or a >= gap or a + len <= -gap then
				part(edge, "Wall", size, CFrame.new(pos.X, FLOOR_Y + wallHeight / 2, pos.Z), color, Enum.Material.Cobblestone)
				part(edge, "WallCap", capSize, CFrame.new(pos.X, FLOOR_Y + wallHeight + 0.17, pos.Z), Palette.WallCap, Enum.Material.Slate)
			else
				-- Segment crosses the gate: keep only the pieces outside it (along X).
				for _, piece in { { a, -gap }, { gap, a + len } } do
					local lo, hi = piece[1], piece[2]
					if hi - lo > 0.2 then
						local m = (lo + hi) / 2
						part(edge, "Wall", Vector3.new(hi - lo - 0.1, wallHeight, 1.3), CFrame.new(m, FLOOR_Y + wallHeight / 2, fixed), color, Enum.Material.Cobblestone)
						part(edge, "WallCap", Vector3.new(hi - lo, 0.35, 1.7), CFrame.new(m, FLOOR_Y + wallHeight + 0.17, fixed), Palette.WallCap, Enum.Material.Slate)
					end
				end
			end
			a += len
		end
	end
	wallRun(-wallOffset, false, -wallOffset, wallOffset)
	wallRun(wallOffset, false, -wallOffset, wallOffset)
	wallRun(wallOffset, true, -wallOffset, wallOffset, GATE_HALF)
	-- Gate posts where the south wall now stops.
	for _, side in { -1, 1 } do
		local x = side * (GATE_HALF + 0.6)
		-- Stays under LowEdgeMaxHeight: this is inside the camera band.
		part(edge, "GatePost", Vector3.new(1.6, wallHeight + 0.6, 1.8), CFrame.new(x, FLOOR_Y + (wallHeight + 0.6) / 2, wallOffset), Palette.WallStone, Enum.Material.Cobblestone)
		part(edge, "GatePostCap", Vector3.new(2, 0.4, 2.2), CFrame.new(x, FLOOR_Y + wallHeight + 0.8, wallOffset), Palette.WallCap, Enum.Material.Slate)
	end

	-- Small amber lamps on the wall cap give the edge a warm rhythm.
	-- Only every third lamp carries a light to keep mobile cost down.
	local lampIndex = 0
	local function lamp(x: number, z: number)
		lampIndex += 1
		local p = part(edge, "WallLamp", Vector3.new(0.6, 0.6, 0.6), CFrame.new(x, FLOOR_Y + wallHeight + 0.65, z), Palette.AmberDeep, Enum.Material.Neon)
		if lampIndex % 3 == 0 then
			glow(p, 1, 10)
		end
	end
	for a = -HALF + 8, HALF - 8, 14 do
		lamp(-wallOffset, a)
		lamp(wallOffset, a)
		if math.abs(a) > GATE_HALF then
			lamp(a, wallOffset)
		else
			lampIndex += 1 -- keep the light rhythm of the other lamps
		end
	end

	-- Low shrubs (clipped azalea) between the bounds and the wall.
	local function shrub(x: number, z: number)
		local d = rng:NextNumber(1.8, 2.6)
		part(edge, "Shrub", Vector3.new(d * 1.3, d * 0.8, d * 1.1), CFrame.new(x, FLOOR_Y + d * 0.35, z), jitter(rng, Palette.Shrub, 0.12), Enum.Material.Grass, "Ball")
	end
	for a = -HALF + 3, HALF - 3, 5 do
		shrub(-HALF - 1.6, a + rng:NextNumber(-1, 1))
		shrub(HALF + 1.6, a + rng:NextNumber(-1, 1))
		if math.abs(a) > 5 then
			shrub(a + rng:NextNumber(-1, 1), HALF + 1.6)
		end
	end

	-- North: low red fence (mizugaki) with a gap for the sandō, then the lantern
	-- avenue that leads the eye to the hall.
	for _, side in { -1, 1 } do
		local x0, x1 = side * 10, side * (wallOffset + 0.6)
		local lo, hi = math.min(x0, x1), math.max(x0, x1)
		local z = -wallOffset
		part(edge, "FenceRail", Vector3.new(hi - lo, 0.35, 0.35), CFrame.new((lo + hi) / 2, FLOOR_Y + 2.1, z), Palette.ToriiRed, Enum.Material.Wood)
		part(edge, "FenceRail", Vector3.new(hi - lo, 0.3, 0.3), CFrame.new((lo + hi) / 2, FLOOR_Y + 1, z), Palette.ToriiRed, Enum.Material.Wood)
		for x = lo, hi, 2 do
			part(edge, "FencePost", Vector3.new(0.35, 2.6, 0.35), CFrame.new(x, FLOOR_Y + 1.3, z), Palette.ToriiRed, Enum.Material.Wood)
		end
	end
	for _, z in { -HALF - 10, -HALF - 20, -HALF - 30 } do
		ShrineCourtyard.StoneLantern(edge, -5.5, z, rng)
		ShrineCourtyard.StoneLantern(edge, 5.5, z, rng)
	end
end

------------------------------------------------------------------------------
-- Tall backdrop (outside the camera band)
------------------------------------------------------------------------------

local function bamboo(parent: Instance, rng: Random, x: number, z: number)
	local height = rng:NextNumber(22, 38)
	local d = rng:NextNumber(0.7, 1.2)
	local lean = CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06))
	local base = CFrame.new(x, FLOOR_Y, z) * lean
	part(
		parent,
		"Culm",
		Vector3.new(height, d, d),
		base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		jitter(rng, if rng:NextNumber() < 0.3 then Palette.BambooDark else Palette.Bamboo, 0.08),
		Enum.Material.SmoothPlastic,
		"Cylinder"
	)
	-- Foliage only in the top third, so the grove reads as tall culms with a canopy.
	for i = 1, 3 do
		local y = height * (0.62 + 0.11 * i)
		part(
			parent,
			"Leaves",
			Vector3.new(rng:NextNumber(4, 6.5), rng:NextNumber(2.6, 4), rng:NextNumber(3.5, 5.5)),
			base * CFrame.new(rng:NextNumber(-1.5, 1.5), y, rng:NextNumber(-1.5, 1.5)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
			jitter(rng, Palette.BambooLeaf, 0.12),
			Enum.Material.Grass,
			"Ball"
		)
	end
end

local function cedar(parent: Instance, rng: Random, x: number, z: number, scale: number)
	local m = model(parent, "Sugi")
	local trunkH = 10 * scale
	column(m, "Trunk", trunkH, 2.2 * scale, Vector3.new(x, FLOOR_Y, z), Palette.CedarTrunk, Enum.Material.Wood)
	local tiers = { { 11, 7 }, { 8.5, 6.5 }, { 6, 6 }, { 3.2, 5 } }
	local y = trunkH * 0.75
	local color = jitter(rng, Palette.Cedar, 0.1)
	for _, t in tiers do
		column(m, "Crown", t[2] * scale, t[1] * scale, Vector3.new(x, FLOOR_Y + y, z), color, Enum.Material.Grass)
		y += t[2] * scale * 0.72
	end
end

local function buildBackdrop(parent: Instance, rng: Random)
	local back = folder(parent, "Backdrop")

	-- Bamboo groves on west, east and south, starting at the tall ring.
	local grove = folder(back, "Bamboo")
	local outer = TALL_RING + 26
	for _ = 1, 150 do
		local side = rng:NextInteger(1, 3)
		local depth = rng:NextNumber(TALL_RING + 10, outer)
		local along = rng:NextNumber(-outer, outer)
		if side == 1 then
			bamboo(grove, rng, -depth, along)
		elseif side == 2 then
			bamboo(grove, rng, depth, along)
		else
			-- Keep a corridor open for the Mistwood path (M2-B).
			if math.abs(along) < BAMBOO_CORRIDOR_HALF then
				along = (if along < 0 then -1 else 1) * (BAMBOO_CORRIDOR_HALF + math.abs(along))
			end
			bamboo(grove, rng, along, depth)
		end
	end

	-- Main hall (honden) at the end of the sandō, behind the torii.
	local hall = model(back, "Honden")
	local hz = -(TALL_RING + 16)
	local width, depth, floorH, bodyH = 30, 16, 3, 9
	part(hall, "Kidan", Vector3.new(width + 4, floorH, depth + 4), CFrame.new(0, FLOOR_Y + floorH / 2, hz), Palette.WallStone, Enum.Material.Cobblestone)
	for i = 1, 5 do
		local stepH = floorH * i / 5
		part(hall, "Step", Vector3.new(8, stepH, 1.1), CFrame.new(0, FLOOR_Y + stepH / 2, hz + depth / 2 + 2 + (5 - i + 0.5) * 1.1), Palette.WallStone, Enum.Material.Slate)
	end
	local bodyY = FLOOR_Y + floorH
	part(hall, "Body", Vector3.new(width - 2, bodyH, depth - 2), CFrame.new(0, bodyY + bodyH / 2, hz), Palette.HallPlaster, Enum.Material.Plaster)
	for i = 0, 5 do
		local x = -width / 2 + 1 + i * (width - 2) / 5
		column(hall, "Pillar", bodyH, 1.1, Vector3.new(x, bodyY, hz + depth / 2 - 0.6), Palette.ToriiRed, Enum.Material.Wood)
		part(hall, "Lattice", Vector3.new(0.25, bodyH - 1, 0.2), CFrame.new(x + (width - 2) / 10, bodyY + bodyH / 2, hz + depth / 2 - 0.95), Palette.HallWood, Enum.Material.Wood)
	end
	part(hall, "Beam", Vector3.new(width, 0.9, 1), CFrame.new(0, bodyY + bodyH - 0.4, hz + depth / 2 - 0.6), Palette.HallWood, Enum.Material.Wood)
	-- Gabled roof: two wedges meeting at a ridge along X, deep eaves.
	local roofH, eave = 8, 4
	local roofY = bodyY + bodyH + roofH / 2
	local halfD = depth / 2 + eave
	part(hall, "RoofFront", Vector3.new(width + eave * 2, roofH, halfD), CFrame.new(0, roofY, hz + halfD / 2) * CFrame.Angles(0, math.pi, 0), Palette.HallRoof, Enum.Material.Slate, "Wedge")
	part(hall, "RoofBack", Vector3.new(width + eave * 2, roofH, halfD), CFrame.new(0, roofY, hz - halfD / 2), Palette.HallRoof, Enum.Material.Slate, "Wedge")
	part(hall, "Ridge", Vector3.new(width + eave * 2 + 1, 1, 1.4), CFrame.new(0, roofY + roofH / 2 + 0.3, hz), Palette.ToriiBlack, Enum.Material.Wood)
	for i = -2, 2 do
		part(hall, "Katsuogi", Vector3.new(3, 0.9, 0.9), CFrame.new(i * 6, roofY + roofH / 2 + 1.2, hz) * CFrame.Angles(0, math.rad(90), 0), Palette.PlaqueGold, Enum.Material.Wood, "Cylinder")
	end
	for _, side in { -1, 1 } do
		local x = side * (width / 2 + eave)
		for _, lean in { -1, 1 } do
			part(hall, "Chigi", Vector3.new(0.4, 5, 0.8), CFrame.new(x, roofY + roofH / 2 + 1.4, hz) * CFrame.Angles(math.rad(35 * lean), 0, 0), Palette.ToriiBlack, Enum.Material.Wood)
		end
	end
	-- Hanging paper lanterns under the front eave: the warm focal point of the shot.
	for _, x in { -9, -3, 3, 9 } do
		local lantern = part(hall, "Chochin", Vector3.new(2.2, 1.6, 1.6), CFrame.new(x, bodyY + bodyH - 2.2, hz + depth / 2 + 1.2) * CFrame.Angles(0, 0, math.rad(90)), Palette.Amber, Enum.Material.Neon, "Cylinder")
		if math.abs(x) == 3 then
			glow(lantern, 2, 22)
		end
	end
	part(hall, "Shimenawa", Vector3.new(14, 1.1, 1.1), CFrame.new(0, bodyY + bodyH - 1.1, hz + depth / 2 + 0.2), Palette.Rope, Enum.Material.Fabric, "Cylinder")

	-- Cedar grove framing the hall.
	local trees = folder(back, "Cedars")
	for i = 1, 14 do
		local side = if i % 2 == 0 then 1 else -1
		local x = side * rng:NextNumber(24, 60)
		local z = hz - rng:NextNumber(-6, 34)
		cedar(trees, rng, x, z, rng:NextNumber(1.1, 1.6))
	end

	-- Distant rounded peaks: half-sunk ellipsoids, hazed by the atmosphere
	-- into soft silhouettes behind the hall.
	local hills = folder(back, "Mountains")
	local function peak(x: number, z: number, w: number, h: number, color: Color3)
		part(hills, "Peak", Vector3.new(w, h * 2, w * 0.7), CFrame.new(x, FLOOR_Y - 4, z), color, Enum.Material.Slate, "Ball")
	end
	peak(-150, -340, 240, 110, Palette.MountainFar)
	peak(30, -380, 300, 140, Palette.MountainFar)
	peak(200, -330, 220, 100, Palette.MountainFar)
	peak(-40, -260, 160, 55, Palette.Mountain)
	peak(110, -250, 140, 48, Palette.Mountain)
	peak(-290, -120, 200, 90, Palette.MountainFar)
	peak(300, -100, 200, 95, Palette.MountainFar)
end

------------------------------------------------------------------------------
-- Dressing for visible gameplay geometry (test wall, low tier, ramp, cover)
------------------------------------------------------------------------------

-- Each piece is placed from the collider's own CFrame/Size and only wraps it a
-- few hundredths of a stud outside, so the collider still drives camera
-- occlusion, hits and movement. Tagged with attribute Dresses = collider name.
function ShrineCourtyard.DressCollision(decorFolder: Instance, collision: Instance)
	local dress = folder(decorFolder, "Dressing")
	local function collider(name: string): BasePart?
		local found = collision:FindFirstChild(name)
		return if found and found:IsA("BasePart") then found else nil
	end
	local function dressPart(target: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Shape?): BasePart
		local p = part(dress, name, size, target.CFrame * offset, color, material, shape)
		p:SetAttribute("Dresses", target.Name)
		return p
	end

	-- Test wall as a tsuiji-bei: plaster body, stone footing, timber posts, tiled cap.
	local wall = collider("TestWall")
	if wall then
		local s = wall.Size
		local footH = 1.4
		dressPart(wall, "Plaster", s + Vector3.new(0.08, 0, 0.08), CFrame.new(), Palette.HallPlaster, Enum.Material.Plaster)
		dressPart(wall, "Footing", Vector3.new(s.X + 0.2, footH, s.Z + 0.2), CFrame.new(0, -s.Y / 2 + footH / 2, 0), Palette.WallStone, Enum.Material.Cobblestone)
		for x = -s.X / 2 + 1, s.X / 2 - 0.9, 4 do
			for _, face in { -1, 1 } do
				dressPart(wall, "Post", Vector3.new(0.35, s.Y - footH, 0.08), CFrame.new(x, footH / 2, face * (s.Z / 2 + 0.06)), Palette.HallWood, Enum.Material.Wood)
			end
		end
		local capW, capD = s.X + 1.2, s.Z + 1.8
		dressPart(wall, "Cap", Vector3.new(capW, 0.35, capD), CFrame.new(0, s.Y / 2 + 0.17, 0), Palette.HallRoof, Enum.Material.Slate)
		local q = capD / 4
		dressPart(wall, "Tiles", Vector3.new(capW, 0.8, capD / 2), CFrame.new(0, s.Y / 2 + 0.75, q) * CFrame.Angles(0, math.pi, 0), Palette.HallRoof, Enum.Material.Slate, "Wedge")
		dressPart(wall, "Tiles", Vector3.new(capW, 0.8, capD / 2), CFrame.new(0, s.Y / 2 + 0.75, -q), Palette.HallRoof, Enum.Material.Slate, "Wedge")
		dressPart(wall, "Ridge", Vector3.new(capW + 0.2, 0.4, 0.4), CFrame.new(0, s.Y / 2 + 1.2, 0), Palette.ToriiBlack, Enum.Material.Slate, "Cylinder")
	end

	-- Low tier as a dressed-stone terrace with a mossy coping.
	local tier = collider("LowTier")
	if tier then
		local s = tier.Size
		dressPart(tier, "Facing", s + Vector3.new(0.1, 0, 0.1), CFrame.new(), Palette.WallStone, Enum.Material.Cobblestone)
		dressPart(tier, "Top", Vector3.new(s.X - 1.2, 0.1, s.Z - 1.2), CFrame.new(0, s.Y / 2 + 0.03, 0), Palette.PathStone, Enum.Material.Slate)
		for _, edge in { { 0, 1, s.X + 0.3, 0.7 }, { 0, -1, s.X + 0.3, 0.7 }, { 1, 0, 0.7, s.Z - 1.1 }, { -1, 0, 0.7, s.Z - 1.1 } } do
			dressPart(
				tier,
				"Coping",
				Vector3.new(edge[3], 0.14, edge[4]),
				CFrame.new(edge[1] * (s.X / 2 - 0.3), s.Y / 2 + 0.05, edge[2] * (s.Z / 2 - 0.3)),
				Palette.WallCap,
				Enum.Material.Slate
			)
		end
	end

	-- Ramp: same wedge, stone dressed to match the terrace.
	local ramp = collider("LowTierRamp")
	if ramp then
		dressPart(ramp, "Slope", ramp.Size + Vector3.new(0.08, 0.04, 0.04), CFrame.new(), Palette.PathStone, Enum.Material.Slate, "Wedge")
	end

	-- Cover as a weathered stone stele on a plinth.
	local cover = collider("Cover")
	if cover then
		local s = cover.Size
		dressPart(cover, "Stele", s + Vector3.new(0.08, 0, 0.08), CFrame.new(), Palette.StoneLantern, Enum.Material.Rock)
		dressPart(cover, "Crown", Vector3.new(s.X + 0.4, 0.3, s.Z + 0.4), CFrame.new(0, s.Y / 2 + 0.15, 0), Palette.WallCap, Enum.Material.Slate)
		dressPart(cover, "Moss", Vector3.new(s.X * 0.6, 0.08, s.Z + 0.1), CFrame.new(-0.6, s.Y / 2 + 0.33, 0), Palette.Moss, Enum.Material.Grass)
	end
end

------------------------------------------------------------------------------

-- Builds everything except the torii and the six arena lanterns, which
-- SceneService places alongside their collision proxies.
function ShrineCourtyard.Build(decorFolder: Instance)
	local rng = Random.new(SEED)
	buildGround(decorFolder, rng)
	buildEdge(decorFolder, rng)
	buildBackdrop(decorFolder, rng)
end

-- Exposed for SceneLayoutTest so the camera band rule has one source.
ShrineCourtyard.TallRingStuds = TALL_RING
ShrineCourtyard.LowEdgeMaxHeight = LOW_EDGE_MAX_HEIGHT

return ShrineCourtyard

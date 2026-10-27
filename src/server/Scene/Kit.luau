--!strict
-- Shared builders for the M2-B regions (village, mistwood). Every region has
-- two part folders: Collision (solid, blocks movement, sight and the camera)
-- and Decor (CanCollide/CanQuery/CanTouch off). Builders take the folder to
-- put each piece in, so a house can be solid where players touch it and
-- decor everywhere else. Visual only otherwise: no gameplay numbers here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)

local FLOOR_Y = Prototype.Arena.FloorTopY

export type Shape = "Block" | "Wedge" | "Cylinder" | "Ball"
export type Folders = { solid: Instance, decor: Instance }

local Kit = {}

Kit.FloorY = FLOOR_Y

-- Tag on parts that switch to glowing Neon at night (lit windows, lanterns).
Kit.NightGlowTag = "SpiritWardNightGlow"
-- Tag on lights that only shine at night.
Kit.NightLightTag = "SpiritWardNightLight"

Kit.Palette = {
	-- shared
	Stone = Color3.fromRGB(116, 114, 120),
	StoneDark = Color3.fromRGB(84, 84, 92),
	PathDirt = Color3.fromRGB(122, 100, 76),
	PathStone = Color3.fromRGB(136, 132, 128),
	Amber = Color3.fromRGB(255, 176, 84),
	Paper = Color3.fromRGB(236, 222, 186),
	PaperLit = Color3.fromRGB(255, 196, 120),
	Rope = Color3.fromRGB(196, 170, 112),
	ToriiRed = Color3.fromRGB(158, 52, 44),
	Ink = Color3.fromRGB(34, 30, 32),
	-- gassho houses
	Thatch = Color3.fromRGB(150, 118, 72),
	ThatchDark = Color3.fromRGB(118, 90, 56),
	HouseWood = Color3.fromRGB(72, 50, 40),
	HouseWoodDark = Color3.fromRGB(48, 34, 30),
	Plaster = Color3.fromRGB(214, 206, 188),
	-- autumn (the only season with built visuals in M2-B)
	Grass = Color3.fromRGB(118, 112, 66),
	GrassDark = Color3.fromRGB(86, 90, 56),
	Stubble = Color3.fromRGB(176, 150, 88),
	PaddyRidge = Color3.fromRGB(104, 92, 60),
	MapleRed = Color3.fromRGB(196, 62, 40),
	MapleOrange = Color3.fromRGB(226, 120, 44),
	MapleYellow = Color3.fromRGB(232, 182, 70),
	Cedar = Color3.fromRGB(30, 50, 42),
	CedarTrunk = Color3.fromRGB(70, 48, 40),
	Bamboo = Color3.fromRGB(88, 120, 78),
	BambooLeaf = Color3.fromRGB(64, 96, 60),
	Fern = Color3.fromRGB(70, 88, 52),
	Leaves = Color3.fromRGB(150, 84, 44),
	Hill = Color3.fromRGB(44, 62, 56),
	HillFar = Color3.fromRGB(70, 78, 104),
}

function Kit.Part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Shape?): BasePart
	local p: BasePart
	if shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		local block = Instance.new("Part")
		if shape == "Cylinder" then
			block.Shape = Enum.PartType.Cylinder
		elseif shape == "Ball" then
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
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local solid = parent.Name == "Collision" or parent:FindFirstAncestor("Collision") ~= nil
	p.CanCollide = solid
	p.CanQuery = solid
	p.CanTouch = false
	if not solid then
		p.CastShadow = size.Y > 0.5
	end
	p:SetAttribute("Placeholder", true)
	p.Parent = parent
	return p
end

-- Upright cylinder (Roblox cylinders run along local X).
function Kit.Column(parent: Instance, name: string, height: number, diameter: number, base: Vector3, color: Color3, material: Enum.Material): BasePart
	return Kit.Part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, material, "Cylinder")
end

function Kit.Folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Kit.Model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Kit.Jitter(rng: Random, color: Color3, amount: number): Color3
	local k = 1 + rng:NextNumber(-amount, amount)
	return Color3.new(math.clamp(color.R * k, 0, 1), math.clamp(color.G * k, 0, 1), math.clamp(color.B * k, 0, 1))
end

-- Warm light; `nightOnly` lights are switched by WorldClockService.
function Kit.Glow(holder: BasePart, brightness: number, range: number, nightOnly: boolean?)
	local light = Instance.new("PointLight")
	light.Color = Kit.Palette.Amber
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	if nightOnly then
		light:SetAttribute("Brightness", brightness)
		game:GetService("CollectionService"):AddTag(light, Kit.NightLightTag)
	end
	light.Parent = holder
end

-- Paper window / lantern face that glows at night.
function Kit.Window(parent: Instance, size: Vector3, cf: CFrame): BasePart
	local w = Kit.Part(parent, "Window", size, cf, Kit.Palette.Paper, Enum.Material.SmoothPlastic)
	game:GetService("CollectionService"):AddTag(w, Kit.NightGlowTag)
	return w
end

-- Floating name label (shop signs, plot owner).
function Kit.Label(holder: BasePart, text: string, offsetY: number, maxDistance: number?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = maxDistance or 90
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 240, 210)
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui
	gui.Parent = holder
	return label
end

-- Flat ground overlay `top` studs above the floor, rotated `yaw` about Y.
function Kit.Slab(parent: Instance, name: string, sizeX: number, sizeZ: number, top: number, x: number, z: number, color: Color3, material: Enum.Material, yaw: number?): BasePart
	local h = 0.2
	return Kit.Part(parent, name, Vector3.new(sizeX, h, sizeZ), CFrame.new(x, FLOOR_Y + top - h / 2, z) * CFrame.Angles(0, yaw or 0, 0), color, material)
end

-- Ground strip along a polyline, one slab per segment plus round joints.
function Kit.Strip(parent: Instance, name: string, points: { { x: number, z: number } }, halfWidth: number, top: number, color: Color3, material: Enum.Material)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dz = b.x - a.x, b.z - a.z
		local len = math.sqrt(dx * dx + dz * dz)
		Kit.Slab(parent, name, halfWidth * 2, len, top, (a.x + b.x) / 2, (a.z + b.z) / 2, color, material, math.atan2(dx, dz))
		if i > 1 then
			Kit.Part(parent, name, Vector3.new(0.2, halfWidth * 2, halfWidth * 2), CFrame.new(a.x, FLOOR_Y + top - 0.1, a.z) * CFrame.Angles(0, 0, math.rad(90)), color, material, "Cylinder")
		end
	end
end

------------------------------------------------------------------------------
-- Trees
------------------------------------------------------------------------------

-- Japanese cedar: solid trunk, stacked cone-ish crowns.
function Kit.Cedar(f: Folders, rng: Random, x: number, z: number, scale: number)
	local trunkH = 10 * scale
	Kit.Column(f.solid, "CedarTrunk", trunkH, 2 * scale, Vector3.new(x, FLOOR_Y, z), Kit.Palette.CedarTrunk, Enum.Material.Wood)
	local tiers = { { 11, 7 }, { 8.5, 6.5 }, { 6, 6 }, { 3.2, 5 } }
	local y = trunkH * 0.75
	local color = Kit.Jitter(rng, Kit.Palette.Cedar, 0.12)
	for _, t in tiers do
		Kit.Column(f.decor, "CedarCrown", t[2] * scale, t[1] * scale, Vector3.new(x, FLOOR_Y + y, z), color, Enum.Material.Grass)
		y += t[2] * scale * 0.72
	end
end

-- Autumn maple: solid trunk, a few warm ellipsoid canopies.
function Kit.Maple(f: Folders, rng: Random, x: number, z: number, scale: number)
	local trunkH = 6 * scale
	Kit.Column(f.solid, "MapleTrunk", trunkH, 1.1 * scale, Vector3.new(x, FLOOR_Y, z), Kit.Palette.HouseWoodDark, Enum.Material.Wood)
	local colors = { Kit.Palette.MapleRed, Kit.Palette.MapleOrange, Kit.Palette.MapleYellow }
	local base = colors[rng:NextInteger(1, 3)]
	for _ = 1, 4 do
		local s = rng:NextNumber(5, 8) * scale
		Kit.Part(
			f.decor,
			"MapleLeaves",
			Vector3.new(s, s * 0.7, s * rng:NextNumber(0.8, 1.1)),
			CFrame.new(x + rng:NextNumber(-2.2, 2.2) * scale, FLOOR_Y + trunkH + rng:NextNumber(-0.5, 2.5) * scale, z + rng:NextNumber(-2.2, 2.2) * scale),
			Kit.Jitter(rng, if rng:NextNumber() < 0.7 then base else colors[rng:NextInteger(1, 3)], 0.1),
			Enum.Material.Grass,
			"Ball"
		)
	end
end

function Kit.Bamboo(f: Folders, rng: Random, x: number, z: number)
	local height = rng:NextNumber(18, 30)
	local d = rng:NextNumber(0.6, 1)
	Kit.Column(f.solid, "BambooCulm", height, d, Vector3.new(x, FLOOR_Y, z), Kit.Jitter(rng, Kit.Palette.Bamboo, 0.1), Enum.Material.SmoothPlastic)
	for i = 1, 2 do
		Kit.Part(
			f.decor,
			"BambooLeaves",
			Vector3.new(rng:NextNumber(4, 6), rng:NextNumber(2.5, 3.5), rng:NextNumber(4, 6)),
			CFrame.new(x + rng:NextNumber(-1.2, 1.2), FLOOR_Y + height * (0.7 + 0.13 * i), z + rng:NextNumber(-1.2, 1.2)),
			Kit.Jitter(rng, Kit.Palette.BambooLeaf, 0.12),
			Enum.Material.Grass,
			"Ball"
		)
	end
end

-- Low stone street lantern: solid post, fire box that glows at night.
-- `light` adds a night-only PointLight (keep these sparse for mobile).
function Kit.StreetLantern(f: Folders, x: number, z: number, light: boolean)
	local P = Kit.Palette
	Kit.Part(f.solid, "LanternPost", Vector3.new(1, 3.2, 1), CFrame.new(x, FLOOR_Y + 1.6, z), P.Stone, Enum.Material.Slate)
	Kit.Part(f.decor, "LanternBase", Vector3.new(1.8, 0.4, 1.8), CFrame.new(x, FLOOR_Y + 0.2, z), P.StoneDark, Enum.Material.Slate)
	local fire = Kit.Window(f.decor, Vector3.new(1.1, 1.1, 1.1), CFrame.new(x, FLOOR_Y + 3.75, z))
	fire.Name = "LanternFire"
	Kit.Part(f.decor, "LanternCap", Vector3.new(2.2, 0.4, 2.2), CFrame.new(x, FLOOR_Y + 4.5, z), P.StoneDark, Enum.Material.Slate)
	Kit.Part(f.decor, "LanternCap", Vector3.new(1.2, 0.35, 1.2), CFrame.new(x, FLOOR_Y + 4.85, z), P.StoneDark, Enum.Material.Slate)
	if light then
		Kit.Glow(fire, 1.4, 16, true)
	end
end

------------------------------------------------------------------------------
-- Gassho-zukuri house
------------------------------------------------------------------------------

export type HouseOpts = {
	width: number, -- along local X (gable to gable runs along Z)
	depth: number, -- along local Z
	wallHeight: number,
	roofHeight: number,
	eave: number,
	windowRows: number?, -- rows of lit windows in the gable
}

-- Steep thatched A-frame house. `cf` is the ground centre; the front gable
-- (door, windows) faces local -Z. Body and roof are solid so the camera and
-- players treat the house as a building; trim and windows are decor.
function Kit.Gassho(f: Folders, cf: CFrame, o: HouseOpts): Model
	local P = Kit.Palette
	local solid = Kit.Model(f.solid, "House")
	local decor = Kit.Model(f.decor, "House")
	local w, d, wallH, roofH, eave = o.width, o.depth, o.wallHeight, o.roofHeight, o.eave
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, FLOOR_Y + y, z)
	end

	Kit.Part(solid, "Plinth", Vector3.new(w + 1.2, 0.6, d + 1.2), at(0, 0.3, 0), P.StoneDark, Enum.Material.Cobblestone)
	Kit.Part(solid, "Body", Vector3.new(w, wallH, d), at(0, 0.6 + wallH / 2, 0), P.HouseWood, Enum.Material.WoodPlanks)

	-- Timber frame and paper panels on the front and back faces.
	local top = 0.6 + wallH
	for _, side in { -1, 1 } do
		local z = side * (d / 2 + 0.06)
		for i = 0, 4 do
			local x = -w / 2 + 0.3 + i * (w - 0.6) / 4
			Kit.Part(decor, "Post", Vector3.new(0.45, wallH, 0.12), at(x, 0.6 + wallH / 2, z), P.HouseWoodDark, Enum.Material.Wood)
		end
		Kit.Part(decor, "Rail", Vector3.new(w, 0.35, 0.12), at(0, top - 0.2, z), P.HouseWoodDark, Enum.Material.Wood)
		for i = 0, 3 do
			local x = -w / 2 + 0.3 + (i + 0.5) * (w - 0.6) / 4
			if side == 1 or i == 0 or i == 3 then
				Kit.Window(decor, Vector3.new((w - 0.6) / 4 - 0.8, wallH * 0.42, 0.1), at(x, 0.6 + wallH * 0.6, z * 1.004))
			end
		end
	end
	-- Door in the front middle.
	Kit.Part(decor, "Door", Vector3.new(w * 0.22, wallH * 0.78, 0.14), at(0, 0.6 + wallH * 0.39, -(d / 2 + 0.1)), P.HouseWoodDark, Enum.Material.Wood)

	-- Roof: two thick thatch slabs meeting at the ridge (ridge along Z).
	local run = w / 2
	local alpha = math.atan2(roofH, run)
	local slopeLen = math.sqrt(run * run + roofH * roofH)
	local thick = 1.8
	local length = slopeLen + eave + 0.4
	local roofDepth = d + eave * 2
	for _, side in { -1, 1 } do
		-- Unit vector from the ridge down toward this side's eave.
		local ux, uy = side * math.cos(alpha), -math.sin(alpha)
		local nx, ny = side * math.sin(alpha), math.cos(alpha) -- outward normal
		local mid = (length / 2) - 0.4
		local cx = ux * mid + nx * thick / 2
		local cy = top + roofH + uy * mid + ny * thick / 2
		Kit.Part(solid, "Thatch", Vector3.new(length, thick, roofDepth), at(cx, cy, 0) * CFrame.Angles(0, 0, -side * alpha), P.Thatch, Enum.Material.Grass)
		-- Darker underside lip so the eave edge reads from below.
		Kit.Part(decor, "ThatchEdge", Vector3.new(0.6, thick + 0.1, roofDepth + 0.1), at(ux * (length - 0.4) + nx * thick / 2, top + roofH + uy * (length - 0.4) + ny * thick / 2, 0) * CFrame.Angles(0, 0, -side * alpha), P.ThatchDark, Enum.Material.Grass)
	end
	Kit.Part(decor, "Ridge", Vector3.new(1.6, 1.2, roofDepth + 0.4), at(0, top + roofH + thick * 0.9, 0), P.ThatchDark, Enum.Material.Grass)

	-- Gable triangles (plaster with timber and lit windows), front and back.
	for _, side in { -1, 1 } do
		local z = side * (d / 2 - 0.2)
		for _, half in { -1, 1 } do
			-- Wedge rises toward local +Z; turn it so it climbs toward the ridge.
			Kit.Part(solid, "Gable", Vector3.new(0.4, roofH, run), at(half * run / 2, top + roofH / 2, z) * CFrame.Angles(0, half * -math.pi / 2, 0), P.Plaster, Enum.Material.Plaster, "Wedge")
		end
		local face = side * (d / 2 + 0.02)
		Kit.Part(decor, "GableBeam", Vector3.new(w, 0.4, 0.14), at(0, top + 0.2, face), P.HouseWoodDark, Enum.Material.Wood)
		local rows = o.windowRows or 2
		for r = 1, rows do
			local y = top + roofH * (r - 0.4) / (rows + 1)
			local halfAtY = run * (1 - (y - top) / roofH)
			local count = math.max(1, math.floor(halfAtY / 1.8))
			for k = 1, count do
				local x = (k - (count + 1) / 2) * (halfAtY * 1.6 / count)
				Kit.Window(decor, Vector3.new(halfAtY * 1.2 / count, roofH * 0.12, 0.1), at(x, y, face))
			end
			Kit.Part(decor, "GableBeam", Vector3.new(halfAtY * 2, 0.3, 0.14), at(0, y - roofH * 0.1, face), P.HouseWoodDark, Enum.Material.Wood)
		end
	end
	return solid
end

return Kit

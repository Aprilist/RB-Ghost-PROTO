--!strict
-- Enemy models (server-owned, anchored, primitive parts only). Each builder
-- makes the upright `Body` PrimaryPart that AI, hits and the HP bar use;
-- every other part is visual only (no collide/query/touch) and follows it.
-- The telegraph warning parts are added by EnemyService from the attack
-- shape, so a model only needs its look.
-- lantern_wisp moved here from EnemyService unchanged (VB-01 benchmark).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VisualPalette = require(ReplicatedStorage.Shared.Definitions.VisualPalette)

export type Tint = { part: BasePart, calm: Color3, angry: Color3 }

export type Built = {
	model: Model,
	body: BasePart,
	tints: { Tint }, -- recoloured while telegraphing
	hpBarOffsetStuds: number,
}

local Models = {}

local function visualPart(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parent
	return part
end
Models.VisualPart = visualPart

-- Squashed sphere: a Ball part is forced uniform, a sphere mesh fills Size.
local function ellipsoid(part: Part): Part
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Upright disc/cylinder (Roblox cylinders run along local X).
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
Models.UPRIGHT = UPRIGHT

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
end

-- VB-01 benchmark wisp: a possessed paper chōchin. Oval paper body with
-- bamboo ribs, wooden rims, glowing eyes, a lolling tongue, a flame on top and
-- a fading spirit tail.
local function lanternWisp(model: Model, at: CFrame): Built
	local PAPER = VisualPalette.Paper
	local FLAME = VisualPalette.Ember
	model.Name = "LanternWisp"

	local bodyH, bodyW = 3, 2.5
	local body = ellipsoid(visualPart(model, "Body", Vector3.new(bodyW, bodyH, bodyW), PAPER, Enum.Material.SmoothPlastic))
	body.CFrame = at
	model.PrimaryPart = body
	light(body, FLAME, 9, 0.9)

	-- Ribs: thin discs just wider than the oval at their height.
	for _, h in { -0.95, -0.45, 0.05, 0.55, 1.0 } do
		local w = bodyW * math.sqrt(math.max(0, 1 - (h / (bodyH / 2)) ^ 2)) + 0.06
		local rib = visualPart(model, "Rib", Vector3.new(0.06, w, w), VisualPalette.Rib, Enum.Material.Wood)
		rib.Shape = Enum.PartType.Cylinder
		rib.CFrame = at * CFrame.new(0, h, 0) * UPRIGHT
	end
	for _, rim in { { 1.45, 1.5 }, { -1.45, 1.3 } } do
		local part = visualPart(model, "Rim", Vector3.new(0.32, rim[2], rim[2]), VisualPalette.LanternWood, Enum.Material.Wood)
		part.Shape = Enum.PartType.Cylinder
		part.CFrame = at * CFrame.new(0, rim[1], 0) * UPRIGHT
	end

	-- Face on the front (-Z): glowing eyes, dark mouth, tongue.
	for _, side in { -0.45, 0.45 } do
		local eye = ellipsoid(visualPart(model, "Eye", Vector3.new(0.42, 0.55, 0.16), VisualPalette.WispEye, Enum.Material.Neon))
		eye.CFrame = at * CFrame.new(side, 0.35, -1.17)
	end
	local mouth = ellipsoid(visualPart(model, "Mouth", Vector3.new(1.1, 0.34, 0.18), VisualPalette.WispMouth, Enum.Material.SmoothPlastic))
	mouth.CFrame = at * CFrame.new(0, -0.35, -1.17)
	local tongue = ellipsoid(visualPart(model, "Tongue", Vector3.new(0.42, 0.7, 0.14), VisualPalette.WispTongue, Enum.Material.SmoothPlastic))
	tongue.CFrame = at * CFrame.new(0.15, -0.7, -1.12) * CFrame.Angles(math.rad(-20), 0, math.rad(8))

	local flame = ellipsoid(visualPart(model, "Flame", Vector3.new(0.7, 1.1, 0.7), FLAME, Enum.Material.Neon))
	flame.CFrame = at * CFrame.new(0, 2.05, 0)
	light(flame, FLAME, 10, 1.2)

	-- Spirit tail under the lantern, fading out.
	for i, t in { { 0.9, 0.35 }, { 0.6, 0.55 }, { 0.35, 0.72 } } do
		local wisp = ellipsoid(visualPart(model, "Tail", Vector3.new(t[1], t[1] * 1.3, t[1]), FLAME, Enum.Material.Neon))
		wisp.Transparency = t[2]
		wisp.CFrame = at * CFrame.new(0.1 * (i % 2), -1.6 - (i - 1) * 0.55, 0.15 * i)
	end

	return { model = model, body = body, tints = { { part = body, calm = PAPER, angry = VisualPalette.PaperAngry } }, hpBarOffsetStuds = 3 }
end

-- Hitodama: a soul flame. Bright teardrop core inside a softer flame shell,
-- two dark eye dots and a long wavering tail. Ghost-fire green so it never
-- reads as the blue soul orb or the red-orange danger warning.
local function hitodama(model: Model, at: CFrame): Built
	local FIRE = VisualPalette.GhostFire
	model.Name = "Hitodama"
	local body = ellipsoid(visualPart(model, "Body", Vector3.new(1.8, 2, 1.8), VisualPalette.GhostFireCore, Enum.Material.Neon))
	body.CFrame = at
	model.PrimaryPart = body
	light(body, FIRE, 10, 1.4)
	local shell = ellipsoid(visualPart(model, "Shell", Vector3.new(2.4, 2.9, 2.4), FIRE, Enum.Material.Neon))
	shell.Transparency = 0.55
	shell.CFrame = at * CFrame.new(0, 0.3, 0)
	local tip = ellipsoid(visualPart(model, "Tip", Vector3.new(0.9, 1.6, 0.9), FIRE, Enum.Material.Neon))
	tip.Transparency = 0.4
	tip.CFrame = at * CFrame.new(0, 1.7, 0.1) * CFrame.Angles(math.rad(-12), 0, 0)
	for _, side in { -0.32, 0.32 } do
		local eye = ellipsoid(visualPart(model, "Eye", Vector3.new(0.26, 0.36, 0.1), VisualPalette.GhostFireEye, Enum.Material.SmoothPlastic))
		eye.CFrame = at * CFrame.new(side, 0.1, -0.86)
	end
	-- Tail streams behind (+Z) and down.
	for i, t in { { 1.2, 0.45 }, { 0.85, 0.6 }, { 0.55, 0.72 }, { 0.3, 0.82 } } do
		local tail = ellipsoid(visualPart(model, "Tail", Vector3.new(t[1], t[1], t[1] * 1.4), FIRE, Enum.Material.Neon))
		tail.Transparency = t[2]
		tail.CFrame = at * CFrame.new(0, -0.3 - i * 0.2, 0.7 + i * 0.6)
	end
	return {
		model = model,
		body = body,
		tints = { { part = shell, calm = FIRE, angry = VisualPalette.PaperAngry } },
		hpBarOffsetStuds = 2.6,
	}
end

-- Kodama: a small pale tree spirit. Round head with three hollow holes for
-- eyes and mouth, stubby body, twig arms and a leaf on the head.
local function kodama(model: Model, at: CFrame): Built
	local SKIN = VisualPalette.KodamaSkin
	model.Name = "Kodama"
	-- Body is the torso; the head sits above it.
	local body = ellipsoid(visualPart(model, "Body", Vector3.new(1.6, 2, 1.4), SKIN, Enum.Material.SmoothPlastic))
	body.CFrame = at
	model.PrimaryPart = body
	local head = ellipsoid(visualPart(model, "Head", Vector3.new(2.2, 2, 2), SKIN, Enum.Material.SmoothPlastic))
	head.CFrame = at * CFrame.new(0, 1.8, 0)
	light(head, VisualPalette.KodamaGlow, 7, 0.6)
	for _, hole in { { -0.42, 2.0, 0.34 }, { 0.42, 2.0, 0.34 }, { 0, 1.35, 0.42 } } do
		local h = ellipsoid(visualPart(model, if hole[1] == 0 then "Mouth" else "Eye", Vector3.new(hole[3], hole[3] * 1.25, 0.12), VisualPalette.KodamaHole, Enum.Material.SmoothPlastic))
		h.CFrame = at * CFrame.new(hole[1], hole[2], -0.95)
	end
	for _, side in { -1, 1 } do
		local arm = visualPart(model, "Twig", Vector3.new(0.18, 1.1, 0.18), VisualPalette.Rib, Enum.Material.Wood)
		arm.CFrame = at * CFrame.new(side * 0.95, -0.1, 0) * CFrame.Angles(0, 0, math.rad(side * 40))
		local foot = ellipsoid(visualPart(model, "Foot", Vector3.new(0.5, 0.35, 0.7), SKIN, Enum.Material.SmoothPlastic))
		foot.CFrame = at * CFrame.new(side * 0.4, -1.05, -0.1)
	end
	local stem = visualPart(model, "Stem", Vector3.new(0.12, 0.5, 0.12), VisualPalette.Rib, Enum.Material.Wood)
	stem.CFrame = at * CFrame.new(0.2, 2.95, 0)
	local leaf = ellipsoid(visualPart(model, "Leaf", Vector3.new(0.9, 0.12, 0.5), VisualPalette.KodamaLeaf, Enum.Material.Grass))
	leaf.CFrame = at * CFrame.new(0.55, 3.15, 0) * CFrame.Angles(0, 0, math.rad(20))
	return {
		model = model,
		body = body,
		tints = {
			{ part = head, calm = SKIN, angry = VisualPalette.PaperAngry },
			{ part = body, calm = SKIN, angry = VisualPalette.PaperAngry },
		},
		hpBarOffsetStuds = 4,
	}
end

-- Karakasa: an old paper umbrella spirit. Tiered canopy with ribs and a top
-- cap, one big eye, a long tongue, its handle turned into one leg on a geta.
local function karakasa(model: Model, at: CFrame): Built
	local CANOPY = VisualPalette.Wagasa
	model.Name = "Karakasa"
	-- Body: an unseen upright hub inside the canopy; the panels show the shape.
	local body = visualPart(model, "Body", Vector3.new(2, 2.6, 2), CANOPY, Enum.Material.SmoothPlastic)
	body.CFrame = at
	body.Transparency = 1
	model.PrimaryPart = body
	-- Canopy as stacked discs narrowing to the cap (a half-closed wagasa),
	-- with dark rib bands between paper tiers.
	local panels: { BasePart } = {}
	for i, tier in { { -1.0, 3.4 }, { -0.45, 3.0 }, { 0.1, 2.5 }, { 0.6, 1.9 }, { 1.05, 1.2 } } do
		local disc = visualPart(model, "Panel", Vector3.new(0.55, tier[2], tier[2]), if i % 2 == 1 then CANOPY else VisualPalette.WagasaDark, Enum.Material.SmoothPlastic)
		disc.Shape = Enum.PartType.Cylinder
		disc.CFrame = at * CFrame.new(0, tier[1], 0) * UPRIGHT
		table.insert(panels, disc)
	end
	for i = 0, 7 do
		local rib = visualPart(model, "Rib", Vector3.new(0.08, 2.4, 0.08), VisualPalette.Rib, Enum.Material.Wood)
		rib.CFrame = at * CFrame.Angles(0, math.rad(i * 45), 0) * CFrame.new(0, 0, -1.2) * CFrame.Angles(math.rad(-28), 0, 0)
	end
	local cap = visualPart(model, "Cap", Vector3.new(0.9, 0.5, 0.5), VisualPalette.LanternWood, Enum.Material.Wood)
	cap.Shape = Enum.PartType.Cylinder
	cap.CFrame = at * CFrame.new(0, 1.4, 0) * UPRIGHT
	local eye = ellipsoid(visualPart(model, "Eye", Vector3.new(0.9, 0.9, 0.2), VisualPalette.WispEye, Enum.Material.SmoothPlastic))
	eye.CFrame = at * CFrame.new(0, 0.3, -1.3)
	local pupil = ellipsoid(visualPart(model, "Pupil", Vector3.new(0.38, 0.45, 0.1), VisualPalette.WispMouth, Enum.Material.SmoothPlastic))
	pupil.CFrame = at * CFrame.new(0, 0.27, -1.4)
	local mouth = ellipsoid(visualPart(model, "Mouth", Vector3.new(0.8, 0.28, 0.16), VisualPalette.WispMouth, Enum.Material.SmoothPlastic))
	mouth.CFrame = at * CFrame.new(0, -0.45, -1.55)
	local tongue = ellipsoid(visualPart(model, "Tongue", Vector3.new(0.4, 1.4, 0.14), VisualPalette.WispTongue, Enum.Material.SmoothPlastic))
	tongue.CFrame = at * CFrame.new(0.1, -1.1, -1.62) * CFrame.Angles(math.rad(-15), 0, math.rad(6))
	-- Handle becomes the single leg.
	local leg = visualPart(model, "Leg", Vector3.new(0.35, 1.3, 0.35), VisualPalette.KarakasaLeg, Enum.Material.SmoothPlastic)
	leg.CFrame = at * CFrame.new(0, -1.75, 0)
	local geta = visualPart(model, "Geta", Vector3.new(0.7, 0.18, 1.1), VisualPalette.LanternWood, Enum.Material.Wood)
	geta.CFrame = at * CFrame.new(0, -2.5, -0.15)
	local tints: { Tint } = {}
	for _, p in panels do
		table.insert(tints, { part = p, calm = p.Color, angry = VisualPalette.PaperAngry })
	end
	return { model = model, body = body, tints = tints, hpBarOffsetStuds = 3 }
end

local BUILDERS: { [string]: (Model, CFrame) -> Built } = {
	lantern_wisp = lanternWisp,
	hitodama = hitodama,
	kodama = kodama,
	karakasa = karakasa,
}

function Models.Has(definitionId: string): boolean
	return BUILDERS[definitionId] ~= nil
end

function Models.Build(definitionId: string, at: CFrame): Built
	local builder = BUILDERS[definitionId]
	assert(builder, "no model for enemy " .. definitionId)
	local model = Instance.new("Model")
	return builder(model, at)
end

-- Idle motion: height offset over time. The wisp keeps its P1 bob.
function Models.Bob(definitionId: string, t: number): number
	if definitionId == "hitodama" then
		return math.sin(t * 3) * 0.45
	elseif definitionId == "kodama" then
		return math.abs(math.sin(t * 6)) * 0.25 -- waddle
	elseif definitionId == "karakasa" then
		return math.abs(math.sin(t * 4)) * 0.9 -- one-leg hops
	end
	return math.sin(t * 2) * 0.25
end

return Models

--!strict
-- M2-B greybox of the Last Lantern Village (หมู่บ้านโคมสุดท้าย), styled
-- after a Shirakawa-gō gasshō village in autumn. Oval layout from the
-- Director's second sketch (27 Oct 2026): an ancient sacred tree on a stone
-- plaza in the middle with market stalls round it, lawns round that, then a
-- ring road with one ring of twelve player houses outside it, all facing in,
-- so every house is seen the same from the plaza. The entrance from the
-- forest and the north road pass through gaps in the ring. A stone avenue
-- runs ring road → spawn → plaza, with paved walks from the north, east and
-- west. Keeper's shrine on the inner lawn, paddies to the east, a grove in
-- the north-west corner.
-- Hub only: no enemies, no rewards.
-- Layout numbers come from Definitions/World; plots are filled at runtime by
-- PlotService through BuildPlotLocked / BuildPlotHouse.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Definitions.World)
local Kit = require(script.Parent.Kit)
local ShrineCourtyard = require(script.Parent.ShrineCourtyard)

local V = World.Village
local P = Kit.Palette
local FLOOR_Y = Kit.FloorY
local SEED = 20261102
local CENTER = Vector3.new(V.center.x, 0, V.center.z)
local GATE_HALF = 7 -- plot gate half-width
local YARD_RADIUS = 24 -- spirit yard in front of each player house (shrunk with the plots, 27 Oct 2026)
local FLOWERS = {
	Color3.fromRGB(196, 62, 72),
	Color3.fromRGB(236, 226, 214),
	Color3.fromRGB(232, 182, 70),
	Color3.fromRGB(150, 96, 170),
	Color3.fromRGB(226, 120, 44),
}

type Folders = Kit.Folders
type PlotDef = World.Plot

local Village = {}

-- Ground-level unit direction for `angle` (0 = south/-Z, 90 = east/+X).
local function heading(angle: number): Vector3
	local a = math.rad(angle)
	return Vector3.new(math.sin(a), 0, -math.cos(a))
end

-- Point on a circle round the village centre, same angle convention.
local function onCircle(angle: number, radius: number): Vector3
	return CENTER + heading(angle) * radius
end

-- Ground frame at (x, z) whose front (local -Z) faces (tx, tz).
local function facing(x: number, z: number, tx: number, tz: number): CFrame
	return CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(tx, 0, tz))
end

-- Frame on the stall circle whose front faces away from the tree.
local function facingOut(angle: number, radius: number): CFrame
	local p = onCircle(angle, radius)
	return CFrame.lookAt(p, p + heading(angle))
end

-- The grove cottage sits on the grove's edge nearest the village.
function Village.GroveCottageX(): number
	local g = V.grove
	return g.x - math.sign(g.x) * (g.radius - 4)
end

-- Plot frame: centre of the yard, front (gate, local -Z) toward the road.
function Village.PlotFrame(plot: PlotDef): CFrame
	local p = Vector3.new(plot.x, 0, plot.z)
	return CFrame.lookAt(p, p + heading(plot.angle))
end

-- Distance from (x, z) to the nearest road edge (negative on a road).
function Village.DistanceToRoad(x: number, z: number): number
	local best = math.huge
	for _, road in V.roads do
		local pts = road.points
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local dx, dz = b.x - a.x, b.z - a.z
			local t = math.clamp(((x - a.x) * dx + (z - a.z) * dz) / (dx * dx + dz * dz), 0, 1)
			local d = math.sqrt((x - a.x - dx * t) ^ 2 + (z - a.z - dz * t) ^ 2) - road.halfWidth
			best = math.min(best, d)
		end
	end
	return best
end

-- Distance from (x, z) to the plaza's stadium outline (negative inside).
function Village.DistanceToPlaza(x: number, z: number): number
	local straight = V.plazaHalfZ - V.plazaHalfX
	local dz = math.max(math.abs(z - V.center.z) - straight, 0)
	return math.sqrt((x - V.center.x) ^ 2 + dz * dz) - V.plazaHalfX
end

-- Circles (x, z, radius) that scattered trees must keep clear of.
local blockers: { { number } } = {}

local function clear(x: number, z: number, r: number): boolean
	for _, b in blockers do
		local dx, dz = x - b[1], z - b[2]
		if dx * dx + dz * dz < (r + b[3]) ^ 2 then
			return false
		end
	end
	return true
end

-- Open ground for a tree or prop of radius `r`: off the roads, the plaza,
-- the pond and everything already placed.
local function isOpen(x: number, z: number, r: number): boolean
	return Village.DistanceToRoad(x, z) > r + 1.5 and Village.DistanceToPlaza(x, z) > r + 2 and clear(x, z, r)
end

------------------------------------------------------------------------------
-- Ground, roads, plaza
------------------------------------------------------------------------------

local function stadium(parent: Instance, name: string, halfX: number, halfZ: number, top: number, color: Color3, material: Enum.Material)
	local straight = halfZ - halfX
	Kit.Slab(parent, name, halfX * 2, straight * 2, top, V.center.x, V.center.z, color, material)
	for _, dz in { -1, 1 } do
		-- Cylinder axis is local X; stand it on end to make a flat disc.
		Kit.Part(parent, name, Vector3.new(0.2, halfX * 2, halfX * 2), CFrame.new(V.center.x, FLOOR_Y + top - 0.1, V.center.z + dz * straight) * CFrame.Angles(0, 0, math.rad(90)), color, material, "Cylinder")
	end
end

local function buildGround(f: Folders, rng: Random)
	local w, d = V.maxX - V.minX, V.maxZ - V.minZ
	Kit.Part(f.solid, "Ground", Vector3.new(w, 2, d), CFrame.new((V.minX + V.maxX) / 2, FLOOR_Y - 1, (V.minZ + V.maxZ) / 2), P.Grass, Enum.Material.Grass)
	for _ = 1, 160 do
		Kit.Slab(f.decor, "GrassPatch", rng:NextNumber(10, 26), rng:NextNumber(8, 20), 0.03, rng:NextNumber(V.minX + 10, V.maxX - 10), rng:NextNumber(V.minZ + 10, V.maxZ - 10), Kit.Jitter(rng, P.GrassDark, 0.1), Enum.Material.Grass, rng:NextNumber(0, math.pi))
	end
	local paths = Kit.Folder(f.decor, "Paths")
	-- Earth roads; the shortcuts through the middle are paved.
	for _, road in V.roads do
		local paved = road.halfWidth < V.roadHalfWidth
		Kit.Strip(paths, road.name, road.points, road.halfWidth, if paved then 0.07 else 0.06, if paved then P.PathStone else P.PathDirt, if paved then Enum.Material.Slate else Enum.Material.Ground)
	end
	-- Stone plaza under the tree, with a darker kerb.
	stadium(paths, "PlazaKerb", V.plazaHalfX + 1, V.plazaHalfZ + 1, 0.09, P.StoneDark, Enum.Material.Slate)
	stadium(paths, "Plaza", V.plazaHalfX, V.plazaHalfZ, 0.1, P.PathStone, Enum.Material.Slate)
	-- Stepping path from the ring road to every plot gate.
	for _, plot in V.plots do
		local h = heading(plot.angle) -- gate direction, toward the road
		local front = Vector3.new(plot.x, 0, plot.z) + h * V.plotSize.z / 2
		local pa, pb = front + h * (V.vergeWidth + 1), front - h
		local a, b = { x = pa.X, z = pa.Z }, { x = pb.X, z = pb.Z }
		Kit.Strip(paths, "PlotPath", { a, b }, GATE_HALF - 1, 0.07, P.PathStone, Enum.Material.Slate)
	end
end

------------------------------------------------------------------------------
-- Sacred tree (shinboku) and the plaza round it
------------------------------------------------------------------------------

local function buildSacredTree(f: Folders, rng: Random)
	local cx, cz = V.center.x, V.center.z
	local r = V.treeTrunkRadius
	local trunkH = 34
	Kit.Column(f.solid, "SacredTrunk", trunkH, r * 2, Vector3.new(cx, FLOOR_Y, cz), P.CedarTrunk, Enum.Material.Wood)
	-- Root flares (low, decor) and the great limbs.
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + 0.3
		Kit.Part(f.decor, "Root", Vector3.new(r * 1.4, 2.2, 3), CFrame.new(cx + math.cos(a) * r * 0.9, FLOOR_Y + 0.6, cz + math.sin(a) * r * 0.9) * CFrame.Angles(0, -a, math.rad(-12)), P.CedarTrunk, Enum.Material.Wood)
	end
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		local len = rng:NextNumber(18, 24)
		local tilt = math.rad(rng:NextNumber(35, 50))
		local base = Vector3.new(cx, FLOOR_Y + trunkH - 4, cz)
		local dir = Vector3.new(math.cos(a) * math.sin(tilt), math.cos(tilt), math.sin(a) * math.sin(tilt))
		Kit.Part(f.decor, "Limb", Vector3.new(3.2, len, 3.2), CFrame.lookAt(base + dir * len / 2, base + dir * len) * CFrame.Angles(math.rad(90), 0, 0), P.CedarTrunk, Enum.Material.Wood)
	end
	-- Golden ancient canopy (ginkgo yellow with maple orange).
	for i = 1, 20 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = if i <= 5 then rng:NextNumber(0, 9) else rng:NextNumber(12, 26)
		local s = rng:NextNumber(18, 26)
		local color = if rng:NextNumber() < 0.75 then P.MapleYellow else P.MapleOrange
		Kit.Part(f.decor, "SacredCanopy", Vector3.new(s, s * 0.6, s), CFrame.new(cx + math.cos(a) * d, FLOOR_Y + trunkH + rng:NextNumber(3, 16) - d * 0.3, cz + math.sin(a) * d), Kit.Jitter(rng, color, 0.08), Enum.Material.Grass, "Ball")
	end
	-- Shimenawa round the trunk with paper shide.
	local ropeY = FLOOR_Y + 9
	for i = 0, 19 do
		local a = i / 20 * math.pi * 2
		Kit.Part(f.decor, "Shimenawa", Vector3.new(2.6, 1.2, 1.2), CFrame.new(cx + math.cos(a) * (r + 0.4), ropeY, cz + math.sin(a) * (r + 0.4)) * CFrame.Angles(0, -a + math.pi / 2, 0), P.Rope, Enum.Material.Fabric, "Cylinder")
		if i % 2 == 0 then
			Kit.Part(f.decor, "Shide", Vector3.new(0.6, 1.4, 0.05), CFrame.new(cx + math.cos(a) * (r + 0.6), ropeY - 1.1, cz + math.sin(a) * (r + 0.6)) * CFrame.Angles(0, -a + math.pi / 2, 0), P.Paper, Enum.Material.SmoothPlastic)
		end
	end
	-- Low rope fence (solid posts) so the trunk reads as sacred ground.
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		Kit.Part(f.solid, "FencePost", Vector3.new(0.6, 2.2, 0.6), CFrame.new(cx + math.cos(a) * (r + 3), FLOOR_Y + 1.1, cz + math.sin(a) * (r + 3)), P.HouseWoodDark, Enum.Material.Wood)
	end
	-- Paper lanterns hanging under the canopy; one warm light at night.
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local lamp = Kit.Window(f.decor, Vector3.new(2, 2.6, 2), CFrame.new(cx + math.cos(a) * (r + 5), FLOOR_Y + 20, cz + math.sin(a) * (r + 5)))
		lamp.Name = "TreeLantern"
		if i == 0 then
			Kit.Glow(lamp, 2, 30, true)
		end
	end
	local sign = Kit.Part(f.decor, "TreeSign", Vector3.new(0.5, 0.5, 0.5), CFrame.new(cx, FLOOR_Y + 14, cz), P.Amber, Enum.Material.Neon)
	sign.Transparency = 1
	Kit.Label(sign, "ต้นไม้ศักดิ์สิทธิ์", 0, 70)
	for _, dz in { -1, 1 } do
		table.insert(blockers, { cx, cz + dz * (V.plazaHalfZ - V.plazaHalfX), V.plazaHalfX })
	end
end

local function buildPlazaLanterns(f: Folders)
	-- Pairs of stone lanterns where the avenue and the side walks meet the
	-- plaza, and at its north tip.
	local cx, cz = V.center.x, V.center.z
	local spots = {
		{ cx - 7, cz - V.plazaHalfZ - 2, true },
		{ cx + 7, cz - V.plazaHalfZ - 2, false },
		{ cx - 7, cz + V.plazaHalfZ + 2, false },
		{ cx + 7, cz + V.plazaHalfZ + 2, false },
		{ cx - V.plazaHalfX - 2, cz - 7, false },
		{ cx - V.plazaHalfX - 2, cz + 7, false },
		{ cx + V.plazaHalfX + 2, cz - 7, false },
		{ cx + V.plazaHalfX + 2, cz + 7, true },
	}
	for _, s in spots do
		Kit.StreetLantern(f, s[1] :: number, s[2] :: number, s[3] :: boolean)
		table.insert(blockers, { s[1] :: number, s[2] :: number, 2 })
	end
end

------------------------------------------------------------------------------
-- Market stalls round the tree
------------------------------------------------------------------------------

local STALLS: { [string]: { label: string, cloth: Color3 } } = {
	shop = { label = "ร้านค้า", cloth = Color3.fromRGB(46, 58, 110) },
	smith = { label = "ร้านตีบวก", cloth = Color3.fromRGB(70, 62, 58) },
	talisman = { label = "ร้านยันต์", cloth = Color3.fromRGB(150, 44, 40) },
	teahouse = { label = "ร้านน้ำชา", cloth = Color3.fromRGB(90, 110, 70) },
}

-- Open stall: four posts, a counter at the front (local -Z, facing the
-- lawn), a sloped roof and a cloth noren. Returns the stall frame.
local function stallFrame(f: Folders, angle: number, label: string, cloth: Color3): CFrame
	local cf = facingOut(angle, V.stallRadius)
	local w, d = 13, 9
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local h = if c[2] < 0 then 8.5 else 10
		Kit.Part(f.solid, "StallPost", Vector3.new(0.5, h, 0.5), cf * CFrame.new(c[1] * (w / 2 - 0.3), FLOOR_Y + h / 2, c[2] * (d / 2 - 0.3)), P.HouseWoodDark, Enum.Material.Wood)
	end
	Kit.Part(f.solid, "Counter", Vector3.new(w - 1, 3, 2), cf * CFrame.new(0, FLOOR_Y + 1.5, -d / 2 + 1.2), P.HouseWood, Enum.Material.WoodPlanks)
	Kit.Part(f.solid, "StallBack", Vector3.new(w, 5, 0.4), cf * CFrame.new(0, FLOOR_Y + 2.5, d / 2 - 0.3), P.HouseWood, Enum.Material.WoodPlanks)
	Kit.Part(f.decor, "StallRoof", Vector3.new(w + 2, 0.5, d + 2), cf * CFrame.new(0, FLOOR_Y + 9.8, 0) * CFrame.Angles(math.rad(12), 0, 0), P.Thatch, Enum.Material.Grass)
	for i = -3, 3 do
		Kit.Part(f.decor, "Noren", Vector3.new(1.6, 2.2, 0.1), cf * CFrame.new(i * 1.8, FLOOR_Y + 7.4, -d / 2 - 0.4), cloth, Enum.Material.Fabric)
	end
	local lamp = Kit.Window(f.decor, Vector3.new(1.4, 2, 1.4), cf * CFrame.new(w / 2 + 0.2, FLOOR_Y + 7.4, -d / 2 - 0.6))
	lamp.Name = "StallLantern"
	local sign = Kit.Part(f.decor, "StallSign", Vector3.new(0.5, 0.5, 0.5), cf * CFrame.new(0, FLOOR_Y + 13, -d / 2), P.Amber, Enum.Material.Neon)
	sign.Transparency = 1
	Kit.Label(sign, label, 0, 100)
	return cf
end

local function buildStalls(f: Folders, rng: Random)
	for _, s in V.stalls do
		local def = STALLS[s.id]
		local cf = stallFrame(f, s.angle, def.label, def.cloth)
		if s.id == "shop" then
			for i = -1, 1 do
				Kit.Part(f.decor, "Goods", Vector3.new(1.4, 1, 1), cf * CFrame.new(i * 3.4, FLOOR_Y + 3.5, -3), Kit.Jitter(rng, P.Paper, 0.2), Enum.Material.Fabric)
			end
			for i = 1, 3 do
				Kit.Column(f.solid, "Barrel", 2, 1.6, (cf * CFrame.new(-8.8, 0, -3 + i * 2)).Position + Vector3.new(0, FLOOR_Y, 0), P.HouseWood, Enum.Material.Wood)
			end
		elseif s.id == "smith" then
			-- Forge beside the stall with coals and smoke, anvil in front.
			Kit.Part(f.solid, "Forge", Vector3.new(3.4, 3, 3.4), cf * CFrame.new(-9.6, FLOOR_Y + 1.5, 1), P.StoneDark, Enum.Material.Cobblestone)
			local coals = Kit.Part(f.decor, "ForgeCoals", Vector3.new(2.4, 0.4, 2.4), cf * CFrame.new(-9.6, FLOOR_Y + 3.1, 1), Color3.fromRGB(255, 110, 40), Enum.Material.Neon)
			Kit.Glow(coals, 2, 16)
			local chimney = Kit.Part(f.solid, "Chimney", Vector3.new(1.4, 9, 1.4), cf * CFrame.new(-10.4, FLOOR_Y + 4.5, 2.2), P.StoneDark, Enum.Material.Cobblestone)
			local smoke = Instance.new("ParticleEmitter")
			smoke.Name = "Smoke"
			smoke.Color = ColorSequence.new(Color3.fromRGB(150, 146, 140))
			smoke.Transparency = NumberSequence.new(0.5, 1)
			smoke.Size = NumberSequence.new(1.5, 5)
			smoke.Lifetime = NumberRange.new(3, 5)
			smoke.Rate = 3
			smoke.Speed = NumberRange.new(2, 3)
			smoke.SpreadAngle = Vector2.new(12, 12)
			smoke.EmissionDirection = Enum.NormalId.Top
			smoke.Parent = chimney
			Kit.Part(f.decor, "Anvil", Vector3.new(2.2, 0.8, 1), cf * CFrame.new(0, FLOOR_Y + 3.4, -3), Color3.fromRGB(60, 60, 66), Enum.Material.Metal)
		elseif s.id == "talisman" then
			-- Rows of paper talismans hanging from a rail.
			Kit.Part(f.decor, "TalismanRail", Vector3.new(12, 0.25, 0.25), cf * CFrame.new(0, FLOOR_Y + 8.6, -1), P.HouseWoodDark, Enum.Material.Wood)
			for i = -4, 4 do
				Kit.Part(f.decor, "Talisman", Vector3.new(0.9, 2.4, 0.05), cf * CFrame.new(i * 1.3, FLOOR_Y + 7.2, -1), P.Paper, Enum.Material.SmoothPlastic)
				Kit.Part(f.decor, "TalismanInk", Vector3.new(0.15, 1.6, 0.06), cf * CFrame.new(i * 1.3, FLOOR_Y + 7.2, -1.01), P.ToriiRed, Enum.Material.SmoothPlastic)
			end
		else
			-- Teahouse: red bench and a red parasol beside the stall.
			local bench = cf * CFrame.new(9.6, 0, -1)
			Kit.Part(f.solid, "TeaBench", Vector3.new(2, 1.4, 5), bench * CFrame.new(0, FLOOR_Y + 0.7, 0), P.ToriiRed, Enum.Material.Fabric)
			Kit.Part(f.decor, "ParasolPole", Vector3.new(0.2, 7, 0.2), bench * CFrame.new(1.2, FLOOR_Y + 3.5, 0), P.HouseWoodDark, Enum.Material.Wood)
			Kit.Part(f.decor, "Parasol", Vector3.new(0.4, 7, 7), bench * CFrame.new(1.2, FLOOR_Y + 7, 0) * CFrame.Angles(0, 0, math.rad(90)), P.ToriiRed, Enum.Material.Fabric, "Cylinder")
		end
	end
end

------------------------------------------------------------------------------
-- Lawns between the roads: spawn lawn and avenue, side lawns, north garden
------------------------------------------------------------------------------

local function bench(f: Folders, x: number, z: number, tx: number, tz: number)
	Kit.Part(f.solid, "Bench", Vector3.new(5, 1.2, 1.6), facing(x, z, tx, tz) * CFrame.new(0, FLOOR_Y + 0.6, 0), P.HouseWood, Enum.Material.Wood)
	table.insert(blockers, { x, z, 3 })
end

local function buildLawns(f: Folders, rng: Random)
	local cx, cz = V.center.x, V.center.z
	-- Quest board beside the spawn, facing it (M2-D).
	local bcf = facing(cx + 14, V.spawn.z + 8, V.spawn.x, V.spawn.z)
	for _, dx in { -2.2, 2.2 } do
		Kit.Part(f.solid, "BoardPost", Vector3.new(0.5, 6, 0.5), bcf * CFrame.new(dx, FLOOR_Y + 3, 0), P.HouseWoodDark, Enum.Material.Wood)
	end
	local board = Kit.Part(f.decor, "QuestBoard", Vector3.new(5, 3, 0.3), bcf * CFrame.new(0, FLOOR_Y + 3.6, 0), P.HouseWood, Enum.Material.WoodPlanks)
	Kit.Part(f.decor, "QuestBoardRoof", Vector3.new(6, 0.4, 1.4), bcf * CFrame.new(0, FLOOR_Y + 6.2, 0), P.ThatchDark, Enum.Material.Grass)
	Kit.Label(board, "กระดานเควสต์", 3.5, 60)
	table.insert(blockers, { bcf.Position.X, bcf.Position.Z, 5 })
	table.insert(blockers, { V.spawn.x, V.spawn.z, 8 })
	-- Benches along the avenue, between the ring road and the spawn.
	local benchZ = cz - V.roadRadius + 20
	bench(f, cx - 8, benchZ, cx, benchZ)
	bench(f, cx + 8, benchZ, cx, benchZ)
	-- Maple avenue: a row each side of the stone avenue, clear of the spawn.
	for z = cz - V.roadRadius + 12, cz - V.plazaHalfZ - 14, 28 do
		for _, side in { -1, 1 } do
			local x = cx + side * 13
			if isOpen(x, z, 4) then
				Kit.Maple(f, rng, x, z, rng:NextNumber(1.3, 1.5))
				table.insert(blockers, { x, z, 4 })
			end
		end
	end
	-- Lawns inside the ring road: maples wherever there is room.
	local placed = 0
	for _ = 1, 400 do
		if placed >= 34 then
			break
		end
		local x = cx + rng:NextNumber(-V.roadRadius, V.roadRadius)
		local z = cz + rng:NextNumber(-V.roadRadius, V.roadRadius)
		local scale = rng:NextNumber(1.2, 1.6)
		local inside = math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2) < V.roadRadius - V.roadHalfWidth - 4 * scale - 2
		if inside and isOpen(x, z, 4 * scale) and math.abs(x) > 18 then
			table.insert(blockers, { x, z, 4 * scale })
			Kit.Maple(f, rng, x, z, scale)
			placed += 1
		end
	end
end

local function buildPond(f: Folders, rng: Random)
	-- Garden pond on the north lawn: water, a ring of rocks, reeds, two lanterns.
	local pd = V.pond
	Kit.Part(f.decor, "PondBank", Vector3.new(0.2, (pd.radius + 2) * 2, (pd.radius + 2) * 2), CFrame.new(pd.x, FLOOR_Y + 0.04, pd.z) * CFrame.Angles(0, 0, math.rad(90)), P.PathDirt, Enum.Material.Ground, "Cylinder")
	local water = Kit.Part(f.decor, "PondWater", Vector3.new(0.2, pd.radius * 2, pd.radius * 2), CFrame.new(pd.x, FLOOR_Y + 0.08, pd.z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(58, 92, 104), Enum.Material.Glass, "Cylinder")
	water.Transparency = 0.15
	water.Reflectance = 0.2
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local s = rng:NextNumber(1.6, 3)
		local r = pd.radius + rng:NextNumber(0, 1.4)
		Kit.Part(f.decor, "PondRock", Vector3.new(s, s * 0.6, s * 0.9), CFrame.new(pd.x + math.cos(a) * r, FLOOR_Y + s * 0.2, pd.z + math.sin(a) * r), Kit.Jitter(rng, P.Stone, 0.12), Enum.Material.Slate, "Ball")
	end
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		Kit.Part(f.decor, "Reed", Vector3.new(0.3, 3, 0.3), CFrame.new(pd.x + math.cos(a) * (pd.radius - 1.5), FLOOR_Y + 1.5, pd.z + math.sin(a) * (pd.radius - 1.5)), P.Stubble, Enum.Material.Grass)
	end
	for _, side in { -1, 1 } do
		ShrineCourtyard.StoneLantern(f.decor, pd.x + side * (pd.radius + 5), pd.z - 4)
	end
	table.insert(blockers, { pd.x, pd.z, pd.radius + 6 })
end

local function buildStreetLanterns(f: Folders)
	-- Inside the ring road opposite every gate, and on the outer verge in the
	-- gaps between houses (not where the entrance and north road leave).
	local inner = V.roadRadius - V.roadHalfWidth - 2.5
	local outer = V.roadRadius + V.roadHalfWidth + V.vergeWidth / 2
	for k = 0, 11 do
		local p = onCircle(15 + k * 30, inner)
		Kit.StreetLantern(f, p.X, p.Z, k == 2 or k == 8)
		table.insert(blockers, { p.X, p.Z, 2 })
		if k ~= 0 and k ~= 6 then
			p = onCircle(k * 30, outer)
			Kit.StreetLantern(f, p.X, p.Z, false)
		end
	end
	-- Either side of the entrance road.
	for _, side in { -1, 1 } do
		Kit.StreetLantern(f, side * 9, 420, side > 0)
	end
end

------------------------------------------------------------------------------
-- Keeper's shrine, north gate, NPC houses, paddies, grove, backdrop
------------------------------------------------------------------------------

local function buildKeeperShrine(f: Folders)
	local k = V.keeperShrine
	-- On the inner lawn, front (and torii) toward the avenue (west).
	local cf = CFrame.new(k.x, 0, k.z) * CFrame.Angles(0, math.pi / 2, 0)
	local house = Kit.Gassho(f, cf * CFrame.new(0, 0, 4), { width = 16, depth = 13, wallHeight = 6.5, roofHeight = 10, eave = 3, windowRows = 1 })
	house.Name = "KeeperShrine"
	local toriiAt = cf * CFrame.new(0, 0, -10)
	ShrineCourtyard.Torii(f.decor, toriiAt, 5, 10)
	for _, side in { -1, 1 } do
		local pillar = Kit.Part(f.solid, "ToriiPillarProxy", Vector3.new(1.2, 10, 1.2), toriiAt * CFrame.new(side * 5, FLOOR_Y + 5, 0), P.ToriiRed, Enum.Material.Wood)
		pillar.Transparency = 1
		local lp = (cf * CFrame.new(side * 6.5, 0, -2)).Position
		ShrineCourtyard.StoneLantern(f.decor, lp.X, lp.Z)
	end
	-- Stone path from the shrine torii west to the plaza edge.
	local from = (toriiAt * CFrame.new(0, 0, -2)).Position
	local dz = math.max(math.abs(from.Z - V.center.z) - (V.plazaHalfZ - V.plazaHalfX), 0)
	local plazaX = V.center.x + math.sqrt(math.max(V.plazaHalfX ^ 2 - dz * dz, 0))
	Kit.Strip(f.decor, "ShrinePath", { { x = from.X, z = from.Z }, { x = plazaX, z = from.Z } }, 2.5, 0.065, P.PathStone, Enum.Material.Slate)
	local sign = Kit.Part(f.decor, "KeeperSign", Vector3.new(0.5, 0.5, 0.5), cf * CFrame.new(0, FLOOR_Y + 13, 0), P.Amber, Enum.Material.Neon)
	sign.Transparency = 1
	Kit.Label(sign, "ศาลผู้ดูแล", 0, 90)
	table.insert(blockers, { k.x, k.z, 16 })
end

local function buildNorthGate(f: Folders)
	-- Where the north road leaves the village: a torii roped off for now
	-- (the road to a later zone).
	local last = V.roads[4].points[2]
	local at = CFrame.new(last.x, 0, last.z - 8)
	local half = V.roadHalfWidth + 2
	ShrineCourtyard.Torii(f.decor, at, half, 11)
	for _, side in { -1, 1 } do
		local pillar = Kit.Part(f.solid, "ToriiPillarProxy", Vector3.new(1.2, 11, 1.2), at * CFrame.new(side * half, FLOOR_Y + 5.5, 0), P.ToriiRed, Enum.Material.Wood)
		pillar.Transparency = 1
	end
	Kit.Part(f.decor, "Shimenawa", Vector3.new(half * 2, 0.6, 0.6), at * CFrame.new(0, FLOOR_Y + 3.4, 0), P.Rope, Enum.Material.Fabric, "Cylinder")
	for i = -2, 2 do
		Kit.Part(f.decor, "Shide", Vector3.new(0.6, 1.4, 0.05), at * CFrame.new(i * 2.4, FLOOR_Y + 2.4, 0), P.Paper, Enum.Material.SmoothPlastic)
	end
	local sign = Kit.Part(f.decor, "NorthGateSign", Vector3.new(0.5, 0.5, 0.5), at * CFrame.new(0, FLOOR_Y + 14, 0), P.Amber, Enum.Material.Neon)
	sign.Transparency = 1
	Kit.Label(sign, "ทางขึ้นเขา (ยังไม่เปิด)", 0, 90)
	table.insert(blockers, { at.Position.X, at.Position.Z, half + 3 })
end

local function npcHouse(f: Folders, rng: Random, cf: CFrame)
	local w = rng:NextNumber(17, 21)
	Kit.Gassho(f, cf, {
		width = w,
		depth = rng:NextNumber(14, 18),
		wallHeight = rng:NextNumber(6.5, 8),
		roofHeight = w * rng:NextNumber(0.75, 0.9),
		eave = 3,
	})
end

local function buildNpcHouses(f: Folders, rng: Random)
	-- Each faces the middle line of the village at its own Z (toward the
	-- fork or the north road).
	for _, h in V.npcHouses do
		npcHouse(f, rng, facing(h.x, h.z, V.center.x, h.z))
		table.insert(blockers, { h.x, h.z, 15 })
	end
end

local function buildPaddies(f: Folders, rng: Random)
	-- Harvested terraces on the east, stepping up away from the village.
	-- Solid so nobody walks through a step.
	local pd = V.paddies
	local steps = 4
	local stepW = (pd.maxX - pd.minX) / steps
	for step = 0, steps - 1 do
		local x = pd.minX + stepW * (step + 0.5)
		local h = 0.6 + step * 0.9
		for z = pd.minZ + 11, pd.maxZ - 11, 22 do
			local zz = z + rng:NextNumber(-1, 1)
			Kit.Part(f.solid, "Terrace", Vector3.new(stepW, h, 20), CFrame.new(x, FLOOR_Y + h / 2 - 0.1, zz), P.PaddyRidge, Enum.Material.Ground)
			Kit.Slab(f.decor, "Stubble", stepW - 1, 19, h + 0.02, x, zz, Kit.Jitter(rng, P.Stubble, 0.08), Enum.Material.Grass)
			if rng:NextNumber() < 0.25 then
				Kit.Part(f.decor, "RiceRack", Vector3.new(0.6, 2.4, 12), CFrame.new(x, FLOOR_Y + h + 1.6, zz), P.Stubble, Enum.Material.Grass)
			end
		end
	end
	-- A farmhouse at the paddies' edge.
	local cf = CFrame.new(pd.minX - 6, 0, pd.minZ - 12) * CFrame.Angles(0, math.pi / 2, 0)
	npcHouse(f, rng, cf)
	table.insert(blockers, { pd.minX - 6, pd.minZ - 12, 15 })
	table.insert(blockers, { (pd.minX + pd.maxX) / 2, (pd.minZ + pd.maxZ) / 2, 0 })
end

local function inPaddies(x: number, z: number, margin: number): boolean
	local pd = V.paddies
	return x > pd.minX - margin and x < pd.maxX + margin and z > pd.minZ - margin and z < pd.maxZ + margin
end

local function buildGrove(f: Folders, rng: Random)
	-- Maple and cedar grove to the west with a fenced cottage on its village side.
	local g = V.grove
	local cottage = CFrame.lookAt(Vector3.new(Village.GroveCottageX(), 0, g.z), CENTER)
	npcHouse(f, rng, cottage)
	table.insert(blockers, { cottage.Position.X, cottage.Position.Z, 18 })
	-- Fence ring with a gap at the front (local -Z, toward the village).
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		if math.sin(a) > -0.9 then
			local p = cottage * CFrame.new(math.cos(a) * 17, 0, math.sin(a) * 17)
			Kit.Part(f.solid, "Fence", Vector3.new(0.5, 1.6, 13), CFrame.lookAt(p.Position, cottage.Position) * CFrame.new(0, FLOOR_Y + 0.8, 0) * CFrame.Angles(0, math.pi / 2, 0), P.HouseWood, Enum.Material.Wood)
		end
	end
	local placed = 0
	for _ = 1, 120 do
		if placed >= 34 then
			break
		end
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, g.radius)
		local x, z = g.x + math.cos(a) * d, g.z + math.sin(a) * d
		if math.abs(x) < V.maxX - 6 and clear(x, z, 4) then
			table.insert(blockers, { x, z, 3 })
			if rng:NextNumber() < 0.6 then
				Kit.Maple(f, rng, x, z, rng:NextNumber(1, 1.4))
			else
				Kit.Cedar(f, rng, x, z, rng:NextNumber(1.1, 1.5))
			end
			placed += 1
		end
	end
end

local function buildTrees(f: Folders, rng: Random)
	-- Maples scattered behind the houses and round the corners, clear of the
	-- plots, the roads, the lawns between the roads and the paddies.
	local placed = 0
	for _ = 1, 1400 do
		if placed >= 90 then
			break
		end
		local x = rng:NextNumber(V.minX + 6, V.maxX - 6)
		local z = rng:NextNumber(V.minZ + 6, V.maxZ - 20)
		local scale = rng:NextNumber(1.2, 1.7)
		local between = math.sqrt((x - V.center.x) ^ 2 + (z - V.center.z) ^ 2) < V.roadRadius + 8
		if not between and isOpen(x, z, 5 * scale) and not inPaddies(x, z, 6) then
			table.insert(blockers, { x, z, 4 * scale })
			Kit.Maple(f, rng, x, z, scale)
			placed += 1
		end
	end
	-- Cedar slope along the far (north) edge, leaving the north road open,
	-- and along the outer east/west edges.
	for _ = 1, 140 do
		local x = rng:NextNumber(V.minX + 4, V.maxX - 4)
		if math.abs(x) > V.roadHalfWidth + 8 then
			Kit.Cedar(f, rng, x, rng:NextNumber(V.maxZ - 12, V.maxZ + 34), rng:NextNumber(1.2, 1.9))
		end
	end
	for _, side in { -1, 1 } do
		for _ = 1, 50 do
			Kit.Cedar(f, rng, side * rng:NextNumber(V.maxX + 2, V.maxX + 30), rng:NextNumber(V.minZ, V.maxZ), rng:NextNumber(1.2, 1.8))
		end
	end
	local north, mid = V.maxZ + 150, V.center.z
	for _, h in { { -220, north + 20, 380, 110 }, { 190, north, 400, 125 }, { -480, mid, 300, 90 }, { 480, mid, 300, 100 } } do
		Kit.Part(f.decor, "Hill", Vector3.new(h[3], h[4] * 2, h[3] * 0.7), CFrame.new(h[1], FLOOR_Y - 6, h[2]), P.Hill, Enum.Material.Grass, "Ball")
	end
end

------------------------------------------------------------------------------
-- House plots
------------------------------------------------------------------------------

-- Fenced plot with an open gate toward the road (local -Z). The big front
-- yard is where captured spirits will float (later milestone); flower beds
-- and shrubs line the front corners and sides so it never looks bare.
local function buildPlot(f: Folders, rng: Random, plotsFolder: Instance, index: number, plot: PlotDef): Model
	local cf = Village.PlotFrame(plot)
	local sx, sz = V.plotSize.x, V.plotSize.z
	local m = Kit.Model(plotsFolder, "Plot" .. index)
	m:SetAttribute("PlotIndex", index)
	m:SetAttribute("OwnerUserId", 0)
	local base = Kit.Part(m, "PlotGround", Vector3.new(sx, 0.2, sz), cf * CFrame.new(0, FLOOR_Y + 0.05, 0), P.GrassDark, Enum.Material.Grass)
	base.CanCollide = false
	base.CanQuery = false
	local fence = Kit.Folder(f.solid, "PlotFence" .. index)
	local function rail(len: number, at: CFrame)
		Kit.Part(fence, "Fence", Vector3.new(len, 1.6, 0.4), at * CFrame.new(0, FLOOR_Y + 0.8, 0), P.HouseWood, Enum.Material.Wood)
	end
	rail(sx, cf * CFrame.new(0, 0, sz / 2))
	rail(sz, cf * CFrame.new(-sx / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0))
	rail(sz, cf * CFrame.new(sx / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0))
	for _, side in { -1, 1 } do
		rail(sx / 2 - GATE_HALF, cf * CFrame.new(side * (sx / 4 + GATE_HALF / 2), 0, -sz / 2))
		Kit.Part(fence, "GatePost", Vector3.new(0.9, 4.4, 0.9), cf * CFrame.new(side * GATE_HALF, FLOOR_Y + 2.2, -sz / 2), P.HouseWoodDark, Enum.Material.Wood)
	end
	-- A maple in a back corner of every plot, like the sketch.
	for _, side in { -1, 1 } do
		local corner = cf * CFrame.new(side * (sx / 2 - 7), 0, sz / 2 - 7)
		Kit.Maple(f, rng, corner.Position.X, corner.Position.Z, 1.7)
	end
	-- Front garden, outside the spirit yard's circle: a flower bed in each
	-- front corner, shrubs flanking the gate and along the front half of the
	-- side fences.
	for _, side in { -1, 1 } do
		local bed = cf * CFrame.new(side * (sx / 2 - 8), 0, -(sz / 2 - 7))
		Kit.Part(f.decor, "FlowerBed", Vector3.new(11, 0.4, 8), bed * CFrame.new(0, FLOOR_Y + 0.2, 0), P.PaddyRidge, Enum.Material.Ground)
		for _ = 1, 7 do
			local fl = bed * CFrame.new(rng:NextNumber(-4.4, 4.4), 0, rng:NextNumber(-3, 3))
			local s = rng:NextNumber(1, 1.6)
			Kit.Part(f.decor, "Flowers", Vector3.new(s, s * 0.7, s), fl * CFrame.new(0, FLOOR_Y + 0.6, 0), FLOWERS[rng:NextInteger(1, #FLOWERS)], Enum.Material.Grass, "Ball")
		end
		local gateShrub = cf * CFrame.new(side * (GATE_HALF + 6), 0, -(sz / 2 - 2.5))
		Kit.Part(f.decor, "Shrub", Vector3.new(3, 2.2, 3), gateShrub * CFrame.new(0, FLOOR_Y + 1, 0), Kit.Jitter(rng, P.Fern, 0.12), Enum.Material.Grass, "Ball")
		for _, z in { -30, -18, -6 } do
			local shrub = cf * CFrame.new(side * (sx / 2 - 3.5), 0, z)
			local s = rng:NextNumber(2.6, 3.4)
			local color = if rng:NextNumber() < 0.35 then P.MapleRed else P.Fern
			Kit.Part(f.decor, "Shrub", Vector3.new(s, s * 0.75, s), shrub * CFrame.new(0, FLOOR_Y + s * 0.3, 0), Kit.Jitter(rng, color, 0.12), Enum.Material.Grass, "Ball")
		end
	end
	Kit.Folder(m, "Locked")
	Kit.Folder(m, "Owned")
	return m
end

-- Free plot: rope across the gate with paper streamers, foundation stones
-- and a "free" label.
function Village.BuildPlotLocked(plotModel: Model, plot: PlotDef)
	local holder = plotModel:FindFirstChild("Locked") :: Instance
	holder:ClearAllChildren()
	local cf = Village.PlotFrame(plot)
	local sz = V.plotSize.z
	-- Cylinder axis is local X, which runs across the gate.
	Kit.Part(holder, "Shimenawa", Vector3.new(GATE_HALF * 2, 0.6, 0.6), cf * CFrame.new(0, FLOOR_Y + 3.6, -sz / 2), P.Rope, Enum.Material.Fabric, "Cylinder")
	for i = -2, 2 do
		Kit.Part(holder, "Shide", Vector3.new(0.6, 1.4, 0.05), cf * CFrame.new(i * 2.6, FLOOR_Y + 2.6, -sz / 2), P.Paper, Enum.Material.SmoothPlastic)
	end
	for _, c in { { -11, 16 }, { 11, 16 }, { -11, 30 }, { 11, 30 } } do
		Kit.Part(holder, "Foundation", Vector3.new(2.4, 0.8, 2.4), cf * CFrame.new(c[1], FLOOR_Y + 0.3, c[2]), P.Stone, Enum.Material.Slate)
	end
	-- Stepping stones from the gate to the foundation (the spirit yard
	-- covers this ground once the plot is taken).
	for i = 0, 7 do
		local z = -sz / 2 + 4 + i * 7
		Kit.Part(holder, "SteppingStone", Vector3.new(3.2, 0.25, 2.4), cf * CFrame.new(if i % 2 == 0 then -0.8 else 0.8, FLOOR_Y + 0.12, z), P.PathStone, Enum.Material.Slate)
	end
	local sign = Kit.Part(holder, "FreeSign", Vector3.new(0.4, 0.4, 0.4), cf * CFrame.new(0, FLOOR_Y + 6.5, -sz / 2), P.Amber, Enum.Material.Neon)
	sign.Transparency = 1
	Kit.Label(sign, "ที่ว่าง", 0, 90)
	local owned = plotModel:FindFirstChild("Owned") :: Instance
	owned:ClearAllChildren()
end

-- Owned plot: a starter gasshō house at the back, a lit gate lantern, and a
-- wide spirit yard in front with empty perches for captured spirits (later).
function Village.BuildPlotHouse(plotModel: Model, plot: PlotDef, ownerName: string)
	local owned = plotModel:FindFirstChild("Owned") :: Instance
	owned:ClearAllChildren()
	local locked = plotModel:FindFirstChild("Locked") :: Instance
	locked:ClearAllChildren()
	local cf = Village.PlotFrame(plot)
	local sz = V.plotSize.z
	local solid = Kit.Folder(owned, "Collision")
	local decor = Kit.Folder(owned, "Decor")
	local f = { solid = solid, decor = decor }
	Kit.Gassho(f, cf * CFrame.new(0, 0, sz / 2 - 17), { width = 26, depth = 20, wallHeight = 8, roofHeight = 19, eave = 3.5 })
	-- Spirit yard: a wide stone ring (room for a large boss spirit) with
	-- perches round the inside, empty until capture.
	local yard = cf * CFrame.new(0, FLOOR_Y, -13)
	local yr = YARD_RADIUS
	Kit.Part(decor, "SpiritYard", Vector3.new(0.2, yr * 2, yr * 2), yard * CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Grass, Enum.Material.Grass, "Cylinder")
	for i = 0, 39 do
		local a = i / 40 * math.pi * 2
		Kit.Part(decor, "YardStone", Vector3.new(1.6, 0.7, 1.6), yard * CFrame.new(math.cos(a) * yr, 0.35, math.sin(a) * yr), P.Stone, Enum.Material.Slate)
	end
	-- Ten perches round the ring, one per showcased spirit.
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2 + math.pi / 10
		local perch = yard * CFrame.new(math.cos(a) * (yr - 8), 0, math.sin(a) * (yr - 8))
		Kit.Part(decor, "SpiritPerch", Vector3.new(3.2, 1.6, 3.2), perch * CFrame.new(0, 0.8, 0), P.StoneDark, Enum.Material.Slate)
		Kit.Part(decor, "SpiritPerchTop", Vector3.new(0.2, 2.8, 2.8), perch * CFrame.new(0, 1.65, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Paper, Enum.Material.SmoothPlastic, "Cylinder")
	end
	-- Centre dais for the biggest spirit (a captured boss).
	Kit.Part(decor, "BossDais", Vector3.new(0.6, 16, 16), yard * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), P.StoneDark, Enum.Material.Slate, "Cylinder")
	local lamp = Kit.Part(decor, "GateLantern", Vector3.new(1.8, 1.4, 1.4), cf * CFrame.new(GATE_HALF, FLOOR_Y + 5, -sz / 2) * CFrame.Angles(0, 0, math.rad(90)), P.Amber, Enum.Material.Neon, "Cylinder")
	Kit.Glow(lamp, 1.2, 14, true)
	local sign = Kit.Part(decor, "OwnerSign", Vector3.new(0.4, 0.4, 0.4), cf * CFrame.new(0, FLOOR_Y + 6.5, -sz / 2), P.Amber, Enum.Material.Neon)
	sign.Transparency = 1
	Kit.Label(sign, "บ้านของ " .. ownerName, 0, 100)
end

------------------------------------------------------------------------------

-- Builds the static village into `region` (Collision/Decor/Markers/Plots
-- folders) and returns the plot models in World.Village.plots order.
function Village.Build(region: Instance): { Model }
	local rng = Random.new(SEED)
	table.clear(blockers)
	local f = { solid = region:FindFirstChild("Collision") :: Instance, decor = region:FindFirstChild("Decor") :: Instance }
	buildGround(f, rng)
	buildSacredTree(f, rng)
	buildPlazaLanterns(f)
	buildStalls(f, rng)
	local plotsFolder = Kit.Folder(region, "Plots")
	local plots = {}
	for i, plot in V.plots do
		table.insert(blockers, { plot.x, plot.z, math.sqrt((V.plotSize.x / 2) ^ 2 + (V.plotSize.z / 2) ^ 2) })
		local m = buildPlot(f, rng, plotsFolder, i, plot)
		Village.BuildPlotLocked(m, plot)
		table.insert(plots, m)
	end
	buildStreetLanterns(f)
	buildPond(f, rng)
	buildLawns(f, rng)
	buildKeeperShrine(f)
	buildNorthGate(f)
	buildNpcHouses(f, rng)
	buildPaddies(f, rng)
	buildGrove(f, rng)
	buildTrees(f, rng)
	return plots
end

return Village

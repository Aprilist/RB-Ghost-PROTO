--!strict
-- World layout and clock (M2-B). One place, three regions along the Z axis:
--   courtyard (boss arena, the VB-01 shrine, origin)  z ≈ -50 .. 50
--   mistwood  (forest path, hunting area)             z ≈  50 .. 350
--   village   (Last Lantern Village, safe hub)        z ≈ 350 .. 1250
-- Ground top everywhere is Prototype.Arena.FloorTopY. Positions are X/Z
-- pairs in studs. Visual detail lives in Scene/; only layout numbers that
-- gameplay or tests read are here.

export type XZ = { x: number, z: number }
-- `angle` is the way the plot's gate faces, in degrees: 0 = south (-Z,
-- toward the forest), 90 = east (+X), 180 = north, 270 = west.
export type Plot = { x: number, z: number, angle: number }
export type Road = { name: string, points: { XZ }, halfWidth: number }
export type Island = { id: string, x: number, z: number }

-- Director 27 Oct 2026: yards big enough to show a large boss spirit.
-- Room for about ten large spirits in each yard, sized down 1.5x from
-- 120x140 so walks stay short (Director 27 Oct 2026).
-- Village redrawn from the Director's third picture (27 Oct 2026): a sacred
-- tree plaza in the middle and three house islands round it, one south and
-- two north. Each island is four plots in a 2x2 grid facing a shared lawn
-- with a big tree, and a ring road round the outside. Roads link the plaza
-- to the islands; a river with footbridges runs down the east side and a
-- great tree shrine sits outside the south-west corner. 12 houses = 12
-- players per server.
local PLAZA = { x = 0, z = 797 }
local PLOT_SIZE = { x = 80, z = 94 } -- x across the front, z deep
local ISLAND_RING = { x = 104, z = 130 } -- ring road centre line, from the island centre
local PLOT_AT = { x = 50, z = 69 } -- plot centres from the island centre
local PLAZA_RING_RADIUS = 62
local ROAD_HALF = 5
local ISLANDS: { Island } = {
	{ id = "south", x = 0, z = 565 },
	{ id = "east", x = 135, z = 1045 },
	{ id = "west", x = -135, z = 1045 },
}
local RIVER_HALF = 8
local BRIDGES = { 565, 797, 1045 } -- river crossings (Z)

local function riverX(z: number): number
	return 285 + 8 * math.sin(z / 55)
end

local function xz(x: number, z: number): XZ
	return table.freeze({ x = x, z = z })
end

-- Plots are numbered island by island, the south island first, so the first
-- players get the houses nearest the spawn. Rows facing the lawn: the north
-- row looks south (angle 0), the south row looks north (angle 180).
local plots: { Plot } = {}
for _, island in ISLANDS do
	for _, slot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
		table.insert(plots, table.freeze({
			x = island.x + slot[1] * PLOT_AT.x,
			z = island.z + slot[2] * PLOT_AT.z,
			angle = if slot[2] > 0 then 0 else 180,
		}))
	end
end

-- Closed rectangle with corners cut by `c`, as a polyline.
local function rectRing(cx: number, cz: number, hx: number, hz: number, c: number): { XZ }
	return {
		xz(cx - hx + c, cz - hz), xz(cx + hx - c, cz - hz), xz(cx + hx, cz - hz + c), xz(cx + hx, cz + hz - c),
		xz(cx + hx - c, cz + hz), xz(cx - hx + c, cz + hz), xz(cx - hx, cz + hz - c), xz(cx - hx, cz - hz + c),
		xz(cx - hx + c, cz - hz),
	}
end

-- Closed circle as a polyline; the first point is due south.
local function circleRing(cx: number, cz: number, r: number, n: number): { XZ }
	local pts = {}
	for i = 0, n do
		local a = i / n * math.pi * 2
		table.insert(pts, xz(cx + math.sin(a) * r, cz - math.cos(a) * r))
	end
	return pts
end

-- Every walkable strip in the village; tests keep solids off all of them.
local roads: { Road } = {
	-- Forest torii up to the south island's ring.
	{ name = "Entrance", points = { xz(0, 350), xz(0, 435) }, halfWidth = ROAD_HALF },
	-- South island to the plaza (the spawn square is on this road).
	{ name = "SpawnRoad", points = { xz(0, 695), xz(0, 735) }, halfWidth = 4 },
	{ name = "PlazaRing", points = circleRing(PLAZA.x, PLAZA.z, PLAZA_RING_RADIUS, 24), halfWidth = ROAD_HALF },
	-- North road: from the plaza between the two north islands to the north gate.
	{ name = "NorthRoad", points = { xz(0, 859), xz(0, 1235) }, halfWidth = ROAD_HALF },
	-- Footbridge paths across the river (east) and the path to the great tree shrine (west).
	{ name = "BridgeSouth", points = { xz(104, 565), xz(335, 565) }, halfWidth = 3 },
	{ name = "BridgeMid", points = { xz(190, 797), xz(335, 797) }, halfWidth = 3 },
	{ name = "BridgeNorth", points = { xz(239, 1045), xz(335, 1045) }, halfWidth = 3 },
	{ name = "ShrinePath", points = { xz(-104, 500), xz(-226, 500) }, halfWidth = 3 },
}
for _, island in ISLANDS do
	table.insert(roads, { name = "Ring_" .. island.id, points = rectRing(island.x, island.z, ISLAND_RING.x, ISLAND_RING.z, 10), halfWidth = ROAD_HALF })
end
for _, side in { -1, 1 } do
	-- Plaza ring to each north island's near corner.
	table.insert(roads, { name = "PlazaLink", points = { xz(side * 20.3, 855.5), xz(side * 41, 915) }, halfWidth = 4 })
	-- South island's side up past the plaza to the north islands (the loop).
	table.insert(roads, { name = "SideLink", points = { xz(side * 104, 630), xz(side * 150, 700), xz(side * 190, 780), xz(side * 190, 915) }, halfWidth = 4 })
	-- Shortcut straight across from the plaza ring to the side link.
	table.insert(roads, { name = "PlazaLane", points = { xz(side * 67, 797), xz(side * 190, 797) }, halfWidth = 3 })
end
for _, r in roads do
	table.freeze(r.points)
	table.freeze(r)
end

local river: { XZ } = {}
for z = 345, 1255, 30 do
	table.insert(river, xz(riverX(z), z))
end

return table.freeze({
	-- Opening in the courtyard's south bound for the sandō from the forest.
	CourtyardGateHalfWidth = 6,
	RiverX = riverX,

	Mistwood = table.freeze({
		minX = -100,
		maxX = 100,
		minZ = 50,
		maxZ = 350,
		-- Narrow walled corridor from the gate through the courtyard's bamboo ring.
		corridorHalfWidth = 9,
		corridorEndZ = 124,
		pathHalfWidth = 4,
		-- Path centre line, gate → village.
		path = table.freeze({
			{ x = 0, z = 50 },
			{ x = 0, z = 124 },
			{ x = -26, z = 168 },
			{ x = -30, z = 214 },
			{ x = 18, z = 262 },
			{ x = 22, z = 304 },
			{ x = 0, z = 350 },
		}),
		checkpoint = { x = 0, z = 336 }, -- mistwood_gate, at the village end
		-- M2-C enemy spawns (Enemies catalog IDs). Weakest near the village,
		-- where players enter the forest; the umbrella spirit near the courtyard.
		enemySpawns = table.freeze({
			{ x = -52, z = 176, enemy = "karakasa" },
			{ x = -4, z = 206, enemy = "karakasa" },
			{ x = -60, z = 236, enemy = "kodama" },
			{ x = 46, z = 246, enemy = "kodama" },
			{ x = 50, z = 292, enemy = "hitodama" },
			{ x = -12, z = 284, enemy = "hitodama" },
		}),
		-- M2-D q03 pickups (veil traces), each inside an enemy spawn clearing,
		-- which the tree scatter keeps clear for 11 studs round the spawn.
		veilTraces = table.freeze({
			{ x = -48, z = 172 }, -- karakasa clearing by the first bend
			{ x = -56, z = 240 }, -- west kodama clearing
			{ x = 40, z = 242 }, -- east kodama clearing, away from the fallen log
		}),
	}),

	Village = table.freeze({
		minX = -360,
		maxX = 360,
		minZ = 350,
		maxZ = 1250,
		-- `center` is the plaza. Walking in from the forest (+Z): the river
		-- and paddies are on the left (+X), the great tree shrine on the
		-- right (-X), as in the picture.
		center = PLAZA,
		treeTrunkRadius = 7,
		plazaRadius = 50, -- stone circle under the tree
		plazaRingRadius = PLAZA_RING_RADIUS, -- ring road centre line
		stallRadius = 30, -- stall centres round the tree
		roadHalfWidth = ROAD_HALF,
		roads = table.freeze(roads),
		plotSize = PLOT_SIZE, -- x across the front, z deep
		islands = table.freeze(ISLANDS),
		islandRing = ISLAND_RING,
		plotAt = PLOT_AT,
		spawn = { x = 0, z = 715 },
		checkpoint = { x = 0, z = 715 }, -- village_shrine, the square between the south island and the plaza
		keeperShrine = { x = -244, z = 500 }, -- great tree shrine, faces east toward its path
		northGate = { x = 0, z = 1225 }, -- roped torii where the north road leaves the village
		ponds = table.freeze({
			{ x = -112, z = 762, radius = 13 },
			{ x = 112, z = 762, radius = 13 },
		}),
		river = table.freeze({ points = table.freeze(river), halfWidth = RIVER_HALF, bridges = table.freeze(BRIDGES) }),
		-- Stalls round the tree, angle in degrees (0 = south, 90 = east).
		stalls = table.freeze({
			{ id = "shop", angle = 135 },
			{ id = "smith", angle = 225 },
			{ id = "talisman", angle = 315 },
			{ id = "teahouse", angle = 45 },
		}),
		-- One plot per player slot (Project.TargetPlayersPerServer).
		plots = table.freeze(plots),
		-- Two cottages flanking the entrance road.
		npcHouses = table.freeze({ xz(-95, 385), xz(95, 385) }),
		-- Terraces on the far bank, in two blocks so the middle bridge path runs between.
		paddies = table.freeze({
			{ minX = 308, maxX = 352, minZ = 600, maxZ = 760 },
			{ minX = 308, maxX = 352, minZ = 835, maxZ = 1005 },
		}),
		farmhouse = xz(332, 505),
	}),

	Clock = table.freeze({
		-- Director 27 Oct 2026: a season lasts 2 real hours, 10 in-game days.
		DaySec = 720,
		DaysPerSeason = 10,
		Seasons = table.freeze({ "autumn", "winter", "spring", "summer" }),
		SeasonNamesTH = table.freeze({
			autumn = "ฤดูใบไม้แดง",
			winter = "ฤดูหิมะ",
			spring = "ฤดูซากุระ",
			summer = "ฤดูนาเขียว",
		}),
		-- Unix time of day 1, 00:00, autumn (27 Oct 2026 00:00 UTC). Every server
		-- derives the same clock from real time, so all servers share a season.
		EpochUnix = 1793059200,
		-- Seasons with built visuals; others fall back to the first one.
		BuiltSeasons = table.freeze({ autumn = true }),
		LightingStepSec = 0.5,
	}),
})

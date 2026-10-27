--!strict
-- World layout and clock (M2-B). One place, three regions along the Z axis:
--   courtyard (boss arena, the VB-01 shrine, origin)  z ≈ -50 .. 50
--   mistwood  (forest path, hunting area)             z ≈  50 .. 350
--   village   (Last Lantern Village, safe hub)        z ≈ 350 .. 850
-- Ground top everywhere is Prototype.Arena.FloorTopY. Positions are X/Z
-- pairs in studs. Visual detail lives in Scene/; only layout numbers that
-- gameplay or tests read are here.

export type XZ = { x: number, z: number }
-- `angle` is the way the plot's gate faces, in degrees: 0 = south (-Z,
-- toward the forest), 90 = east (+X), 270 = west.
export type Plot = { x: number, z: number, angle: number }
export type Road = { name: string, points: { XZ }, halfWidth: number }

-- Director 27 Oct 2026: yards big enough to show a large boss spirit.
-- Village redrawn 27 Oct 2026 (Director: too big, and the back-row houses
-- were hidden): one ring of 12 houses round the plaza, all facing in on the
-- same ring road, so every house is seen the same from the middle. Plots
-- shrunk from 80x94 to 64x80 so the ring stays small.
-- 12 houses = 12 players per server.
local VILLAGE_CENTER = { x = 0, z = 590 }
local PLOT_SIZE = { x = 64, z = 80 } -- x across the front (along the road), z deep
local ROAD_R = 136 -- ring road centre line, radius from the village centre
local ROAD_HALF = 5
local VERGE = 5 -- grass between the ring road edge and the plot fences
local PLOT_FRONT_R = ROAD_R + ROAD_HALF + VERGE
local PLAZA_HALF_X, PLAZA_HALF_Z = 44, 56

-- Same angle convention as Plot.angle: 0 = south (-Z), 90 = east (+X).
local function onRing(angle: number, r: number): (number, number)
	local a = math.rad(angle)
	return VILLAGE_CENTER.x + math.sin(a) * r, VILLAGE_CENTER.z - math.cos(a) * r
end

-- Plots sit at 15° + 30°k round the ring, leaving gaps due south (entrance)
-- and due north (north road). Plot 1 is the one a lone player gets, so the
-- lowest numbers sit nearest the entrance and alternate east/west.
local plots: { Plot } = {}
for _, a in { 15, 345, 45, 315, 75, 285, 105, 255, 135, 225, 165, 195 } do
	local x, z = onRing(a, PLOT_FRONT_R + PLOT_SIZE.z / 2)
	-- Gate faces the village centre.
	table.insert(plots, table.freeze({ x = x, z = z, angle = (a + 180) % 360 }))
end

local function xz(x: number, z: number): XZ
	return table.freeze({ x = x, z = z })
end

local ring: { XZ } = {}
for a = 0, 360, 15 do
	table.insert(ring, xz(onRing(a % 360, ROAD_R)))
end
local south, north = VILLAGE_CENTER.z - ROAD_R, VILLAGE_CENTER.z + ROAD_R

-- Every walkable strip in the village; tests keep solids off all of them.
-- NorthRoad stays 4th: Scene/Village puts the north gate at its end.
local roads: { Road } = {
	-- Forest torii up to the ring road, through the gap between plots 1 and 2.
	{ name = "Entrance", points = { xz(0, 350), xz(0, south) }, halfWidth = ROAD_HALF },
	{ name = "RingRoad", points = ring, halfWidth = ROAD_HALF },
	-- Stone avenue ring road → spawn → plaza.
	{ name = "Avenue", points = { xz(0, south), xz(0, VILLAGE_CENTER.z - PLAZA_HALF_Z) }, halfWidth = 3.5 },
	-- North road out of the village (ends at a closed torii for now).
	{ name = "NorthRoad", points = { xz(0, north), xz(0, 840) }, halfWidth = ROAD_HALF },
	-- Paved walks from the ring road to the plaza: north, east, west.
	{ name = "PlazaWalk", points = { xz(0, north), xz(0, VILLAGE_CENTER.z + PLAZA_HALF_Z) }, halfWidth = 3 },
}
for _, side in { -1, 1 } do
	table.insert(roads, { name = "PlazaWalk", points = { xz(side * ROAD_R, VILLAGE_CENTER.z), xz(side * PLAZA_HALF_X, VILLAGE_CENTER.z) }, halfWidth = 3 })
end
for _, r in roads do
	table.freeze(r.points)
	table.freeze(r)
end

return table.freeze({
	-- Opening in the courtyard's south bound for the sandō from the forest.
	CourtyardGateHalfWidth = 6,

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
		minX = -280,
		maxX = 280,
		minZ = 350,
		maxZ = 850,
		-- Round village: plaza in the middle, lawns, the ring road, then the
		-- ring of houses. Walking in from the forest (+Z): paddies on the left
		-- (+X), grove top right (-X), the keeper's shrine on the inner lawn
		-- to the left of the avenue.
		center = VILLAGE_CENTER,
		treeTrunkRadius = 7,
		-- Stone plaza under the tree: a stadium (oval) shape, half-widths from `center`.
		plazaHalfX = PLAZA_HALF_X,
		plazaHalfZ = PLAZA_HALF_Z,
		stallRadius = 30, -- stall centres round the tree
		roadRadius = ROAD_R,
		roadHalfWidth = ROAD_HALF,
		roads = table.freeze(roads),
		vergeWidth = VERGE, -- grass between the ring road edge and the plot fences
		plotSize = PLOT_SIZE, -- x across the front, z deep
		spawn = { x = 0, z = 496 },
		checkpoint = { x = 0, z = 496 }, -- village_shrine, lawn just south of the plaza
		keeperShrine = { x = 90, z = 540 }, -- inner lawn, faces west to the avenue
		pond = { x = -60, z = 660, radius = 15 }, -- garden pond on the north-west lawn
		-- Stalls round the tree, angle in degrees (0 = south, 90 = east).
		stalls = table.freeze({
			{ id = "shop", angle = 135 },
			{ id = "smith", angle = 225 },
			{ id = "talisman", angle = 315 },
			{ id = "teahouse", angle = 45 },
		}),
		-- One plot per player slot (Project.TargetPlayersPerServer): one ring
		-- round the ring road, gates facing the plaza.
		plots = table.freeze(plots),
		-- NPC houses outside the ring: the corners and the west side.
		npcHouses = table.freeze({
			xz(-200, 390),
			xz(200, 390),
			xz(200, 800),
			xz(-255, 590),
		}),
		paddies = { minX = 240, maxX = 275, minZ = 470, maxZ = 710 },
		grove = { x = -200, z = 800, radius = 35 }, -- north-west corner
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

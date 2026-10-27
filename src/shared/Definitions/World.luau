--!strict
-- World layout and clock (M2-B). One place, three regions along the Z axis:
--   courtyard (boss arena, the VB-01 shrine, origin)  z ≈ -50 .. 50
--   mistwood  (forest path, hunting area)             z ≈  50 .. 350
--   village   (Last Lantern Village, safe hub)        z ≈ 350 .. 1040
-- Ground top everywhere is Prototype.Arena.FloorTopY. Positions are X/Z
-- pairs in studs. Visual detail lives in Scene/; only layout numbers that
-- gameplay or tests read are here.

export type XZ = { x: number, z: number }
-- `angle` is the way the plot's gate faces, in degrees: 0 = south (-Z,
-- toward the forest), 90 = east (+X), 270 = west.
export type Plot = { x: number, z: number, angle: number }
export type Road = { name: string, points: { XZ }, halfWidth: number }

-- Director 27 Oct 2026: yards big enough to show a large boss spirit.
-- Room for about ten large spirits in each yard, sized down 1.5x from
-- 120x140 so walks stay short (Director 27 Oct 2026).
-- Village redrawn from the Director's second sketch (27 Oct 2026): a long
-- oval village 1.5x the old area, a plaza in the middle, a straight road down
-- each long side and six houses along the outside of each road, all facing
-- in. 12 houses = 12 players per server.
local VILLAGE_CENTER = { x = 0, z = 700 }
local PLOT_SIZE = { x = 80, z = 94 } -- x across the front (along the road), z deep
local ROAD_X = 70 -- side road centre lines at x = ±ROAD_X
local ROAD_HALF = 5
local PLOT_FRONT_X = 80 -- front fence of every plot, |x|
local PLOT_ROWS = { 655, 745, 565, 835, 475, 925 } -- plot centres along Z, nearest the plaza first
local LANE_Z = { 565, 835 } -- cross lanes between the side roads, in line with plot gates

-- Plot 1 is the one a lone player gets, so the lowest numbers sit nearest
-- the plaza and alternate west/east.
local plots: { Plot } = {}
for _, z in PLOT_ROWS do
	for _, side in { -1, 1 } do
		local x = side * (PLOT_FRONT_X + PLOT_SIZE.z / 2)
		table.insert(plots, table.freeze({ x = x, z = z, angle = if side < 0 then 90 else 270 }))
	end
end

local function xz(x: number, z: number): XZ
	return table.freeze({ x = x, z = z })
end

-- Every walkable strip in the village; tests keep solids off all of them.
local roads: { Road } = {
	-- Forest torii up to the fork.
	{ name = "Entrance", points = { xz(0, 350), xz(0, 420) }, halfWidth = ROAD_HALF },
	-- The two long roads: out from the fork, straight up the sides, back in
	-- to meet the north road (the Y of the sketch at both ends).
	{ name = "WestRoad", points = { xz(0, 420), xz(-ROAD_X, 472), xz(-ROAD_X, 928), xz(0, 984) }, halfWidth = ROAD_HALF },
	{ name = "EastRoad", points = { xz(0, 420), xz(ROAD_X, 472), xz(ROAD_X, 928), xz(0, 984) }, halfWidth = ROAD_HALF },
	-- North road out of the village (ends at a closed torii for now).
	{ name = "NorthRoad", points = { xz(0, 984), xz(0, 1036) }, halfWidth = ROAD_HALF },
	-- Shortcuts: the stone avenue fork → spawn → plaza, and two lanes across.
	{ name = "Avenue", points = { xz(0, 420), xz(0, 624) }, halfWidth = 3.5 },
}
for i, z in LANE_Z do
	table.insert(roads, { name = "Lane" .. i, points = { xz(-ROAD_X, z), xz(ROAD_X, z) }, halfWidth = 3 })
end
for _, side in { -1, 1 } do
	table.insert(roads, { name = "PlazaWalk", points = { xz(side * ROAD_X, VILLAGE_CENTER.z), xz(side * 44, VILLAGE_CENTER.z) }, halfWidth = 3 })
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
	}),

	Village = table.freeze({
		minX = -330,
		maxX = 330,
		minZ = 350,
		maxZ = 1040,
		-- Oval village (Director sketch 2, 27 Oct 2026). Walking in from the
		-- forest (+Z): paddies on the left (+X), grove on the right (-X), the
		-- keeper's shrine outside the bottom-left corner, as in the sketch.
		center = VILLAGE_CENTER,
		treeTrunkRadius = 7,
		-- Stone plaza under the tree: a stadium (oval) shape, half-widths from `center`.
		plazaHalfX = 44,
		plazaHalfZ = 76,
		stallRadius = 30, -- stall centres round the tree
		roadX = ROAD_X,
		roadHalfWidth = ROAD_HALF,
		laneZ = table.freeze(LANE_Z),
		roads = table.freeze(roads),
		plotFrontX = PLOT_FRONT_X, -- front fence of every plot, |x|
		plotSize = PLOT_SIZE, -- x across the front, z deep
		spawn = { x = 0, z = 596 },
		checkpoint = { x = 0, z = 596 }, -- village_shrine, lawn just south of the plaza
		keeperShrine = { x = 200, z = 396 }, -- outside the bottom-left corner, faces west to the fork
		pond = { x = 0, z = 862, radius = 15 }, -- garden pond on the north lawn
		-- Stalls round the tree, angle in degrees (0 = south, 90 = east).
		stalls = table.freeze({
			{ id = "shop", angle = 135 },
			{ id = "smith", angle = 225 },
			{ id = "talisman", angle = 315 },
			{ id = "teahouse", angle = 45 },
		}),
		-- One plot per player slot (Project.TargetPlayersPerServer): six along
		-- the outside of each side road, gates facing the road.
		plots = table.freeze(plots),
		-- NPC houses at the four corners, by the fork and the north road.
		npcHouses = table.freeze({
			xz(-124, 400),
			xz(-206, 412),
			xz(-118, 1004),
			xz(118, 1004),
		}),
		paddies = { minX = 255, maxX = 320, minZ = 480, maxZ = 920 },
		grove = { x = -272, z = 700, radius = 42 },
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

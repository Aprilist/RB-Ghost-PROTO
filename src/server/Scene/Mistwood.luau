--!strict
-- M2-B greybox of Mistwood (ป่าม่านหมอก): the forest between the village and
-- the shrine courtyard (now the boss arena). A narrow walled corridor leaves
-- the courtyard's south gate through its bamboo ring, then a winding path
-- runs through cedar, bamboo and a few autumn maples to the village gate.
-- Trees are solid trunks so the path reads as the way through. Enemy spawn
-- markers (M2-C) name their catalog enemy with attribute EnemyType.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Definitions.World)
local Kit = require(script.Parent.Kit)
local ShrineCourtyard = require(script.Parent.ShrineCourtyard)

local M = World.Mistwood
local P = Kit.Palette
local FLOOR_Y = Kit.FloorY
local SEED = 20261103

type Folders = Kit.Folders

local Mistwood = {}

-- Distance from (x, z) to the path centre line.
function Mistwood.DistanceToPath(x: number, z: number): number
	local best = math.huge
	for i = 1, #M.path - 1 do
		local a, b = M.path[i], M.path[i + 1]
		local abx, abz = b.x - a.x, b.z - a.z
		local t = math.clamp(((x - a.x) * abx + (z - a.z) * abz) / (abx * abx + abz * abz), 0, 1)
		local dx, dz = x - (a.x + abx * t), z - (a.z + abz * t)
		best = math.min(best, math.sqrt(dx * dx + dz * dz))
	end
	return best
end

local function nearSpawn(x: number, z: number, r: number): boolean
	for _, s in M.enemySpawns do
		if (x - s.x) ^ 2 + (z - s.z) ^ 2 < r * r then
			return true
		end
	end
	return false
end

local function buildGround(f: Folders, rng: Random)
	local cw = M.corridorHalfWidth
	-- Corridor ground (gate → end of the bamboo ring) and the forest floor.
	Kit.Part(f.solid, "Ground", Vector3.new(cw * 2, 2, M.corridorEndZ - M.minZ), CFrame.new(0, FLOOR_Y - 1, (M.minZ + M.corridorEndZ) / 2), P.GrassDark, Enum.Material.Grass)
	Kit.Part(f.solid, "Ground", Vector3.new(M.maxX - M.minX, 2, M.maxZ - M.corridorEndZ), CFrame.new((M.minX + M.maxX) / 2, FLOOR_Y - 1, (M.corridorEndZ + M.maxZ) / 2), P.GrassDark, Enum.Material.Grass)
	-- Leaf litter patches.
	for _ = 1, 60 do
		Kit.Slab(f.decor, "LeafLitter", rng:NextNumber(5, 12), rng:NextNumber(4, 10), 0.03, rng:NextNumber(M.minX + 6, M.maxX - 6), rng:NextNumber(M.corridorEndZ + 4, M.maxZ - 4), Kit.Jitter(rng, P.Leaves, 0.15), Enum.Material.Grass, rng:NextNumber(0, math.pi))
	end
	-- Path: dirt with a flagstone strip in the corridor (continues the sandō).
	Kit.Strip(f.decor, "Path", M.path, M.pathHalfWidth, 0.06, P.PathDirt, Enum.Material.Ground)
	Kit.Strip(f.decor, "Sando", { M.path[1], M.path[2] }, 3, 0.08, P.PathStone, Enum.Material.Slate)
end

local function buildBounds(f: Folders)
	-- Corridor walls from the courtyard gate to the forest proper.
	local cw = M.corridorHalfWidth
	local len = M.corridorEndZ - M.minZ
	local h = 30
	for _, side in { -1, 1 } do
		local wall = Kit.Part(f.solid, "CorridorBound", Vector3.new(1, h, len), CFrame.new(side * (cw + 0.5), FLOOR_Y + h / 2, M.minZ + len / 2), P.Stone, Enum.Material.Slate)
		wall.Transparency = 1
	end
	-- Low hedges to show the corridor edge (decor; the bounds above stop players).
	for z = M.minZ + 4, M.corridorEndZ, 4 do
		for _, side in { -1, 1 } do
			Kit.Part(f.decor, "Hedge", Vector3.new(2.4, 2.2, 3.6), CFrame.new(side * (cw - 0.4), FLOOR_Y + 1, z), P.Fern, Enum.Material.Grass, "Ball")
		end
	end
end

local function buildTrees(f: Folders, rng: Random)
	-- Trees fill the forest proper, clear of the path and the spawn clearings.
	local placed = 0
	for _ = 1, 900 do
		if placed >= 170 then
			break
		end
		local x = rng:NextNumber(M.minX + 3, M.maxX - 3)
		local z = rng:NextNumber(M.corridorEndZ + 4, M.maxZ - 6)
		local d = Mistwood.DistanceToPath(x, z)
		if d > M.pathHalfWidth + 4 and not nearSpawn(x, z, 11) then
			local roll = rng:NextNumber()
			if roll < 0.62 then
				Kit.Cedar(f, rng, x, z, rng:NextNumber(1, 1.7))
			elseif roll < 0.85 then
				Kit.Bamboo(f, rng, x, z)
			else
				Kit.Maple(f, rng, x, z, rng:NextNumber(0.9, 1.2))
			end
			placed += 1
		end
	end
	-- Ferns and shrubs along the path edges.
	for _ = 1, 120 do
		local x = rng:NextNumber(M.minX + 3, M.maxX - 3)
		local z = rng:NextNumber(M.corridorEndZ, M.maxZ - 4)
		local d = Mistwood.DistanceToPath(x, z)
		if d > M.pathHalfWidth + 0.5 and d < M.pathHalfWidth + 9 then
			local s = rng:NextNumber(1.6, 3)
			Kit.Part(f.decor, "Fern", Vector3.new(s * 1.4, s * 0.7, s * 1.2), CFrame.new(x, FLOOR_Y + s * 0.25, z), Kit.Jitter(rng, P.Fern, 0.15), Enum.Material.Grass, "Ball")
		end
	end
end

local function buildLandmarks(f: Folders, rng: Random)
	-- Lanterns every ~45 studs along the path, alternating sides.
	local walked, nextAt, i = 0, 30, 0
	for k = 1, #M.path - 1 do
		local a, b = M.path[k], M.path[k + 1]
		local dx, dz = b.x - a.x, b.z - a.z
		local len = math.sqrt(dx * dx + dz * dz)
		while nextAt <= walked + len do
			local t = (nextAt - walked) / len
			i += 1
			local side = if i % 2 == 0 then 1 else -1
			-- Perpendicular offset to the path edge.
			local px, pz = -dz / len * side, dx / len * side
			local x, z = a.x + dx * t + px * (M.pathHalfWidth + 1.5), a.z + dz * t + pz * (M.pathHalfWidth + 1.5)
			if z > 90 then -- keep the camera band beside the courtyard flat
				Kit.StreetLantern(f, x, z, i % 2 == 0)
			end
			nextAt += 45
		end
		walked += len
	end
	-- Jizō statues at the first bend: a quiet landmark.
	local bend = M.path[3]
	for j = 0, 2 do
		local x, z = bend.x - 8 + j * 1.8, bend.z - 3
		Kit.Part(f.solid, "JizoBody", Vector3.new(1.2, 1.8, 1), CFrame.new(x, FLOOR_Y + 0.9, z), P.Stone, Enum.Material.Slate)
		Kit.Part(f.decor, "JizoHead", Vector3.new(0.9, 0.9, 0.9), CFrame.new(x, FLOOR_Y + 2.2, z), P.Stone, Enum.Material.Slate, "Ball")
		Kit.Part(f.decor, "JizoBib", Vector3.new(1.1, 0.6, 0.15), CFrame.new(x, FLOOR_Y + 1.5, z - 0.5), P.ToriiRed, Enum.Material.Fabric)
	end
	-- Fallen log across a clearing edge.
	local log = M.enemySpawns[4]
	Kit.Part(f.solid, "FallenLog", Vector3.new(12, 1.6, 1.6), CFrame.new(log.x + 10, FLOOR_Y + 0.8, log.z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), P.CedarTrunk, Enum.Material.Wood, "Cylinder")
	-- Village gate: a weathered torii where the path leaves the forest.
	local a, b = M.path[#M.path - 1], M.path[#M.path]
	local gz = M.maxZ - 8
	local gx = a.x + (b.x - a.x) * (gz - a.z) / (b.z - a.z) -- on the path centre line
	local span = M.pathHalfWidth + 2.5
	ShrineCourtyard.Torii(f.decor, CFrame.new(gx, 0, gz) * CFrame.Angles(0, math.pi, 0), span, 9)
	for _, side in { -1, 1 } do
		local proxy = Kit.Part(f.solid, "ToriiPillarProxy", Vector3.new(1.2, 9, 1.2), CFrame.new(gx + side * span, FLOOR_Y + 4.5, gz), P.ToriiRed, Enum.Material.Wood)
		proxy.Transparency = 1
	end
end

-- Spawn and checkpoint markers (SpawnLocation is non-colliding).
local function buildMarkers(markers: Instance)
	local cp = Instance.new("SpawnLocation")
	cp.Name = "MistwoodGate"
	cp.Size = Vector3.new(6, 0.2, 6)
	cp.CFrame = CFrame.new(M.checkpoint.x, FLOOR_Y + 0.1, M.checkpoint.z)
	cp.Anchored = true
	cp.Neutral = true
	cp.Duration = 0
	cp.Color = P.Amber
	cp.Material = Enum.Material.Neon
	cp.Transparency = 0.5
	cp.CanCollide = false
	cp:SetAttribute("CheckpointId", "mistwood_gate")
	game:GetService("CollectionService"):AddTag(cp, "Checkpoint")
	cp.Parent = markers
	for i, s in M.enemySpawns do
		local m = Instance.new("Part")
		m.Name = "EnemySpawn" .. i
		m.Size = Vector3.new(2, 0.2, 2)
		m.CFrame = CFrame.new(s.x, FLOOR_Y + 0.1, s.z)
		m.Anchored = true
		m.CanCollide = false
		m.CanQuery = false
		m.CanTouch = false
		m.Transparency = 1
		m:SetAttribute("EnemySpawnId", "mistwood_" .. i)
		m:SetAttribute("EnemyType", s.enemy)
		game:GetService("CollectionService"):AddTag(m, "EnemySpawn")
		m.Parent = markers
	end
end

function Mistwood.Build(region: Instance)
	local rng = Random.new(SEED)
	local f = { solid = region:FindFirstChild("Collision") :: Instance, decor = region:FindFirstChild("Decor") :: Instance }
	buildGround(f, rng)
	buildBounds(f)
	buildTrees(f, rng)
	buildLandmarks(f, rng)
	buildMarkers(region:FindFirstChild("Markers") :: Instance)
end

return Mistwood

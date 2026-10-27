--!strict
-- M2-B: builds the regions around the courtyard under
-- <WorldNamespace>/Regions/{Mistwood,Village}, each with Collision, Decor and
-- Markers folders, plus the outer world bounds and far ground. Called by
-- SceneService.Build so one rebuild makes the whole place.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Definitions.World)
local Kit = require(script.Parent.Kit)
local Mistwood = require(script.Parent.Mistwood)
local Village = require(script.Parent.Village)

local FLOOR_Y = Kit.FloorY
local M, V = World.Mistwood, World.Village
local BOUND_HEIGHT = 40

local Regions = {}

local function region(parent: Instance, name: string): Instance
	local r = Kit.Folder(parent, name)
	Kit.Folder(r, "Collision")
	Kit.Folder(r, "Decor")
	Kit.Folder(r, "Markers")
	return r
end

-- Invisible wall from (x0, z0) to (x1, z1), axis-aligned.
local function bound(parent: Instance, name: string, x0: number, z0: number, x1: number, z1: number)
	local alongX = z0 == z1
	local len = if alongX then math.abs(x1 - x0) else math.abs(z1 - z0)
	local size = if alongX then Vector3.new(len, BOUND_HEIGHT, 1) else Vector3.new(1, BOUND_HEIGHT, len)
	local wall = Kit.Part(parent, name, size, CFrame.new((x0 + x1) / 2, FLOOR_Y + BOUND_HEIGHT / 2, (z0 + z1) / 2), Kit.Palette.Stone, Enum.Material.Slate)
	wall.Transparency = 1
end

local function buildBounds(world: Instance)
	local c = Kit.Folder(world, "Collision")
	-- Mistwood: sides, and the edge facing the courtyard's bamboo ring.
	bound(c, "MistwoodWest", M.minX - 0.5, M.corridorEndZ, M.minX - 0.5, M.maxZ)
	bound(c, "MistwoodEast", M.maxX + 0.5, M.corridorEndZ, M.maxX + 0.5, M.maxZ)
	bound(c, "MistwoodNorthWest", M.minX, M.corridorEndZ - 0.5, -M.corridorHalfWidth, M.corridorEndZ - 0.5)
	bound(c, "MistwoodNorthEast", M.corridorHalfWidth, M.corridorEndZ - 0.5, M.maxX, M.corridorEndZ - 0.5)
	-- Village: sides, far end, and the shoulders where it is wider than the forest.
	bound(c, "VillageWest", V.minX - 0.5, V.minZ, V.minX - 0.5, V.maxZ)
	bound(c, "VillageEast", V.maxX + 0.5, V.minZ, V.maxX + 0.5, V.maxZ)
	bound(c, "VillageSouth", V.minX, V.maxZ + 0.5, V.maxX, V.maxZ + 0.5)
	bound(c, "VillageNorthWest", V.minX, V.minZ - 0.5, M.minX, V.minZ - 0.5)
	bound(c, "VillageNorthEast", M.maxX, V.minZ - 0.5, V.maxX, V.minZ - 0.5)
end

local function villageSpawn(markers: Instance)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "VillageSpawn"
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.CFrame = CFrame.new(V.spawn.x, FLOOR_Y + 0.1, V.spawn.z)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Kit.Palette.Amber
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.5
	spawn.CanCollide = false
	spawn:SetAttribute("SpawnId", "village_start")
	-- Also the village checkpoint: walking back here makes it the respawn point.
	spawn:SetAttribute("CheckpointId", "village_shrine")
	CollectionService:AddTag(spawn, "Checkpoint")
	spawn.Parent = markers
end

function Regions.Build(root: Instance)
	local world = Kit.Folder(root, "Regions")
	-- Far ground under the backdrop beyond the courtyard's own outer ground.
	local far = Kit.Folder(world, "Decor")
	Kit.Part(far, "FarGround", Vector3.new(1200, 2, 1000), CFrame.new(0, FLOOR_Y - 1.15, 750), Kit.Palette.Hill, Enum.Material.Grass)
	buildBounds(world)
	Mistwood.Build(region(world, "Mistwood"))
	local village = region(world, "Village")
	Village.Build(village)
	villageSpawn(village:FindFirstChild("Markers") :: Instance)
end

return Regions

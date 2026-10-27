--!strict
-- P1 player setup: spawn at the prototype arena, respawn at the last touched
-- checkpoint, standard third-person camera with geometry occlusion (Zoom mode).
-- HP/gauge/cooldown state lives in PlayerStateService.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local VisualPalette = require(ReplicatedStorage.Shared.Definitions.VisualPalette)

type SceneService = {
	GetSpawn: () -> SpawnLocation?,
}

local PlayerService = {}

local scene: SceneService

type Shape = "Block" | "Cylinder" | "Wedge"

-- One welded, visual-only piece (no collision/query/touch, massless).
local function weldedPiece(
	model: Model,
	anchor: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Shape?
): BasePart
	local part: BasePart
	if shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local block = Instance.new("Part")
		if shape == "Cylinder" then
			block.Shape = Enum.PartType.Cylinder
		end
		part = block
	end
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.CFrame = anchor.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

-- VB-01 benchmark katana: visual only, welded to the hand. Hits are computed by
-- CombatService from the root part, never from these parts. The blade runs
-- along the hand's -Z with the edge on -Y, as in the P1 placeholder.
local function attachKatana(character: Model)
	local hand = (character:WaitForChild("RightHand", 5) or character:FindFirstChild("Right Arm")) :: BasePart?
	if not hand or character:FindFirstChild("Katana") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Katana"
	model:SetAttribute("Placeholder", true)
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Shape?)
		weldedPiece(model, hand, name, size, CFrame.new(0, -0.3, 0) * offset, color, material, shape)
	end
	local alongZ = CFrame.Angles(0, math.rad(90), 0) -- cylinders run along local X

	-- Hilt: wrapped grip, gold menuki, iron pommel.
	piece("Kashira", Vector3.new(0.3, 0.32, 0.12), CFrame.new(0, 0, 0.29), VisualPalette.Iron, Enum.Material.Metal)
	piece("Tsuka", Vector3.new(0.24, 0.3, 1.1), CFrame.new(0, 0, -0.3), VisualPalette.Wrap, Enum.Material.Fabric)
	for i = 0, 3 do
		piece("Ito", Vector3.new(0.26, 0.32, 0.07), CFrame.new(0, 0, 0.12 - i * 0.28) * CFrame.Angles(0, 0, math.rad(45)), VisualPalette.Wrap:Lerp(Color3.new(1, 1, 1), 0.18), Enum.Material.Fabric)
	end
	piece("Menuki", Vector3.new(0.27, 0.1, 0.22), CFrame.new(0, 0, -0.3), VisualPalette.Gold, Enum.Material.Metal)

	-- Guard and collar.
	piece("Tsuba", Vector3.new(0.08, 0.78, 0.78), CFrame.new(0, 0, -0.9) * alongZ, VisualPalette.Iron, Enum.Material.Metal, "Cylinder")
	piece("Seppa", Vector3.new(0.05, 0.56, 0.56), CFrame.new(0, 0, -0.96) * alongZ, VisualPalette.Gold, Enum.Material.Metal, "Cylinder")
	piece("Habaki", Vector3.new(0.13, 0.32, 0.16), CFrame.new(0, -0.01, -1.06), VisualPalette.Gold, Enum.Material.Metal)

	-- Blade: two segments with a slight curve toward the spine (+Y), a pale
	-- edge line that stays readable at dusk, and a wedge tip.
	local bladeH = 0.28
	piece("Blade", Vector3.new(0.07, bladeH, 1.8), CFrame.new(0, 0, -2.04), VisualPalette.Steel, Enum.Material.Metal)
	piece("Hamon", Vector3.new(0.075, 0.06, 1.8), CFrame.new(0, -bladeH / 2 + 0.03, -2.04), VisualPalette.SteelEdge, Enum.Material.Neon)
	local upper = CFrame.new(0, 0, -2.94) * CFrame.Angles(math.rad(-4), 0, 0)
	piece("Blade", Vector3.new(0.07, bladeH, 1.5), upper * CFrame.new(0, 0, -0.75), VisualPalette.Steel, Enum.Material.Metal)
	piece("Hamon", Vector3.new(0.075, 0.06, 1.5), upper * CFrame.new(0, -bladeH / 2 + 0.03, -0.75), VisualPalette.SteelEdge, Enum.Material.Neon)
	-- WedgePart is full height at local +Z and tapers toward -Z; rolled 180°
	-- so the edge (-Y) sweeps up to a point in line with the spine.
	piece("Kissaki", Vector3.new(0.07, bladeH, 0.42), upper * CFrame.new(0, 0, -1.71) * CFrame.Angles(0, 0, math.pi), VisualPalette.Steel, Enum.Material.Metal, "Wedge")
	model.Parent = character

	-- Empty scabbard on the left hip: hilt end forward, tip back and down.
	local hip = (character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if hip and not character:FindFirstChild("Saya") then
		local saya = Instance.new("Model")
		saya.Name = "Saya"
		saya:SetAttribute("Placeholder", true)
		local at = CFrame.new(-hip.Size.X / 2 - 0.15, -0.1, 0.45) * CFrame.Angles(math.rad(22), 0, 0)
		weldedPiece(saya, hip, "Scabbard", Vector3.new(0.2, 0.36, 3.6), at, VisualPalette.Lacquer, Enum.Material.SmoothPlastic)
		weldedPiece(saya, hip, "Koiguchi", Vector3.new(0.24, 0.4, 0.16), at * CFrame.new(0, 0, -1.74), VisualPalette.Gold, Enum.Material.Metal)
		weldedPiece(saya, hip, "Kojiri", Vector3.new(0.24, 0.4, 0.14), at * CFrame.new(0, 0, 1.74), VisualPalette.Iron, Enum.Material.Metal)
		weldedPiece(saya, hip, "Sageo", Vector3.new(0.26, 0.42, 0.1), at * CFrame.new(0, 0, -1.3), VisualPalette.Cord, Enum.Material.Fabric)
		saya.Parent = character
	end
end

local function setupPlayer(player: Player)
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = Prototype.Camera.MinZoomStuds
	player.CameraMaxZoomDistance = Prototype.Camera.MaxZoomStuds
	player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom

	local spawn = scene.GetSpawn()
	if spawn then
		player.RespawnLocation = spawn
	end

	player.CharacterAdded:Connect(attachKatana)
	if player.Character then
		-- Joined before the arena existed (e.g. Play Solo race): move them in.
		player:LoadCharacter()
	end
end

local function bindCheckpoint(checkpoint: Instance)
	if not checkpoint:IsA("SpawnLocation") then
		return
	end
	-- SpawnLocation is non-colliding, so touch is detected by the character's feet passing through it.
	checkpoint.CanTouch = true
	checkpoint.Touched:Connect(function(hit: BasePart)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if player and player.RespawnLocation ~= checkpoint then
			player.RespawnLocation = checkpoint
		end
	end)
end

function PlayerService.Init(deps: { SceneService: SceneService })
	scene = deps.SceneService
end

function PlayerService.Start()
	Players.RespawnTime = Prototype.Player.RespawnSec

	for _, checkpoint in CollectionService:GetTagged("Checkpoint") do
		bindCheckpoint(checkpoint)
	end
	CollectionService:GetInstanceAddedSignal("Checkpoint"):Connect(bindCheckpoint)

	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end

return PlayerService

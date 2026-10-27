--!strict
-- Quest props in the world (M2-D): the village NPCs (Definitions/Npcs) and
-- the q03 veil traces in Mistwood (World.Mistwood.veilTraces). Readable
-- greybox figures, no polish. Each has a ProximityPrompt (key F, so it never
-- clashes with E = skill); the server re-checks range and alive before
-- handing the talk or pickup to QuestService. Built in their own folder
-- under the scene root, outside Regions, so the layout tests and part
-- budgets of the regions are unchanged. Nothing here collides.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Definitions.Classes)
local Npcs = require(ReplicatedStorage.Shared.Definitions.Npcs)
local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local World = require(ReplicatedStorage.Shared.Definitions.World)
local Kit = require(script.Parent.Parent.Scene.Kit)
local SealRules = require(script.Parent.Parent.Util.SealRules)

type Quests = {
	Talk: (Player, string, number?) -> (),
	CollectTrace: (Player, number) -> (),
	InRange: (Player, Npcs.NpcDef, number) -> boolean,
}

type PlayerState = {
	IsAlive: (Player) -> boolean,
	GetRoot: (Player) -> BasePart?,
}

type Seals = {
	OpenMenu: (Player) -> (),
}

type ClassMenu = {
	OpenMenu: (Player) -> (),
}

local NpcService = {}

NpcService.NpcTag = "SpiritWardNpc"
NpcService.TraceTag = "SpiritWardVeilTrace"
NpcService.FolderName = "QuestWorld"

local TALK_COOLDOWN_SEC = 0.4
local TRACE_RANGE_STUDS = 8
local SKIN = Color3.fromRGB(232, 196, 160)
local TRACE_BLUE = Color3.fromRGB(140, 210, 255)

local quests: Quests
local playerState: PlayerState
local seals: Seals
local classes: ClassMenu
local lastUse: { [Player]: number } = {}

local function prompt(holder: BasePart, action: string, object: string, range: number): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = Enum.KeyCode.F
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.HoldDuration = 0
	p.MaxActivationDistance = range
	p.RequiresLineOfSight = false
	p.Parent = holder
	return p
end

-- Drops prompt spam: one use per player per TALK_COOLDOWN_SEC.
local function allow(player: Player): boolean
	local now = os.clock()
	if now - (lastUse[player] or 0) < TALK_COOLDOWN_SEC then
		return false
	end
	lastUse[player] = now
	return true
end

-- Standing figure about 5.5 studs tall: robe, sash, head, straw hat.
local function buildNpc(parent: Instance, npc: Npcs.NpcDef): Model
	local m = Kit.Model(parent, npc.id)
	local a = math.rad(npc.angle)
	-- Ground frame whose front (local -Z) points along the NPC's angle.
	local base = CFrame.lookAt(Vector3.new(npc.x, 0, npc.z), Vector3.new(npc.x + math.sin(a), 0, npc.z - math.cos(a)))
	local y = Kit.FloorY
	Kit.Part(m, "Robe", Vector3.new(2.2, 3.6, 1.4), base * CFrame.new(0, y + 1.8, 0), npc.robeColor, Enum.Material.Fabric)
	Kit.Part(m, "Sash", Vector3.new(2.3, 0.4, 1.5), base * CFrame.new(0, y + 2.6, 0), Kit.Palette.HouseWoodDark, Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		Kit.Part(m, "Sleeve", Vector3.new(0.8, 2.2, 1.2), base * CFrame.new(side * 1.45, y + 2.4, 0), npc.robeColor, Enum.Material.Fabric)
	end
	local head = Kit.Part(m, "Head", Vector3.new(1.3, 1.3, 1.3), base * CFrame.new(0, y + 4.3, 0), SKIN, Enum.Material.SmoothPlastic, "Ball")
	-- Two dots so the facing reads from a distance.
	for _, side in { -1, 1 } do
		Kit.Part(m, "Eye", Vector3.new(0.16, 0.16, 0.05), base * CFrame.new(side * 0.25, y + 4.4, -0.64), Color3.fromRGB(30, 26, 24), Enum.Material.SmoothPlastic)
	end
	Kit.Part(m, "Hat", Vector3.new(0.3, 2.8, 2.8), base * CFrame.new(0, y + 5.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Kit.Palette.Thatch, Enum.Material.Grass, "Cylinder")
	m.PrimaryPart = head
	Kit.Label(head, npc.displayNameTH, 2.6, 60)
	m:SetAttribute("NpcId", npc.id)
	CollectionService:AddTag(m, NpcService.NpcTag)

	local action = if npc.id == SealRules.StationNpcId then "ผนึกดาบ" elseif npc.id == Classes.StationNpcId then "อาชีพ" else "คุย"
	local p = prompt(head, action, npc.displayNameTH, npc.talkRangeStuds)
	p.Triggered:Connect(function(player)
		if allow(player) and quests.InRange(player, npc, 2) then
			if npc.id == SealRules.StationNpcId then
				-- The smith's stall is the seal station (M2-E): menu instead of chat.
				seals.OpenMenu(player)
			elseif npc.id == Classes.StationNpcId then
				classes.OpenMenu(player)
			else
				quests.Talk(player, npc.id)
			end
		end
	end)
	return m
end

-- Glowing shard floating at chest height, with a soft light.
local function buildTrace(parent: Instance, index: number, at: { x: number, z: number })
	local shard = Kit.Part(parent, "VeilTrace" .. index, Vector3.new(0.8, 1.8, 0.8), CFrame.new(at.x, Kit.FloorY + 2.6, at.z) * CFrame.Angles(math.rad(20), math.rad(35), math.rad(15)), TRACE_BLUE, Enum.Material.Neon)
	shard.Transparency = 0.15
	local light = Instance.new("PointLight")
	light.Color = TRACE_BLUE
	light.Brightness = 1.5
	light.Range = 10
	light.Shadows = false
	light.Parent = shard
	shard:SetAttribute("VeilTraceIndex", index)
	CollectionService:AddTag(shard, NpcService.TraceTag)
	local center = Vector3.new(at.x, 0, at.z)
	local p = prompt(shard, "เก็บ", "เศษม่าน", TRACE_RANGE_STUDS)
	p.Triggered:Connect(function(player)
		if not allow(player) or not playerState.IsAlive(player) then
			return
		end
		local root = playerState.GetRoot(player)
		if root and (Vector3.new(root.Position.X, 0, root.Position.Z) - center).Magnitude <= TRACE_RANGE_STUDS + 2 then
			quests.CollectTrace(player, index)
		end
	end)
end

function NpcService.Build(): Folder?
	local root = workspace:FindFirstChild(Prototype.WorldNamespace)
	if not root then
		warn("[NpcService] scene root missing; NPCs not built")
		return nil
	end
	local old = root:FindFirstChild(NpcService.FolderName)
	if old then
		old:Destroy()
	end
	local folder = Kit.Folder(root, NpcService.FolderName)
	local npcFolder = Kit.Folder(folder, "Npcs")
	for _, npc in Npcs do
		buildNpc(npcFolder, npc)
	end
	local traceFolder = Kit.Folder(folder, "VeilTraces")
	for i, at in World.Mistwood.veilTraces do
		buildTrace(traceFolder, i, at)
	end
	return folder
end

function NpcService.Init(deps: { Quests: Quests, PlayerState: PlayerState, Seals: Seals, Classes: ClassMenu })
	quests = deps.Quests
	playerState = deps.PlayerState
	seals = deps.Seals
	classes = deps.Classes
end

function NpcService.Start()
	NpcService.Build()
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)
end

return NpcService

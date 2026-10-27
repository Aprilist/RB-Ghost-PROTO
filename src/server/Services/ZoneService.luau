--!strict
-- Zone volumes (M2-A). Builds one invisible, non-colliding box per catalog
-- volume under <WorldNamespace>/Zones (tag Zone, attribute ZoneId), so they
-- can be seen in Studio and never
-- touch Collision or Markers. ZoneAt answers which zone a point is in; reward
-- and (later) checkpoint, quest and encounter rules ask it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local Zones = require(ReplicatedStorage.Shared.Definitions.Zones)

local FOLDER_NAME = "Zones"
local TAG = "Zone"

local ZoneService = {}

local volumes: { BasePart } = {}

-- First zone whose box contains `position`, or nil outside every zone.
function ZoneService.ZoneAt(position: Vector3): string?
	for _, part in volumes do
		local offset = position - part.Position
		local half = part.Size / 2
		if math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z then
			return part:GetAttribute("ZoneId") :: string
		end
	end
	return nil
end

function ZoneService.Build()
	local root = workspace:FindFirstChild(Prototype.WorldNamespace)
	assert(root, "ZoneService needs the arena; start SceneService first")
	local old = root:FindFirstChild(FOLDER_NAME)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	table.clear(volumes)
	local ids = {}
	for id in Zones do
		table.insert(ids, id)
	end
	table.sort(ids) -- stable order for ZoneAt when boxes overlap
	for _, id in ids do
		for i, volume in Zones[id].volumes do
			local part = Instance.new("Part")
			part.Name = id .. "_" .. i
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Transparency = 1
			part.Size = volume.size
			part.CFrame = CFrame.new(volume.center)
			part:SetAttribute("ZoneId", id)
			CollectionService:AddTag(part, TAG)
			part.Parent = folder
			table.insert(volumes, part)
		end
	end
	folder.Parent = root
end

function ZoneService.Init() end

function ZoneService.Start()
	ZoneService.Build()
end

return ZoneService

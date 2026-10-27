--!strict
-- Guardian transform lifecycle: gauge check, timer, aura and mask.
-- Defeat rewards (gauge, essence, EXP, coins) moved to RewardService in M2-A.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)
local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local VisualPalette = require(ReplicatedStorage.Shared.Definitions.VisualPalette)

type ResultCode = Contracts.ResultCode

type Network = {
	Handle: (string, (Player, { [string]: any }) -> ResultCode) -> (),
	EmitFx: (string, Vector3, number?, string?) -> (),
}

type State = {
	alive: boolean,
	spiritGauge: number,
	transformEndsAt: number?,
}

type PlayerState = {
	Get: (Player) -> State?,
	IsAlive: (Player) -> boolean,
	GetRoot: (Player) -> BasePart?,
	Commit: (Player) -> (),
	OnDied: ((Player) -> ()) -> (),
}

local S = Prototype.Spirit
local AURA_NAME = "GuardianForm"
local MASK_NAME = "GuardianMask"

local SpiritService = {}

local network: Network
local playerState: PlayerState

local function isActive(state: State): boolean
	local endsAt = state.transformEndsAt
	return endsAt ~= nil and workspace:GetServerTimeNow() < endsAt
end

-- VB-01 guardian mask: a white half-mask with glowing indigo eye slits and a
-- brow mark, welded over the face. Visual only; hitbox and rig are unchanged.
local function attachMask(character: Model)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local mask = Instance.new("Model")
	mask.Name = MASK_NAME
	mask:SetAttribute("Placeholder", true)
	local front = head.Size.Z / 2
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = material
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Massless = true
		part.CFrame = head.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = part
		weld.Parent = part
		part.Parent = mask
	end
	piece("Plate", Vector3.new(head.Size.X * 0.92, head.Size.Y * 0.62, 0.12), CFrame.new(0, head.Size.Y * 0.12, -front - 0.04), VisualPalette.MaskWhite, Enum.Material.SmoothPlastic)
	for _, side in { -1, 1 } do
		piece("EyeSlit", Vector3.new(head.Size.X * 0.26, 0.1, 0.06), CFrame.new(side * head.Size.X * 0.2, head.Size.Y * 0.16, -front - 0.12) * CFrame.Angles(0, 0, math.rad(-12 * side)), VisualPalette.GuardianAura, Enum.Material.Neon)
		piece("Cheek", Vector3.new(0.08, head.Size.Y * 0.3, 0.06), CFrame.new(side * head.Size.X * 0.32, -head.Size.Y * 0.02, -front - 0.12), VisualPalette.GuardianMark, Enum.Material.Neon)
	end
	piece("BrowMark", Vector3.new(0.14, head.Size.Y * 0.22, 0.06), CFrame.new(0, head.Size.Y * 0.34, -front - 0.12), VisualPalette.GuardianMark, Enum.Material.Neon)
	mask.Parent = character
end

local function setAura(player: Player, on: boolean)
	local character = player.Character
	if not character then
		return
	end
	local existing = character:FindFirstChild(AURA_NAME)
	if existing then
		existing:Destroy()
	end
	local oldMask = character:FindFirstChild(MASK_NAME)
	if oldMask then
		oldMask:Destroy()
	end
	if not on then
		return
	end
	local aura = Instance.new("Highlight")
	aura.Name = AURA_NAME
	aura.FillColor = VisualPalette.GuardianAura
	aura.FillTransparency = 0.6
	aura.OutlineColor = VisualPalette.Guardian
	aura.DepthMode = Enum.HighlightDepthMode.Occluded
	aura.Parent = character
	attachMask(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		local light = Instance.new("PointLight")
		light.Name = AURA_NAME
		light.Color = aura.FillColor
		light.Range = 14
		light.Brightness = 2
		light.Parent = root
	end
end

local function clearAura(player: Player)
	setAura(player, false)
	local root = playerState.GetRoot(player)
	local light = root and root:FindFirstChild(AURA_NAME)
	if light then
		light:Destroy()
	end
end

local function transform(player: Player): ResultCode
	local state = playerState.Get(player)
	if not state or not playerState.IsAlive(player) then
		return "DEAD"
	end
	if isActive(state) or state.spiritGauge < S.GaugeMax then
		return "NOT_READY"
	end
	local endsAt = workspace:GetServerTimeNow() + S.TransformDurationSec
	state.spiritGauge = 0
	state.transformEndsAt = endsAt
	setAura(player, true)
	playerState.Commit(player)
	local root = playerState.GetRoot(player)
	if root then
		network.EmitFx("transform_start", root.Position, player.UserId, nil)
	end

	task.delay(S.TransformDurationSec, function()
		-- Only end this transform; death or a newer transform may have replaced it.
		if state.transformEndsAt ~= endsAt then
			return
		end
		state.transformEndsAt = nil
		clearAura(player)
		if player.Parent then
			playerState.Commit(player)
			local r = playerState.GetRoot(player)
			if r then
				network.EmitFx("transform_end", r.Position, player.UserId, nil)
			end
		end
	end)
	return "OK"
end

function SpiritService.Init(deps: { Network: Network, PlayerState: PlayerState })
	network = deps.Network
	playerState = deps.PlayerState
end

function SpiritService.Start()
	network.Handle("transform", function(player)
		return transform(player)
	end)
	-- PlayerStateService already zeroes gauge/transform on death; drop the visual too.
	playerState.OnDied(clearAura)
end

return SpiritService

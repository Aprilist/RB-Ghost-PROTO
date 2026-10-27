--!strict
-- Turns canonical actions into contract requests and plays the local swing,
-- sweep and dash immediately (visual prediction only). The server decides
-- hits and damage; this controller never reports targets.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Definitions.Classes)
local SkillRules = require(ReplicatedStorage.Shared.Util.SkillRules)
local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)
local Skills = require(ReplicatedStorage.Shared.Definitions.Skills)
local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)

type Network = {
	Send: (Contracts.ActionName, { [string]: any }) -> string?,
	OnResult: ((Contracts.ActionResult, string) -> ()) -> (),
	GetSnapshot: () -> Contracts.SnapshotEvent?,
}

type Camera = { GetAimDirection: (BasePart?) -> Vector3 }
type Effects = {
	PlaySwing: (BasePart, Vector3, number) -> (),
	PlaySweep: (BasePart, Vector3, number?) -> (),
	PlayDash: (BasePart) -> (),
	PlayWave: (BasePart, Vector3) -> (),
	PlayBolt: (BasePart, Vector3, number) -> (),
}
type Banner = { ShowAction: (string) -> () }

local C = Prototype.Combat
-- Seconds the dash force needs to reach full speed from rest.
local DASH_ACCEL_SEC = 0.03

local REJECT_TEXT: { [string]: string } = {
	COOLDOWN = "ยังติดคูลดาวน์",
	DEAD = "ตายอยู่ รอเกิดใหม่",
	RATE_LIMITED = "กดเร็วเกินไป",
	NOT_READY = "ยังไม่พร้อม",
	INVALID_PAYLOAD = "คำสั่งไม่ถูกต้อง",
	NOT_OWNED = "ไม่มีวิชานี้",
	SKILL_LOCKED = "ยังไม่ได้เรียนสกิลนี้",
	NO_SP = "SP ไม่พอ",
	INTERNAL_ERROR = "server ผิดพลาด",
}

local CombatController = {}

local network: Network
local camera: Camera
local effects: Effects
local banner: Banner

local comboStep = 0
local lastSwingAt = -math.huge
local predictedCooldowns: { [string]: number } = {}
-- requestId → skill id of each cast_skill sent, to undo its predicted cooldown.
local pendingCasts: { [string]: string } = {}

local function flat(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else nil
end

local function getRoot(): (BasePart?, Humanoid?)
	local character = (Players.LocalPlayer :: Player).Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?, humanoid
end

local function collisionParams(): RaycastParams?
	local root = workspace:FindFirstChild(Prototype.WorldNamespace)
	local collision = root and root:FindFirstChild("Collision")
	if not collision then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { collision }
	return params
end

-- Soft aim: turn toward the enemy closest to the camera aim inside the cone,
-- within reach, same height band and visible. Never extends reach.
local function softAim(root: BasePart, aim: Vector3, reach: number): Vector3
	local best, bestCos = aim, math.cos(math.rad(C.SoftAimConeDeg))
	local params = collisionParams()
	for _, model in CollectionService:GetTagged("Enemy") do
		if not model:IsA("Model") or model:GetAttribute("State") == "dead" then
			continue
		end
		local body = model.PrimaryPart
		if not body then
			continue
		end
		local offset = body.Position - root.Position
		if math.abs(offset.Y) > C.MaxHeightDiffStuds then
			continue
		end
		local dir = flat(offset)
		local dist = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if not dir or dist > reach + Prototype.Enemy.BodyRadiusStuds then
			continue
		end
		local cos = dir:Dot(aim)
		if cos > bestCos then
			if not params or workspace:Raycast(root.Position, offset, params) == nil then
				best, bestCos = dir, cos
			end
		end
	end
	return best
end

local function face(root: BasePart, dir: Vector3)
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
end

local function cooldownReady(key: string): boolean
	local now = workspace:GetServerTimeNow()
	local snapshot = network.GetSnapshot()
	local serverEnds = snapshot and snapshot.session.cooldowns[key]
	local predicted = predictedCooldowns[key]
	return (serverEnds == nil or now >= serverEnds) and (predicted == nil or now >= predicted)
end

local function isTransformed(): boolean
	local snapshot = network.GetSnapshot()
	local endsAt = snapshot and snapshot.session.transformEndsAt
	return endsAt ~= nil and workspace:GetServerTimeNow() < endsAt
end

-- The player's class numbers (M4); samurai until the first snapshot.
local function kit(): Classes.Kit
	local snapshot = network.GetSnapshot()
	return Classes.Kit(if snapshot then snapshot.profile.classId else Prototype.ClassId)
end

local function basicAttack()
	local root = getRoot()
	if not root then
		return
	end
	local k = kit()
	local now = os.clock()
	if now - lastSwingAt < k.basicIntervalSec then
		return -- local cadence; server enforces its own
	end
	comboStep = if now - lastSwingAt > C.ComboResetSec then 1 else comboStep % C.BasicComboSteps + 1
	lastSwingAt = now

	local transformed = isTransformed()
	local reach = if transformed then Prototype.Spirit.TransformAttackReachStuds else k.basicReachStuds
	local aim = softAim(root, camera.GetAimDirection(root), reach)
	face(root, aim)
	if transformed then
		effects.PlayWave(root, aim)
	elseif k.basicShape == "bolt" then
		effects.PlayBolt(root, aim, k.basicReachStuds)
	else
		effects.PlaySwing(root, aim, comboStep)
	end
	network.Send("basic_attack", { sequence = comboStep, aimDirection = aim })
end

local dashMotion: (BasePart, Vector3) -> ()

-- M4: hotbar slot 1–5 (E = slot 1). Checks lock, SP and cooldown locally
-- for a quick answer; the server decides.
local function castSkill(slot: number)
	local root = getRoot()
	local snapshot = network.GetSnapshot()
	if not root or not snapshot then
		return
	end
	local p = snapshot.profile
	local skillId = kit().skillIds[slot]
	local skill = skillId and Skills[skillId]
	if not skill then
		return
	end
	if SkillRules.CanCast(p, skill.id) ~= "OK" then
		banner.ShowAction(if p.level < skill.unlockLevel then string.format("%s ปลดที่ Lv %d", skill.displayNameTH, skill.unlockLevel) else skill.displayNameTH .. " ยังไม่ได้เรียน (กด K)")
		return
	end
	if not cooldownReady(skill.id) then
		banner.ShowAction(REJECT_TEXT.COOLDOWN)
		return
	end
	local s = snapshot.session
	if SkillRules.SpAt(s.sp, s.spAt, s.maxSp, workspace:GetServerTimeNow()) < skill.spCost then
		banner.ShowAction(REJECT_TEXT.NO_SP)
		return
	end
	predictedCooldowns[skill.id] = workspace:GetServerTimeNow() + skill.cooldownSec
	local aim = softAim(root, camera.GetAimDirection(root), math.max(skill.rangeStuds, 6))
	face(root, aim)
	local requestId = network.Send("cast_skill", { skillId = skill.id, aimDirection = aim })
	if requestId then
		pendingCasts[requestId] = skill.id
	end
	if skill.hitShape == "line" then
		-- Dash strike: moves exactly like a dash (server checks it the same way).
		dashMotion(root, aim)
	elseif skill.hitShape == "sector" then
		effects.PlaySweep(root, aim, skill.rangeStuds)
	elseif skill.hitShape == "bolt" then
		effects.PlayBolt(root, aim, skill.rangeStuds)
	end
	-- circle, buff and heal are drawn from the server's combat_fx for everyone.
end

-- Same rule as the server's Geometry.ClearDistance: only the arena's
-- Collision folder stops a dash.
local function clearDistance(root: BasePart, dir: Vector3, distance: number): number
	local arena = workspace:FindFirstChild(Prototype.WorldNamespace)
	local collision = arena and arena:FindFirstChild("Collision")
	if not collision then
		return distance
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { collision }
	local hit = workspace:Spherecast(root.Position, Prototype.Movement.DashProbeRadiusStuds, dir * distance, params)
	return if hit then math.max(0, hit.Distance - 0.1) else distance
end

local function dash()
	local root, humanoid = getRoot()
	if not root or not humanoid then
		return
	end
	if not cooldownReady("dash") then
		banner.ShowAction(REJECT_TEXT.COOLDOWN)
		return
	end
	local dir = flat(humanoid.MoveDirection) or flat(root.CFrame.LookVector) or Vector3.new(0, 0, -1)
	predictedCooldowns.dash = workspace:GetServerTimeNow() + Prototype.Dash.CooldownSec
	network.Send("dash", { moveDirection = dir })
	dashMotion(root, dir)
end

function dashMotion(root: BasePart, dir: Vector3)
	-- Constant planar velocity, cut short in front of the first wall so the
	-- character never grinds into Collision (that contact could launch it
	-- upward). Gravity still applies; the force is sized to the body.
	local speed = Prototype.Dash.DistanceStuds / Prototype.Dash.DurationSec
	local distance = clearDistance(root, dir, Prototype.Dash.DistanceStuds)
	face(root, dir)
	effects.PlayDash(root)
	if distance < 0.5 then
		return
	end
	local startVy = root.AssemblyLinearVelocity.Y
	local attachment = Instance.new("Attachment")
	attachment.Name = "DashAttachment"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	velocity.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	velocity.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)
	velocity.MaxForce = root.AssemblyMass * speed / DASH_ACCEL_SEC
	velocity.Parent = root
	task.delay(distance / speed, function()
		velocity:Destroy()
		attachment:Destroy()
		if root.Parent then
			-- Drop leftover horizontal speed so the dash ends crisply, and any
			-- upward speed the dash itself added (a jump before it is kept).
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(0, math.min(v.Y, math.max(startVy, 0)), 0)
		end
	end)
end

function CombatController.Handle(action: string)
	if action == "basic_attack" then
		basicAttack()
	elseif action == "cast_skill" then
		castSkill(1)
	elseif string.sub(action, 1, 6) == "skill_" then
		castSkill(tonumber(string.sub(action, 7)) or 0)
	elseif action == "dash" then
		dash()
	elseif action == "transform" then
		network.Send("transform", {})
	end
end

function CombatController.Init(deps: { Network: Network, Camera: Camera, Effects: Effects, Banner: Banner })
	network = deps.Network
	camera = deps.Camera
	effects = deps.Effects
	banner = deps.Banner
end

function CombatController.Start()
	network.OnResult(function(result, action)
		local castSkillId = pendingCasts[result.requestId]
		pendingCasts[result.requestId] = nil
		-- claim_quest errors are shown by QuestController, apply_seal by SealController,
		-- choose_class by ClassController.
		-- learn_skill by SkillController.
		if result.ok or action == "ready" or action == "claim_quest" or action == "apply_seal" or action == "choose_class" or action == "learn_skill" then
			return
		end
		if action == "dash" or action == "cast_skill" then
			-- Server is the authority; fall back to its snapshot cooldowns.
			predictedCooldowns[if action == "dash" then "dash" else castSkillId or ""] = nil
		end
		local text = REJECT_TEXT[result.code] or result.code
		if action == "transform" and result.code == "NOT_READY" then
			text = "เกจวิญญาณยังไม่เต็ม"
		end
		banner.ShowAction(text)
	end)
end

return CombatController

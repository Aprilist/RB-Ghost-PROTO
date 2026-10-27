--!strict
-- Placeholder visuals and sounds for P1 combat. Local swings play at once;
-- other players' swings, hits, enemy telegraph/attack/death come from
-- combat_fx. Everything here is cosmetic and auto-cleans.
-- Sounds are Roblox built-in engine content (rbxasset://sounds/...).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)
local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local VisualPalette = require(ReplicatedStorage.Shared.Definitions.VisualPalette)

local SOUNDS = {
	swing = "rbxasset://sounds/swordslash.wav",
	sweep = "rbxasset://sounds/swordlunge.wav",
	hit = "rbxasset://sounds/swordlunge.wav",
	telegraph = "rbxasset://sounds/electronicpingshort.wav",
}

-- VB-01: one colour language shared with server visuals (VisualPalette).
-- Player FX start more transparent than enemy warnings so a swing, sweep or
-- transform burst never hides a telegraph ring underneath it.
local PLAYER_BLUE = VisualPalette.PlayerSlash
local PLAYER_CORE = VisualPalette.PlayerSlashCore
local HIT_WHITE = VisualPalette.HitSpark
local ENEMY_ORANGE = VisualPalette.Danger
local GUARDIAN = VisualPalette.Guardian
local SOUL = VisualPalette.Soul
local SOUL_CORE = VisualPalette.SoulCore
local EMBER = VisualPalette.EmberDeath
local LEVEL_UP = VisualPalette.LevelUp
local PLAYER_FX_ALPHA = 0.4

-- Telegraph cue pitch per enemy type (runtime IDs are "<type>#<n>"), so a
-- warning can be told apart by ear too. The wisp keeps its P1 pitch.
local TELEGRAPH_PITCH: { [string]: number } = {
	lantern_wisp = 0.7,
	hitodama = 1.15,
	kodama = 0.9,
	karakasa = 0.5,
}

local EffectsController = {}

local fxFolder: Folder
local flash: Frame
local levelBanner: TextLabel

local function sound(id: string, at: Vector3, pitch: number?)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = at
	holder.Parent = fxFolder
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = 0.6
	s.PlaybackSpeed = pitch or 1
	s.RollOffMaxDistance = 80
	s.Parent = holder
	s:Play()
	Debris:AddItem(holder, 2)
end

local function fadePart(size: Vector3, cf: CFrame, color: Color3, duration: number, shape: Enum.PartType?, grow: Vector3?, startAlpha: number?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.CFrame = cf
	part.Transparency = startAlpha or 0.25
	if shape then
		part.Shape = shape
	end
	part.Parent = fxFolder
	local goal: { [string]: any } = { Transparency = 1 }
	if grow then
		goal.Size = grow
	end
	TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(part, duration + 0.05)
	return part
end

-- Three readable combo shapes: right→left, left→right, wide finisher.
local ROLLS = { math.rad(28), math.rad(-28), 0 }

function EffectsController.PlaySwing(root: BasePart, aim: Vector3, step: number)
	local reach = Prototype.Combat.BasicReachStuds
	local width = if step == 3 then reach * 1.9 else reach * 1.4
	local cf = CFrame.lookAt(root.Position, root.Position + aim) * CFrame.new(0, 0.5, -reach * 0.55) * CFrame.Angles(0, 0, ROLLS[step] or 0)
	local duration = if step == 3 then 0.22 else 0.15
	fadePart(Vector3.new(width, 0.15, 1.4), cf, PLAYER_BLUE, duration, nil, nil, PLAYER_FX_ALPHA)
	-- Thin bright core along the leading edge gives the cut a crisp line.
	fadePart(Vector3.new(width * 0.9, 0.08, 0.18), cf * CFrame.new(0, 0, -0.55), PLAYER_CORE, duration * 0.8, nil, nil, 0.15)
	sound(SOUNDS.swing, root.Position, 0.9 + step * 0.08)
end

function EffectsController.PlaySweep(root: BasePart, aim: Vector3)
	local reach = Prototype.Skill.ReachStuds
	local cf = CFrame.lookAt(root.Position, root.Position + aim) * CFrame.new(0, -1.5, -1) * CFrame.Angles(0, 0, math.rad(90))
	fadePart(Vector3.new(0.2, 2, 2), cf, PLAYER_BLUE, 0.3, Enum.PartType.Cylinder, Vector3.new(0.2, reach * 2, reach * 2), 0.55)
	sound(SOUNDS.sweep, root.Position, 0.8)
end

function EffectsController.PlayWave(root: BasePart, aim: Vector3)
	local reach = Prototype.Spirit.TransformAttackReachStuds
	local cf = CFrame.lookAt(root.Position, root.Position + aim) * CFrame.new(0, 0, -reach / 2)
	fadePart(Vector3.new(3, 0.3, reach), cf, GUARDIAN, 0.22, nil, Vector3.new(7, 0.3, reach), PLAYER_FX_ALPHA)
	fadePart(Vector3.new(0.4, 0.12, reach), cf, PLAYER_CORE, 0.18, nil, nil, 0.1)
	sound(SOUNDS.sweep, root.Position, 1.15)
end

function EffectsController.PlayDash(root: BasePart)
	fadePart(Vector3.new(2, 4, 0.4), root.CFrame, PLAYER_BLUE, 0.25, nil, nil, PLAYER_FX_ALPHA)
end

local function hitSpark(at: Vector3, color: Color3)
	fadePart(Vector3.new(1, 1, 1), CFrame.new(at), color, 0.18, Enum.PartType.Ball, Vector3.new(3.5, 3.5, 3.5))
end

-- Orb drifts from the defeated wisp to the rewarded player. Purely visual:
-- the grant already happened on the server before this event was sent.
local function soulOrb(event: Contracts.CombatFxEvent)
	local actor = event.actorUserId and Players:GetPlayerByUserId(event.actorUserId)
	local character = actor and actor.Character
	local target = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local orb = fadePart(Vector3.new(0.7, 0.7, 0.7), CFrame.new(event.position), SOUL_CORE, 0.9, Enum.PartType.Ball)
	orb.Transparency = 0.05
	-- Soft halo in the HUD gauge colour, welded so it rides along with the core.
	local halo = Instance.new("Part")
	halo.Shape = Enum.PartType.Ball
	halo.Size = Vector3.new(1.5, 1.5, 1.5)
	halo.Material = Enum.Material.Neon
	halo.Color = SOUL
	halo.Transparency = 0.45
	halo.CanCollide = false
	halo.CanQuery = false
	halo.CanTouch = false
	halo.CastShadow = false
	halo.Massless = true
	halo.CFrame = orb.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = orb
	weld.Part1 = halo
	weld.Parent = halo
	halo.Parent = orb
	local started = os.clock()
	local connection
	connection = game:GetService("RunService").RenderStepped:Connect(function()
		local t = (os.clock() - started) / 0.6
		if t >= 1 or not orb.Parent or not target or not target.Parent then
			connection:Disconnect()
			if orb.Parent then
				orb:Destroy()
			end
			return
		end
		local arc = Vector3.new(0, math.sin(t * math.pi) * 3, 0)
		orb.CFrame = CFrame.new(event.position:Lerp(target.Position, t) + arc)
	end)
end

-- Two gold rings rise around the player; the owner also gets a short banner.
-- The level itself is shown by the HUD from the snapshot.
local function levelUp(event: Contracts.CombatFxEvent, mine: boolean)
	local feet = event.position - Vector3.new(0, 2.8, 0)
	for i = 0, 1 do
		local ring = CFrame.new(feet + Vector3.new(0, i * 2.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		fadePart(Vector3.new(0.15, 3, 3), ring, LEVEL_UP, 0.7 + i * 0.15, Enum.PartType.Cylinder, Vector3.new(0.15, 10, 10), 0.35)
	end
	fadePart(Vector3.new(0.6, 1, 0.6), CFrame.new(event.position), LEVEL_UP, 0.6, nil, Vector3.new(0.2, 10, 0.2), 0.25)
	sound(SOUNDS.telegraph, event.position, 1.8)
	if mine then
		levelBanner.TextTransparency = 0
		levelBanner.TextStrokeTransparency = 0.4
		TweenService:Create(levelBanner, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
	end
end

local function onFx(event: Contracts.CombatFxEvent)
	local me = (Players.LocalPlayer :: Player).UserId
	local id = event.effectId
	if id == "slash_hit" then
		hitSpark(event.position, HIT_WHITE)
		sound(SOUNDS.hit, event.position, 1.4)
	elseif id == "slash" and event.actorUserId ~= me then
		fadePart(Vector3.new(6, 0.15, 1.2), CFrame.new(event.position), PLAYER_BLUE, 0.15, nil, nil, PLAYER_FX_ALPHA)
		sound(SOUNDS.swing, event.position)
	elseif id == "sweep" and event.actorUserId ~= me then
		local d = Prototype.Skill.ReachStuds * 2
		fadePart(Vector3.new(0.2, 2, 2), CFrame.new(event.position) * CFrame.Angles(0, 0, math.rad(90)), PLAYER_BLUE, 0.3, Enum.PartType.Cylinder, Vector3.new(0.2, d, d), 0.55)
	elseif id == "dash" and event.actorUserId ~= me then
		fadePart(Vector3.new(2, 4, 0.4), CFrame.new(event.position), PLAYER_BLUE, 0.25, nil, nil, PLAYER_FX_ALPHA)
	elseif id == "enemy_telegraph" then
		local kind = event.enemyId and string.match(event.enemyId, "^[^#]+") or ""
		sound(SOUNDS.telegraph, event.position, TELEGRAPH_PITCH[kind] or 0.7)
	elseif id == "enemy_attack" then
		hitSpark(event.position, ENEMY_ORANGE)
	elseif id == "player_hit" then
		hitSpark(event.position, ENEMY_ORANGE)
		if event.actorUserId == me then
			flash.BackgroundTransparency = 0.6
			TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		end
	elseif id == "wave" and event.actorUserId ~= me then
		-- Guardian wave: long, wide streak from the actor along the aim.
		fadePart(Vector3.new(3, 0.3, Prototype.Spirit.TransformAttackReachStuds), CFrame.new(event.position), GUARDIAN, 0.22, nil, Vector3.new(7, 0.3, Prototype.Spirit.TransformAttackReachStuds), PLAYER_FX_ALPHA)
		sound(SOUNDS.sweep, event.position, 1.15)
	elseif id == "soul_orb" then
		soulOrb(event)
	elseif id == "level_up" then
		levelUp(event, event.actorUserId == me)
	elseif id == "transform_start" then
		-- A ground ring and a rising column instead of a solid sphere, so nearby
		-- telegraph rings stay visible through the burst.
		local feet = CFrame.new(event.position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
		fadePart(Vector3.new(0.15, 2, 2), feet, GUARDIAN, 0.5, Enum.PartType.Cylinder, Vector3.new(0.15, 14, 14), 0.5)
		fadePart(Vector3.new(1.2, 1, 1.2), CFrame.new(event.position), PLAYER_CORE, 0.45, nil, Vector3.new(0.3, 12, 0.3), 0.3)
		sound(SOUNDS.telegraph, event.position, 1.4)
	elseif id == "transform_end" then
		fadePart(Vector3.new(5, 5, 5), CFrame.new(event.position), GUARDIAN, 0.35, Enum.PartType.Ball, Vector3.new(1, 1, 1), 0.6)
	elseif id == "burn" then
		-- Small flicker on a burning enemy (M2-E ember); ember colour, not danger orange.
		fadePart(Vector3.new(1, 1, 1), CFrame.new(event.position + Vector3.new(0, 1.5, 0)), EMBER, 0.3, Enum.PartType.Ball, Vector3.new(2.4, 2.4, 2.4), 0.35)
	elseif id == "ward_shield" then
		local feet = CFrame.new(event.position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
		fadePart(Vector3.new(0.15, 2, 2), feet, SOUL, 0.5, Enum.PartType.Cylinder, Vector3.new(0.15, 9, 9), 0.4)
		fadePart(Vector3.new(4, 6, 4), CFrame.new(event.position), SOUL_CORE, 0.45, Enum.PartType.Ball, Vector3.new(6, 8, 6), 0.7)
		sound(SOUNDS.telegraph, event.position, 1.6)
	elseif id == "seal_apply" then
		fadePart(Vector3.new(1.2, 1, 1.2), CFrame.new(event.position), LEVEL_UP, 0.5, nil, Vector3.new(0.3, 9, 0.3), 0.3)
		sound(SOUNDS.hit, event.position, 0.8)
	elseif id == "enemy_death" then
		fadePart(Vector3.new(2, 2, 2), CFrame.new(event.position), EMBER, 0.4, Enum.PartType.Ball, Vector3.new(7, 7, 7))
	end
end

function EffectsController.Start(network: { OnFx: ((Contracts.CombatFxEvent) -> ()) -> () })
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "SpiritWardLocalFx"
	fxFolder.Parent = workspace

	local gui = Instance.new("ScreenGui")
	gui.Name = "SpiritWardDamageFlash"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = VisualPalette.DamageFlash
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Active = false
	flash.Parent = gui
	levelBanner = Instance.new("TextLabel")
	levelBanner.BackgroundTransparency = 1
	levelBanner.Size = UDim2.fromOffset(360, 44)
	levelBanner.Position = UDim2.new(0.5, -180, 0.3, 0)
	levelBanner.Font = Enum.Font.GothamBold
	levelBanner.TextSize = 30
	levelBanner.TextColor3 = LEVEL_UP
	levelBanner.TextTransparency = 1
	levelBanner.TextStrokeTransparency = 1
	levelBanner.Text = "เลเวลอัป!"
	levelBanner.Active = false
	levelBanner.Parent = gui
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

	network.OnFx(onFx)
end

return EffectsController

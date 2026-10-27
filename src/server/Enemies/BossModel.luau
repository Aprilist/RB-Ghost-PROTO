--!strict
-- Greybox model of the Extinguished Keeper (M2-F). Server-owned, anchored,
-- primitive parts only. `Hitbox` is the invisible PrimaryPart that AI, player
-- hits and the HP bar use (its centre sits near player-root height so the
-- normal hit checks work); every other part is visual and follows it.
-- Readable silhouette, not final art: a tall robed figure with a cracked white
-- mask, a half-dead lantern on a staff and four cold lanterns floating round.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VisualPalette = require(ReplicatedStorage.Shared.Definitions.VisualPalette)
local Models = require(script.Parent.Models)

export type Built = {
	model: Model,
	body: BasePart, -- Hitbox, also the PrimaryPart
	tints: { Models.Tint }, -- robe + lantern: recoloured while telegraphing / open
	openTints: { Models.Tint }, -- the robe parts, tinted blue while the boss is open
	hpBarOffsetStuds: number,
}

local BossModel = {}

-- Height of the Hitbox centre above the ground, in studs.
BossModel.HitboxHeightStuds = 4

local visualPart = Models.VisualPart

function BossModel.Build(at: CFrame): Built
	local model = Instance.new("Model")
	model.Name = "ExtinguishedKeeper"
	local tints: { Models.Tint } = {}
	local openTints: { Models.Tint } = {}

	-- `at` is the Hitbox centre; parts are placed by height above the ground.
	local up = BossModel.HitboxHeightStuds
	local function place(name: string, size: Vector3, height: number, x: number, z: number, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
		local part = visualPart(model, name, size, color, material)
		if shape then
			part.Shape = shape
		end
		part.CFrame = at * CFrame.new(x, height - up, z)
		return part
	end
	local function robe(name: string, size: Vector3, height: number, x: number, z: number): Part
		local part = place(name, size, height, x, z, VisualPalette.BossRobe, Enum.Material.Fabric)
		table.insert(tints, { part = part, calm = VisualPalette.BossRobe, angry = VisualPalette.BossRobeAngry })
		table.insert(openTints, { part = part, calm = VisualPalette.BossRobe, angry = VisualPalette.BossRobeOpen })
		return part
	end

	local hitbox = place("Hitbox", Vector3.new(8, 8, 8), up, 0, 0, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	hitbox.Transparency = 1
	model.PrimaryPart = hitbox

	-- Robe, torso and wide shoulders.
	robe("RobeLow", Vector3.new(9, 7, 7), 3.5, 0, 0)
	robe("RobeMid", Vector3.new(7.5, 5, 6), 9.5, 0, 0)
	robe("Shoulders", Vector3.new(11.5, 1.6, 5), 12.6, 0, 0)
	place("Sash", Vector3.new(7.8, 0.8, 6.3), 7, 0, 0, VisualPalette.Gold, Enum.Material.Fabric)

	-- Arms: the left hangs, the right reaches forward holding the staff.
	robe("ArmLeft", Vector3.new(2.2, 6, 2.2), 9.5, -6.4, 0)
	local armRight = robe("ArmRight", Vector3.new(2.2, 6, 2.2), 10, 6.4, -1.4)
	armRight.CFrame = armRight.CFrame * CFrame.Angles(math.rad(-20), 0, 0)

	-- Head and the cracked white mask on the front (-Z).
	place("Head", Vector3.new(3.4, 4, 3.4), 14.8, 0, 0, VisualPalette.BossRobe, Enum.Material.Fabric)
	place("Mask", Vector3.new(3.6, 4.4, 0.5), 14.8, 0, -1.85, VisualPalette.MaskWhite, Enum.Material.SmoothPlastic)
	for _, side in { -1, 1 } do
		place("Eye", Vector3.new(0.8, 0.3, 0.12), 15.3, side * 0.9, -2.15, VisualPalette.Ember, Enum.Material.Neon)
	end
	local crackA = place("Crack", Vector3.new(0.14, 2.6, 0.1), 14.4, -0.4, -2.14, VisualPalette.BossCrack, Enum.Material.SmoothPlastic)
	crackA.CFrame = crackA.CFrame * CFrame.Angles(0, 0, math.rad(18))
	local crackB = place("Crack", Vector3.new(0.12, 1.6, 0.1), 13.9, 0.7, -2.14, VisualPalette.BossCrack, Enum.Material.SmoothPlastic)
	crackB.CFrame = crackB.CFrame * CFrame.Angles(0, 0, math.rad(-25))

	-- Staff with the half-dead lantern: dim until the boss winds up.
	place("StaffPole", Vector3.new(0.5, 20, 0.5), 10.5, 7.6, -3.6, VisualPalette.Rib, Enum.Material.Wood)
	local lantern = place("StaffLantern", Vector3.new(3.2, 4, 3.2), 21.5, 7.6, -3.6, VisualPalette.BossLanternDim, Enum.Material.SmoothPlastic)
	table.insert(tints, { part = lantern, calm = VisualPalette.BossLanternDim, angry = VisualPalette.Ember })
	for _, h in { 19.4, 23.6 } do
		place("StaffRim", Vector3.new(0.4, 3.6, 3.6), h, 7.6, -3.6, VisualPalette.LanternWood, Enum.Material.Wood, Enum.PartType.Cylinder).CFrame =
			at * CFrame.new(7.6, h - up, -3.6) * Models.UPRIGHT
	end
	local glow = Instance.new("PointLight")
	glow.Color = VisualPalette.Ember
	glow.Range = 16
	glow.Brightness = 0.8
	glow.Parent = lantern

	-- Four cold lanterns floating round the boss.
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local x, z = math.cos(angle) * 9, math.sin(angle) * 9
		local small = place("FloatingLantern", Vector3.new(1.4, 1.8, 1.4), 17 + (i % 2) * 2, x, z, VisualPalette.BossLanternDim, Enum.Material.Neon)
		small.Transparency = 0.45
	end

	return { model = model, body = hitbox, tints = tints, openTints = openTints, hpBarOffsetStuds = 17 }
end

return BossModel

--!strict
-- Seal menu (M2-E). Opens when the server sends "seal_menu" (the player used
-- the smith's prompt). Shows each seal's effect and essence cost from
-- Definitions/Seals, and which one the weapon carries, from the latest
-- snapshot. The only request it sends is apply_seal; the server checks
-- ownership, distance and essence and charges once. Readable greybox UI;
-- visual polish comes in the later art pass.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)
local Npcs = require(ReplicatedStorage.Shared.Definitions.Npcs)
local Seals = require(ReplicatedStorage.Shared.Definitions.Seals)

type Network = {
	Send: (Contracts.ActionName, { [string]: any }) -> string?,
	OnResult: ((Contracts.ActionResult, string) -> ()) -> (),
	OnSnapshot: ((Contracts.SnapshotEvent) -> ()) -> (),
	OnSealMenu: ((Contracts.SealMenuEvent) -> ()) -> (),
	GetSnapshot: () -> Contracts.SnapshotEvent?,
}

local PANEL = Color3.fromRGB(24, 22, 40)
local AMBER = Color3.fromRGB(255, 196, 120)
local SOFT = Color3.fromRGB(220, 222, 240)
local GREEN = Color3.fromRGB(70, 130, 80)
local GREY = Color3.fromRGB(70, 66, 96)
-- Menu closes by itself once you walk this far past the NPC's talk range.
local WALK_AWAY_SLACK = 8
-- Display order of the seals in the menu.
local SEAL_ORDER = { "ember", "ward" }

local APPLY_ERRORS: { [string]: string } = {
	INSUFFICIENT_ESSENCE = "แก่นวิญญาณไม่พอ",
	ALREADY_SEALED = "ดาบเล่มนี้ติดผนึกนี้อยู่แล้ว",
	OUT_OF_RANGE = "อยู่ไกลเกินไป เดินเข้าไปใกล้แผงอีกนิด",
	DEAD = "รอเกิดใหม่ก่อน",
	NOT_OWNED = "ไม่พบดาบเล่มนี้",
	RATE_LIMITED = "กดเร็วเกินไป ลองอีกครั้ง",
}

local SealController = {}

local network: Network
local frame: Frame
local titleLabel: TextLabel
local essenceLabel: TextLabel
local messageLabel: TextLabel
local rows: { [string]: { button: TextButton, state: TextLabel } } = {}
local openNpcId: string? = nil
local pending: string? = nil
-- The seal whose price the player has been shown and must confirm (M2-E:
-- the first press shows the price, the second sends apply_seal).
local confirming: string? = nil

local function make(className: string, parent: Instance, props: { [string]: any }): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	inst.Parent = parent
	return inst
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local l = make("TextLabel", parent, {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.6,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Active = false,
	})
	for key, value in props do
		(l :: any)[key] = value
	end
	return l
end

local function describe(sealId: string): string
	local e = Seals[sealId].effect
	if sealId == "ember" then
		return string.format("ทุก %d ครั้งที่ฟันโดน ศัตรูที่โดนจะติดไฟ %d ต่อวินาที นาน %d วินาที (ไฟไม่ซ้อน)", e.hitsToBurn, e.burnDps, e.burnSec)
	elseif sealId == "ward" then
		return string.format("ดูดวิญญาณครบ %d ดวง ได้โล่ %d HP นาน %d วินาที (คูลดาวน์ %d วินาที)", e.soulsToShield, e.shieldHp, e.shieldSec, e.cooldownSec)
	end
	return ""
end

local function setMessage(message: string)
	messageLabel.Text = message
end

local function refresh()
	local snapshot = network.GetSnapshot()
	if not snapshot then
		return
	end
	local p = snapshot.profile
	essenceLabel.Text = string.format("แก่นวิญญาณที่มี: %d", p.essence)
	for sealId, row in rows do
		local def = Seals[sealId]
		if p.equippedSealId == sealId then
			row.state.Text = "ติดอยู่ที่ดาบ"
			row.button.Text = "ติดอยู่"
			row.button.BackgroundColor3 = GREY
			row.button.Active = false
		else
			row.state.Text = string.format("ราคา %d แก่นวิญญาณ%s", def.essenceCost, if p.equippedSealId then " (แทนผนึกเดิม)" else "")
			row.button.Text = if pending == sealId then "..." elseif confirming == sealId then string.format("ยืนยัน -%d", def.essenceCost) else "ผนึก"
			row.button.BackgroundColor3 = if p.essence >= def.essenceCost then GREEN else GREY
			row.button.Active = pending == nil
		end
	end
end

local function close()
	frame.Visible = false
	openNpcId = nil
	pending = nil
	confirming = nil
end

local function onApply(sealId: string)
	local snapshot = network.GetSnapshot()
	if pending or not snapshot then
		return
	end
	if confirming ~= sealId then
		-- First press: show the price and wait for a second press.
		local def = Seals[sealId]
		confirming = sealId
		setMessage(string.format(
			"ใช้แก่นวิญญาณ %d เพื่อ%s%s กดปุ่มอีกครั้งเพื่อยืนยัน",
			def.essenceCost,
			def.displayNameTH,
			if snapshot.profile.equippedSealId then " (ผนึกเดิมจะหลุด)" else ""
		))
		refresh()
		return
	end
	confirming = nil
	pending = sealId
	setMessage("")
	refresh()
	network.Send("apply_seal", { itemInstanceId = snapshot.profile.equippedWeaponId, sealId = sealId })
end

local function onResult(result: Contracts.ActionResult, action: string)
	if action ~= "apply_seal" then
		return
	end
	local sealId = pending
	pending = nil
	if result.ok then
		setMessage(if sealId then "ผนึกสำเร็จ: " .. Seals[sealId].displayNameTH else "ผนึกสำเร็จ")
	else
		setMessage(APPLY_ERRORS[result.code] or ("ผนึกไม่ได้ (" .. result.code .. ")"))
	end
	refresh()
end

local function watchDistance()
	local npcId = openNpcId
	if not npcId then
		return
	end
	local npc = Npcs[npcId]
	local character = (Players.LocalPlayer :: Player).Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not npc or not root then
		return
	end
	local d = Vector3.new(root.Position.X - npc.x, 0, root.Position.Z - npc.z).Magnitude
	if d > npc.talkRangeStuds + WALK_AWAY_SLACK then
		close()
	end
end

function SealController.Start(deps: Network)
	network = deps

	local gui = make("ScreenGui", (Players.LocalPlayer :: Player):WaitForChild("PlayerGui"), {
		Name = "SpiritWardSeals",
		ResetOnSpawn = false,
		DisplayOrder = 7,
	})

	-- Centred like the quest dialogue, above the bottom corners where the
	-- thumbstick and touch action buttons live.
	frame = make("Frame", gui, {
		Name = "SealMenu",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.new(0.55, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Visible = false,
	})
	make("UISizeConstraint", frame, { MinSize = Vector2.new(320, 0), MaxSize = Vector2.new(560, math.huge) })
	make("UICorner", frame, { CornerRadius = UDim.new(0, 10) })
	make("UIPadding", frame, {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
	})
	make("UIListLayout", frame, { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })

	titleLabel = text(frame, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 22), TextSize = 18, TextColor3 = AMBER, Text = "ผนึกดาบ" })
	essenceLabel = text(frame, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 18), TextSize = 14, TextColor3 = SOFT })

	for i, sealId in SEAL_ORDER do
		local def = Seals[sealId]
		local row = make("Frame", frame, {
			LayoutOrder = 2 + i,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.fromRGB(40, 38, 64),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
		})
		make("UICorner", row, { CornerRadius = UDim.new(0, 8) })
		make("UIPadding", row, {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		})
		make("UIListLayout", row, { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) })
		text(row, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20), TextSize = 16, TextColor3 = AMBER, Text = def.displayNameTH })
		text(row, {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = SOFT,
			Text = describe(sealId),
		})
		local bottom = make("Frame", row, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 })
		local state = text(bottom, {
			Size = UDim2.new(1, -130, 1, 0),
			TextSize = 14,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextColor3 = SOFT,
		})
		local button = make("TextButton", bottom, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(120, 34),
			BackgroundColor3 = GREEN,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "ผนึก",
			AutoButtonColor = true,
		})
		make("UICorner", button, { CornerRadius = UDim.new(0, 6) })
		button.Activated:Connect(function()
			onApply(sealId)
		end)
		rows[sealId] = { button = button, state = state }
	end

	messageLabel = text(frame, {
		LayoutOrder = 10,
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 15,
		TextColor3 = AMBER,
	})
	local closeRow = make("Frame", frame, { LayoutOrder = 11, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 })
	local closeButton = make("TextButton", closeRow, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(120, 34),
		BackgroundColor3 = GREY,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "ปิด",
	})
	make("UICorner", closeButton, { CornerRadius = UDim.new(0, 6) })
	closeButton.Activated:Connect(close)

	network.OnSealMenu(function(event)
		openNpcId = event.npcId
		pending = nil
		confirming = nil
		titleLabel.Text = event.speakerTH .. " — ผนึกดาบ"
		setMessage("")
		refresh()
		frame.Visible = true
	end)
	network.OnSnapshot(function()
		if frame.Visible then
			refresh()
		end
	end)
	network.OnResult(onResult)
	RunService.Heartbeat:Connect(watchDistance)
end

return SealController

--!strict
-- Class menu (M4). Director 28 Oct 2026: the class is picked once and never
-- changed back. The menu opens by itself while the snapshot says
-- classChosen = false and cannot be closed until a class is picked; picking
-- needs a second press to confirm. After that the trainer's prompt
-- ("class_menu") shows the same list, read-only. The only request it sends
-- is choose_class; the server re-checks everything. Same greybox style as
-- the seal menu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Classes = require(ReplicatedStorage.Shared.Definitions.Classes)
local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)
local Npcs = require(ReplicatedStorage.Shared.Definitions.Npcs)

type Network = {
	Send: (Contracts.ActionName, { [string]: any }) -> string?,
	OnResult: ((Contracts.ActionResult, string) -> ()) -> (),
	OnSnapshot: ((Contracts.SnapshotEvent) -> ()) -> (),
	OnClassMenu: ((Contracts.ClassMenuEvent) -> ()) -> (),
	GetSnapshot: () -> Contracts.SnapshotEvent?,
}

local PANEL = Color3.fromRGB(24, 22, 40)
local AMBER = Color3.fromRGB(255, 196, 120)
local SOFT = Color3.fromRGB(220, 222, 240)
local GREEN = Color3.fromRGB(70, 130, 80)
local GREY = Color3.fromRGB(70, 66, 96)
local WALK_AWAY_SLACK = 8

local ERRORS: { [string]: string } = {
	CLASS_LOCKED = "เลือกอาชีพไปแล้ว เปลี่ยนไม่ได้",
	DEAD = "รอเกิดใหม่ก่อน",
	NOT_OWNED = "อาชีพนี้ยังไม่เปิด",
	NOT_READY = "ข้อมูลตัวละครยังไม่พร้อม",
	RATE_LIMITED = "กดเร็วเกินไป ลองอีกครั้ง",
}

local ClassController = {}

local network: Network
local frame: Frame
local titleLabel: TextLabel
local messageLabel: TextLabel
local closeButton: TextButton
local rows: { [string]: { button: TextButton, state: TextLabel } } = {}
local openNpcId: string? = nil
local pending: string? = nil
-- The class the player pressed once and must press again to confirm.
local confirming: string? = nil

local function chosen(): boolean?
	local snapshot = network.GetSnapshot()
	return snapshot and snapshot.profile.classChosen
end

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

local function refresh()
	local snapshot = network.GetSnapshot()
	local locked = snapshot ~= nil and snapshot.profile.classChosen
	local current = snapshot and snapshot.profile.classId
	closeButton.Visible = locked
	for classId, row in rows do
		local def = Classes.Get(classId) :: Classes.ClassDef
		if locked then
			row.state.Text = if classId == current then "อาชีพของคุณ" else "เลือกอาชีพแล้ว เปลี่ยนไม่ได้"
			row.button.Text = if classId == current then "อาชีพนี้" else "—"
			row.button.BackgroundColor3 = GREY
			row.button.Active = false
		elseif not def.available then
			row.state.Text = "เร็ว ๆ นี้"
			row.button.Text = "ยังไม่เปิด"
			row.button.BackgroundColor3 = GREY
			row.button.Active = false
		else
			row.state.Text = "เลือกได้ครั้งเดียว"
			row.button.Text = if pending == classId then "..." elseif confirming == classId then "ยืนยัน" else "เลือก"
			row.button.BackgroundColor3 = GREEN
			row.button.Active = pending == nil
		end
	end
end

local function close()
	if not chosen() then
		return -- must pick first
	end
	frame.Visible = false
	openNpcId = nil
	pending = nil
	confirming = nil
end

local function onChoose(classId: string)
	local def = Classes.Get(classId)
	if pending or chosen() ~= false or not def or not def.available then
		return
	end
	if confirming ~= classId then
		-- First press: say it is final and wait for a second press.
		confirming = classId
		messageLabel.Text = "เป็น" .. def.displayNameTH .. "แล้วจะเปลี่ยนอาชีพไม่ได้อีก กด \"ยืนยัน\" เพื่อเลือก"
		refresh()
		return
	end
	confirming = nil
	pending = classId
	messageLabel.Text = ""
	refresh()
	network.Send("choose_class", { classId = classId })
end

local function open(title: string, npcId: string?)
	openNpcId = npcId
	pending = nil
	confirming = nil
	titleLabel.Text = title
	messageLabel.Text = ""
	refresh()
	frame.Visible = true
end

local function onResult(result: Contracts.ActionResult, action: string)
	if action ~= "choose_class" then
		return
	end
	local classId = pending
	pending = nil
	local def = classId and Classes.Get(classId)
	if result.ok then
		messageLabel.Text = if def then "ตอนนี้เป็น" .. def.displayNameTH .. "แล้ว" else "เปลี่ยนอาชีพแล้ว"
	else
		messageLabel.Text = ERRORS[result.code] or ("เปลี่ยนไม่ได้ (" .. result.code .. ")")
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

function ClassController.Start(deps: Network)
	network = deps

	local gui = make("ScreenGui", (Players.LocalPlayer :: Player):WaitForChild("PlayerGui"), {
		Name = "SpiritWardClasses",
		ResetOnSpawn = false,
		DisplayOrder = 7,
	})
	frame = make("Frame", gui, {
		Name = "ClassMenu",
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

	titleLabel = text(frame, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 22), TextSize = 18, TextColor3 = AMBER, Text = "เลือกอาชีพ" })

	for i, def in Classes.List do
		local row = make("Frame", frame, {
			LayoutOrder = 1 + i,
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
			Text = def.descriptionTH,
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
			Text = "เลือก",
			AutoButtonColor = true,
		})
		make("UICorner", button, { CornerRadius = UDim.new(0, 6) })
		button.Activated:Connect(function()
			onChoose(def.id)
		end)
		rows[def.id] = { button = button, state = state }
	end

	messageLabel = text(frame, { LayoutOrder = 10, Size = UDim2.new(1, 0, 0, 20), TextSize = 15, TextColor3 = AMBER })
	local closeRow = make("Frame", frame, { LayoutOrder = 11, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 })
	closeButton = make("TextButton", closeRow, {
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

	network.OnClassMenu(function(event)
		open(event.speakerTH .. " — อาชีพ", event.npcId)
	end)
	network.OnSnapshot(function(snapshot)
		if not snapshot.profile.classChosen and not frame.Visible then
			open("เลือกอาชีพของคุณ", nil)
		elseif frame.Visible then
			refresh()
		end
	end)
	network.OnResult(onResult)
	RunService.Heartbeat:Connect(watchDistance)
end

return ClassController

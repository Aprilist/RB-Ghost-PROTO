--!strict
-- M4 skill system on the client: the hotbar (bottom centre, keys 1–5, also
-- tappable so touch players can cast) and the skill window (K, or the
-- "สกิล" button above the hotbar) where skill points are spent with
-- learn_skill. Everything shown comes from the snapshot and the shared
-- catalog/rules (Classes, Skills, SkillRules); the server decides.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Classes = require(ReplicatedStorage.Shared.Definitions.Classes)
local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)
local Skills = require(ReplicatedStorage.Shared.Definitions.Skills)
local SkillRules = require(ReplicatedStorage.Shared.Util.SkillRules)

type Network = {
	Send: (Contracts.ActionName, { [string]: any }) -> string?,
	OnResult: ((Contracts.ActionResult, string) -> ()) -> (),
	OnSnapshot: ((Contracts.SnapshotEvent) -> ()) -> (),
	GetSnapshot: () -> Contracts.SnapshotEvent?,
}
type Combat = { Handle: (string) -> () }

local PANEL = Color3.fromRGB(24, 22, 40)
local AMBER = Color3.fromRGB(255, 196, 120)
local SOFT = Color3.fromRGB(220, 222, 240)
local GREEN = Color3.fromRGB(70, 130, 80)
local GREY = Color3.fromRGB(70, 66, 96)
local SLOT_READY = Color3.fromRGB(44, 52, 86)
local SLOTS = 5
local PASSIVES = 2 -- window rows under the hotbar skills (Classes passiveIds)

local LEARN_ERRORS: { [string]: string } = {
	SKILL_LOCKED = "เลเวลยังไม่ถึง",
	MAX_RANK = "ระดับสูงสุดแล้ว",
	NO_SKILL_POINTS = "แต้มสกิลไม่พอ",
	NOT_READY = "เลือกอาชีพก่อน",
	RATE_LIMITED = "กดเร็วเกินไป",
}

local SkillController = {}

local network: Network
local combat: Combat
local slotButtons: { { button: TextButton, name: TextLabel, state: TextLabel } } = {}
local window: Frame
local pointsLabel: TextLabel
local messageLabel: TextLabel
local rows: { { frame: Frame, name: TextLabel, info: TextLabel, button: TextButton } } = {}
local pending = false

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
		TextWrapped = true,
		Active = false,
	})
	for key, value in props do
		(l :: any)[key] = value
	end
	return l
end

local function classSkills(snapshot: Contracts.SnapshotEvent): { string }
	return Classes.Kit(snapshot.profile.classId).skillIds
end

-- Window rows: hotbar skills, then passives.
local function windowSkills(snapshot: Contracts.SnapshotEvent): { string }
	local ids = table.clone(classSkills(snapshot))
	local class = Classes.Get(snapshot.profile.classId)
	for _, id in if class then class.passiveIds else {} do
		table.insert(ids, id)
	end
	return ids
end

local PASSIVE_TEXT: { [string]: string } = {
	basicDamagePct = "ดาเมจโจมตีปกติ +%d%%",
	skillDamagePct = "ดาเมจสกิล +%d%%",
	maxHpPct = "HP สูงสุด +%d%%",
	maxSpFlat = "SP สูงสุด +%d",
}

-- What a skill does at `rank`, for the window.
local function effectLine(skill: Skills.SkillDef, rank: number): string
	if skill.hitShape == "passive" then
		local v = (skill.passivePerRank or 0) * rank
		local pct = skill.passiveStat ~= "maxSpFlat"
		return string.format(PASSIVE_TEXT[skill.passiveStat or ""] or "%d", math.floor(if pct then v * 100 + 0.5 else v))
	elseif skill.rootSec then
		return string.format("ดาเมจ %d · ตรึง %.2f วิ", SkillRules.Damage(skill, rank), SkillRules.RootSec(skill, rank))
	elseif skill.hitShape == "buff" then
		return string.format("ดาเมจ ×%.2f นาน %d วิ", skill.buffMult or 1, SkillRules.BuffSec(skill, rank))
	elseif skill.hitShape == "heal" then
		return string.format("ฟื้น %d%% HP", math.floor(SkillRules.HealFraction(skill, rank) * 100 + 0.5))
	end
	return string.format("ดาเมจ %d", SkillRules.Damage(skill, rank))
end

local function renderHotbar()
	local snapshot = network.GetSnapshot()
	if not snapshot or not snapshot.profile.classChosen then
		for _, slot in slotButtons do
			slot.button.Visible = false
		end
		return
	end
	local p, s = snapshot.profile, snapshot.session
	local now = workspace:GetServerTimeNow()
	local sp = SkillRules.SpAt(s.sp, s.spAt, s.maxSp, now)
	local ids = classSkills(snapshot)
	for i, slot in slotButtons do
		local skill = ids[i] and Skills[ids[i]]
		slot.button.Visible = skill ~= nil
		if skill then
			slot.name.Text = skill.displayNameTH
			local rank = SkillRules.Rank(p, skill.id)
			local cd = s.cooldowns[skill.id]
			local left = if cd then cd - now else 0
			if p.level < skill.unlockLevel then
				slot.state.Text = "Lv " .. skill.unlockLevel
				slot.button.BackgroundColor3 = GREY
			elseif rank < 1 then
				slot.state.Text = "เรียน K"
				slot.button.BackgroundColor3 = GREY
			elseif left > 0 then
				slot.state.Text = string.format("%.1f", left)
				slot.button.BackgroundColor3 = GREY
			elseif sp < skill.spCost then
				slot.state.Text = "SP " .. skill.spCost
				slot.button.BackgroundColor3 = GREY
			else
				slot.state.Text = string.format("R%d · SP %d", rank, skill.spCost)
				slot.button.BackgroundColor3 = SLOT_READY
			end
		end
	end
end

local function renderWindow()
	local snapshot = network.GetSnapshot()
	if not snapshot or not window.Visible then
		return
	end
	local p = snapshot.profile
	local class = Classes.Get(p.classId)
	pointsLabel.Text = string.format("%s · Lv %d · แต้มสกิล %d", if class then class.displayNameTH else p.classId, p.level, p.skillPoints)
	local ids = windowSkills(snapshot)
	for i, row in rows do
		local skill = ids[i] and Skills[ids[i]]
		row.frame.Visible = skill ~= nil
		if skill then
			local rank = SkillRules.Rank(p, skill.id)
			local passive = skill.hitShape == "passive"
			row.name.Text = string.format("%s · %s  (ระดับ %d/%d)", if passive then "ติดตัว" else tostring(i), skill.displayNameTH, rank, skill.maxRank)
			local next = if rank < skill.maxRank and (rank >= 1 or passive) then "  → ระดับถัดไป " .. effectLine(skill, rank + 1) else ""
			row.info.Text = if passive
				then string.format("ปลด Lv %d · ตอนนี้ %s%s", skill.unlockLevel, if rank > 0 then effectLine(skill, rank) else "ยังไม่ได้เรียน", next)
				else string.format(
					"ปลด Lv %d · SP %d · คูลดาวน์ %d วิ · %s%s\n%s",
					skill.unlockLevel, skill.spCost, skill.cooldownSec, effectLine(skill, math.max(rank, 1)), next, skill.effectNotes
				)
			local canLearn = SkillRules.Learn({
				classId = p.classId,
				classChosen = p.classChosen,
				level = p.level,
				skillPoints = p.skillPoints,
				skills = table.clone(p.skills),
			}, skill.id)
			row.button.Text = if pending then "..." elseif rank >= skill.maxRank then "เต็ม" elseif p.level < skill.unlockLevel then "Lv " .. skill.unlockLevel elseif rank < 1 then "เรียน" else "+1"
			row.button.BackgroundColor3 = if canLearn == "OK" and not pending then GREEN else GREY
			row.button.Active = canLearn == "OK" and not pending
		end
	end
end

local function toggleWindow()
	local snapshot = network.GetSnapshot()
	if not snapshot or not snapshot.profile.classChosen then
		return
	end
	window.Visible = not window.Visible
	messageLabel.Text = ""
	renderWindow()
end

local function learn(slot: number)
	local snapshot = network.GetSnapshot()
	local id = snapshot and windowSkills(snapshot)[slot]
	if pending or not id then
		return
	end
	pending = true
	messageLabel.Text = ""
	renderWindow()
	network.Send("learn_skill", { skillId = id })
end

local function slotButton(parent: Instance, i: number)
	local button = make("TextButton", parent, {
		LayoutOrder = i,
		Size = UDim2.fromOffset(74, 52),
		BackgroundColor3 = SLOT_READY,
		BackgroundTransparency = 0.15,
		AutoButtonColor = true,
		Text = "",
	})
	make("UICorner", button, { CornerRadius = UDim.new(0, 6) })
	text(button, { Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(4, 2), TextSize = 12, TextColor3 = AMBER, Text = tostring(i) })
	local name = text(button, { Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 15), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center })
	local state = text(button, { Size = UDim2.new(1, -8, 0, 14), Position = UDim2.fromOffset(4, 34), TextSize = 11, TextColor3 = SOFT, TextXAlignment = Enum.TextXAlignment.Center })
	button.Activated:Connect(function()
		combat.Handle("skill_" .. i)
	end)
	slotButtons[i] = { button = button, name = name, state = state }
end

function SkillController.Start(deps: { Network: Network, Combat: Combat })
	network = deps.Network
	combat = deps.Combat
	local gui = make("ScreenGui", (Players.LocalPlayer :: Player):WaitForChild("PlayerGui"), {
		Name = "SpiritWardSkills",
		ResetOnSpawn = false,
		DisplayOrder = 6,
	})

	-- Hotbar: bottom centre, between the thumbstick and the touch buttons.
	local bar = make("Frame", gui, {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(SLOTS * 78, 78),
		BackgroundTransparency = 1,
	})
	local slotsRow = make("Frame", bar, { Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 26), BackgroundTransparency = 1 })
	make("UIListLayout", slotsRow, { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
	for i = 1, SLOTS do
		slotButton(slotsRow, i)
	end
	local openButton = make("TextButton", bar, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(110, 22),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.2,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = AMBER,
		Text = "สกิล (K)",
	})
	make("UICorner", openButton, { CornerRadius = UDim.new(0, 6) })
	openButton.Activated:Connect(toggleWindow)

	-- Skill window, centred like the other menus.
	window = make("Frame", gui, {
		Name = "SkillWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.new(0.6, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Visible = false,
	})
	make("UISizeConstraint", window, { MinSize = Vector2.new(340, 0), MaxSize = Vector2.new(600, math.huge) })
	make("UICorner", window, { CornerRadius = UDim.new(0, 10) })
	make("UIPadding", window, { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) })
	make("UIListLayout", window, { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) })
	text(window, { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 22), TextSize = 18, TextColor3 = AMBER, Text = "สกิล" })
	pointsLabel = text(window, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 18), TextSize = 14, TextColor3 = SOFT })
	for i = 1, SLOTS + PASSIVES do
		local row = make("Frame", window, {
			LayoutOrder = 1 + i,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.fromRGB(40, 38, 64),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
		})
		make("UICorner", row, { CornerRadius = UDim.new(0, 8) })
		make("UIPadding", row, { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 92), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) })
		make("UIListLayout", row, { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
		local name = text(row, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 18), TextSize = 15, TextColor3 = AMBER })
		local info = text(row, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = SOFT })
		local button = make("TextButton", row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 82, 0.5, 0),
			Size = UDim2.fromOffset(76, 32),
			BackgroundColor3 = GREEN,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "+1",
		})
		make("UICorner", button, { CornerRadius = UDim.new(0, 6) })
		button.Activated:Connect(function()
			learn(i)
		end)
		rows[i] = { frame = row, name = name, info = info, button = button }
	end
	messageLabel = text(window, { LayoutOrder = 10, Size = UDim2.new(1, 0, 0, 18), TextSize = 14, TextColor3 = AMBER, Text = "" })
	local closeButton = make("TextButton", window, {
		LayoutOrder = 11,
		Size = UDim2.fromOffset(120, 32),
		BackgroundColor3 = GREY,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "ปิด (K)",
	})
	make("UICorner", closeButton, { CornerRadius = UDim.new(0, 6) })
	closeButton.Activated:Connect(toggleWindow)

	ContextActionService:BindAction("SpiritWard_skill_window", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			toggleWindow()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.K)

	network.OnResult(function(result, action)
		if action ~= "learn_skill" then
			return
		end
		pending = false
		messageLabel.Text = if result.ok then "อัปสกิลแล้ว" else (LEARN_ERRORS[result.code] or ("อัปไม่ได้ (" .. result.code .. ")"))
		renderWindow()
	end)
	network.OnSnapshot(function()
		renderWindow()
	end)
	RunService.RenderStepped:Connect(renderHotbar)
end

return SkillController

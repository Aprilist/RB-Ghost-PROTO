--!strict
-- Quest UI (M2-D), all driven by the server: the tracker reads the quests map
-- in each snapshot, the dialogue box shows "dialogue" events, short lines
-- show "notice" events. The only request it sends is claim_quest, from the
-- dialogue's claim button; the server decides everything else. "!" / "?"
-- over a quest giver are local pictures of QuestRules.GiverState.
-- Readable greybox UI; visual polish comes in the later art pass.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)
local Npcs = require(ReplicatedStorage.Shared.Definitions.Npcs)
local Quests = require(ReplicatedStorage.Shared.Definitions.Quests)
local QuestRules = require(ReplicatedStorage.Shared.Util.QuestRules)

type Network = {
	Send: (Contracts.ActionName, { [string]: any }) -> string?,
	OnResult: ((Contracts.ActionResult, string) -> ()) -> (),
	OnSnapshot: ((Contracts.SnapshotEvent) -> ()) -> (),
	OnDialogue: ((Contracts.DialogueEvent) -> ()) -> (),
	OnNotice: ((Contracts.NoticeEvent) -> ()) -> (),
	GetSnapshot: () -> Contracts.SnapshotEvent?,
}

local PANEL = Color3.fromRGB(24, 22, 40)
local AMBER = Color3.fromRGB(255, 196, 120)
local SOFT = Color3.fromRGB(220, 222, 240)
local READY_GREEN = Color3.fromRGB(150, 230, 150)
local NPC_TAG = "SpiritWardNpc"
-- Dialogue closes by itself once you walk this far past the NPC's talk range.
local WALK_AWAY_SLACK = 8
local NOTICE_SEC = 3.5
local MAX_TRACKED = 2

local CLAIM_ERRORS: { [string]: string } = {
	QUEST_NOT_READY = "เควสนี้ยังไม่เสร็จ",
	ALREADY_CLAIMED = "รับรางวัลเควสนี้ไปแล้ว",
	OUT_OF_RANGE = "อยู่ไกลเกินไป เดินเข้าไปใกล้อีกนิด",
	DEAD = "รอเกิดใหม่ก่อน",
	RATE_LIMITED = "กดเร็วเกินไป ลองอีกครั้ง",
}

local QuestController = {}

local network: Network
local trackerFrame: Frame
local trackerText: TextLabel
local noticeLabel: TextLabel
local dialogueFrame: Frame
local speakerLabel: TextLabel
local bodyLabel: TextLabel
local claimButton: TextButton
local closeButton: TextButton
local openNpcId: string? = nil
local openClaimId: string? = nil
local pendingClaim: string? = nil
local noticeCount = 0
local markers: { [Model]: TextLabel } = {}

local function make(className: string, parent: Instance, props: { [string]: any }): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	inst.Parent = parent
	return inst
end

local function corner(parent: Instance, radius: number)
	make("UICorner", parent, { CornerRadius = UDim.new(0, radius) })
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

local function button(parent: Instance, label: string, color: Color3): TextButton
	local b = make("TextButton", parent, {
		Size = UDim2.fromOffset(120, 34),
		BackgroundColor3 = color,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		Text = label,
		AutoButtonColor = true,
	})
	corner(b, 6)
	return b
end

local function showNotice(message: string)
	noticeLabel.Text = message
	noticeLabel.Visible = true
	noticeCount += 1
	local mine = noticeCount
	task.delay(NOTICE_SEC, function()
		if mine == noticeCount then
			noticeLabel.Visible = false
		end
	end)
end

------------------------------------------------------------------------------
-- Tracker
------------------------------------------------------------------------------

local function renderTracker(snapshot: Contracts.SnapshotEvent)
	local quests = snapshot.profile.quests or {}
	local lines = {}
	local shown = 0
	for _, id in QuestRules.Order() do
		local record = quests[id]
		local def = Quests[id]
		if record and record.status ~= "claimed" and shown < MAX_TRACKED then
			shown += 1
			table.insert(lines, string.format('<font color="#FFC478">%s</font>', def.titleTH))
			if record.status == "ready" then
				local giver = Npcs[def.giverNpcId]
				table.insert(lines, string.format('<font color="#96E696">✓ เสร็จแล้ว กลับไปหา%s</font>', if giver then giver.displayNameTH else "ผู้ให้เควส"))
			elseif def.targetCount > 1 then
				table.insert(lines, string.format("%s  %d/%d", def.objectiveTH, record.progress, def.targetCount))
			else
				table.insert(lines, def.objectiveTH)
			end
		end
	end
	trackerFrame.Visible = shown > 0
	trackerText.Text = table.concat(lines, "\n")
end

------------------------------------------------------------------------------
-- Quest giver markers ("!" new quest, "?" ready to claim)
------------------------------------------------------------------------------

local function markerFor(model: Model): TextLabel?
	local existing = markers[model]
	if existing then
		return existing
	end
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end
	local gui = make("BillboardGui", head, {
		Name = "QuestMarker",
		Size = UDim2.fromOffset(40, 40),
		StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0),
		MaxDistance = 120,
		AlwaysOnTop = true,
		LightInfluence = 0,
	})
	local l = text(gui, {
		Size = UDim2.fromScale(1, 1),
		TextScaled = true,
		TextColor3 = AMBER,
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = "",
	})
	markers[model] = l
	model.Destroying:Connect(function()
		markers[model] = nil
	end)
	return l
end

local function renderMarkers()
	local snapshot = network.GetSnapshot()
	local quests = if snapshot then snapshot.profile.quests or {} else {}
	for _, inst in CollectionService:GetTagged(NPC_TAG) do
		if inst:IsA("Model") then
			local npcId = inst:GetAttribute("NpcId")
			local l = type(npcId) == "string" and markerFor(inst)
			if l then
				local state = QuestRules.GiverState(quests :: any, npcId :: string)
				local talk = QuestRules.WantsTalk(quests :: any, npcId :: string)
				l.Text = if state == "claim" then "?" elseif state == "offer" or talk then "!" else ""
				l.TextColor3 = if state == "claim" then READY_GREEN else AMBER
			end
		end
	end
end

------------------------------------------------------------------------------
-- Dialogue
------------------------------------------------------------------------------

local function closeDialogue()
	dialogueFrame.Visible = false
	openNpcId = nil
	openClaimId = nil
	pendingClaim = nil
end

local function onDialogue(event: Contracts.DialogueEvent)
	openNpcId = event.npcId
	openClaimId = event.claimQuestId
	pendingClaim = nil
	speakerLabel.Text = event.speakerTH
	bodyLabel.Text = table.concat(event.lines, "\n")
	claimButton.Visible = event.claimQuestId ~= nil
	claimButton.Text = "รับรางวัล"
	claimButton.Active = true
	if event.claimQuestId then
		local def = Quests[event.claimQuestId]
		if def then
			bodyLabel.Text ..= string.format('\n<font color="#FFC478">รางวัล: EXP %d · เหรียญ %d · แก่นวิญญาณ %d</font>', def.rewardXp, def.rewardCoins, def.rewardEssence)
		end
	end
	dialogueFrame.Visible = true
end

local function onClaimPressed()
	local questId = openClaimId
	if not questId or pendingClaim then
		return
	end
	pendingClaim = questId
	claimButton.Text = "..."
	claimButton.Active = false
	network.Send("claim_quest", { questId = questId })
end

local function onResult(result: Contracts.ActionResult, action: string)
	-- pendingClaim is cleared when a newer dialogue arrived first; then
	-- that dialogue stays open.
	if action ~= "claim_quest" or not pendingClaim then
		return
	end
	if result.ok then
		-- The server follows with the giver's next line (or a notice).
		closeDialogue()
	else
		pendingClaim = nil
		claimButton.Text = "รับรางวัล"
		claimButton.Active = true
		showNotice(CLAIM_ERRORS[result.code] or ("รับรางวัลไม่ได้ (" .. result.code .. ")"))
	end
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
		closeDialogue()
	end
end

------------------------------------------------------------------------------

function QuestController.Start(deps: Network)
	network = deps

	local gui = make("ScreenGui", (Players.LocalPlayer :: Player):WaitForChild("PlayerGui"), {
		Name = "SpiritWardQuests",
		ResetOnSpawn = false,
		DisplayOrder = 6,
	})

	-- Tracker: under the HUD panel (HUD sits at 12,44 and is 156 tall).
	trackerFrame = make("Frame", gui, {
		Name = "Tracker",
		Size = UDim2.fromOffset(260, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(12, 208),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Active = false,
		Visible = false,
	})
	corner(trackerFrame, 8)
	make("UIPadding", trackerFrame, {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	})
	trackerText = text(trackerFrame, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 13,
		RichText = true,
		TextColor3 = SOFT,
	})

	noticeLabel = text(gui, {
		Name = "Notice",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 66),
		Size = UDim2.fromOffset(460, 26),
		TextSize = 17,
		TextColor3 = AMBER,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	})

	-- Dialogue box: centred, above the bottom corners where the thumbstick
	-- and the touch action buttons live.
	dialogueFrame = make("Frame", gui, {
		Name = "Dialogue",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.new(0.5, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Visible = false,
	})
	make("UISizeConstraint", dialogueFrame, { MinSize = Vector2.new(300, 0), MaxSize = Vector2.new(520, math.huge) })
	corner(dialogueFrame, 10)
	make("UIPadding", dialogueFrame, {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
	})
	make("UIListLayout", dialogueFrame, {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	})
	speakerLabel = text(dialogueFrame, {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 18,
		TextColor3 = AMBER,
	})
	bodyLabel = text(dialogueFrame, {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		RichText = true,
	})
	local row = make("Frame", dialogueFrame, {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
	})
	make("UIListLayout", row, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	})
	claimButton = button(row, "รับรางวัล", Color3.fromRGB(70, 130, 80))
	closeButton = button(row, "ปิด", Color3.fromRGB(70, 66, 96))
	claimButton.LayoutOrder = 1
	closeButton.LayoutOrder = 2
	claimButton.Activated:Connect(onClaimPressed)
	closeButton.Activated:Connect(closeDialogue)

	network.OnSnapshot(function(snapshot)
		renderTracker(snapshot)
		renderMarkers()
	end)
	network.OnDialogue(onDialogue)
	network.OnNotice(function(event)
		showNotice(event.textTH)
	end)
	network.OnResult(onResult)
	-- NPC models may stream in after the first snapshot.
	CollectionService:GetInstanceAddedSignal(NPC_TAG):Connect(function()
		task.defer(renderMarkers)
	end)
	renderMarkers()
	RunService.Heartbeat:Connect(watchDistance)
end

return QuestController

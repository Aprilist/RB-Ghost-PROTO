--!strict
-- Boss fight HUD (M2-F part 2). Shows, at the top of the screen, the join
-- countdown while the fight is open, the boss's HP bar while you are in the
-- fight, and a short result line when it ends. It only reads: encounter
-- events from the server for the phase, and the boss model's replicated
-- attributes (Hp, MaxHp, Open) for the bar, so no extra traffic per hit.
-- Readable greybox UI; visual polish comes in the later art pass.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bosses = require(ReplicatedStorage.Shared.Definitions.Bosses)
local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)

type Network = {
	OnEncounter: ((Contracts.EncounterEvent) -> ()) -> (),
}

local DEF = Bosses.extinguished_keeper
local PANEL = Color3.fromRGB(24, 22, 40)
local AMBER = Color3.fromRGB(255, 196, 120)
local OPEN_BLUE = Color3.fromRGB(150, 190, 255)
local HP_ORANGE = Color3.fromRGB(255, 170, 90)
local RESULT_SEC = 4
local COMPACT_HEIGHT = 500

local BossController = {}

local frame: Frame
local titleLabel: TextLabel
local barBack: Frame
local barFill: Frame
local statusLabel: TextLabel
local event: Contracts.EncounterEvent? = nil
local resultUntil = 0
local bossModel: Model? = nil

local function make(className: string, parent: Instance, props: { [string]: any }): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	inst.Parent = parent
	return inst
end

local function inArena(): boolean
	local character = (Players.LocalPlayer :: Player).Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	return math.abs(root.Position.X - DEF.arenaCenterX) <= DEF.arenaHalfStuds and math.abs(root.Position.Z - DEF.arenaCenterZ) <= DEF.arenaHalfStuds
end

local function findBoss(): Model?
	local current = bossModel
	if current and current.Parent then
		return current
	end
	bossModel = nil
	for _, inst in CollectionService:GetTagged("Enemy") do
		if inst:IsA("Model") and inst:GetAttribute("EnemyType") == DEF.id then
			bossModel = inst
			return inst
		end
	end
	return nil
end

local function update()
	local e = event
	local showBar = false
	local text = ""
	local color = AMBER
	if e then
		local now = workspace:GetServerTimeNow()
		if e.state == "open" and inArena() then
			showBar = true
			text = string.format("ศึกจะเริ่มใน %d วินาที — คนอื่นเข้าร่วมได้ก่อนล็อก", math.max(0, math.ceil((e.endsAt or now) - now)))
		elseif e.state == "fighting" and inArena() then
			if e.joined then
				showBar = true
				local model = findBoss()
				if model and model:GetAttribute("Open") == true then
					text = "เปิดช่อง! โจมตีเต็มที่"
					color = OPEN_BLUE
				end
			else
				text = "ศึกกำลังดำเนินอยู่ รอรอบหน้า"
			end
		elseif (e.state == "won" or e.state == "reset") and os.clock() < resultUntil then
			text = if e.state == "won" then "ปราบผู้เฝ้าโคมดับสำเร็จ!" else "ผู้เฝ้ากลับสู่ความมืด — เริ่มรอบใหม่ได้"
		end
	end

	local model = if showBar then findBoss() else nil
	if showBar and model then
		local hp = model:GetAttribute("Hp")
		local maxHp = model:GetAttribute("MaxHp")
		if type(hp) == "number" and type(maxHp) == "number" and maxHp > 0 then
			barFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
			barFill.BackgroundColor3 = if model:GetAttribute("Open") == true then OPEN_BLUE else HP_ORANGE
		end
	end
	local visible = (showBar and model ~= nil) or text ~= ""
	frame.Visible = visible
	barBack.Visible = showBar and model ~= nil
	titleLabel.Visible = showBar and model ~= nil
	statusLabel.Text = text
	statusLabel.TextColor3 = color
end

function BossController.Start(deps: Network)
	local gui = make("ScreenGui", (Players.LocalPlayer :: Player):WaitForChild("PlayerGui"), {
		Name = "SpiritWardBoss",
		ResetOnSpawn = false,
		DisplayOrder = 6,
	})
	-- Top centre under the notice line, clear of the HUD panel on the left and
	-- of the thumbstick and action buttons at the bottom.
	frame = make("Frame", gui, {
		Name = "BossBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 98),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Active = false,
		Visible = false,
	})
	make("UISizeConstraint", frame, { MaxSize = Vector2.new(420, math.huge) })
	-- On phone-height screens 98px lands on the horizon band where the boss's
	-- telegraphs project (M2-G touch run), so move into the free middle of the
	-- top bar, clear of the Roblox buttons at the left.
	local camera = workspace.CurrentCamera
	local function layout()
		local vp = camera.ViewportSize
		local compact = vp.Y < COMPACT_HEIGHT
		gui.IgnoreGuiInset = compact
		frame.Position = UDim2.new(0.5, 0, 0, if compact then 4 else 98)
		frame.Size = UDim2.fromOffset(if compact then math.max(240, vp.X - 340) else 420, 0)
	end
	layout()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	make("UICorner", frame, { CornerRadius = UDim.new(0, 8) })
	make("UIPadding", frame, {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	})
	make("UIListLayout", frame, { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) })
	titleLabel = make("TextLabel", frame, {
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.5,
		Text = DEF.displayNameTH,
		Active = false,
	})
	barBack = make("Frame", frame, {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundColor3 = Color3.fromRGB(10, 10, 18),
		BorderSizePixel = 0,
		Active = false,
	})
	barFill = make("Frame", barBack, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = HP_ORANGE,
		BorderSizePixel = 0,
		Active = false,
	})
	statusLabel = make("TextLabel", frame, {
		LayoutOrder = 3,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = AMBER,
		TextStrokeTransparency = 0.5,
		TextWrapped = true,
		Text = "",
		Active = false,
	})

	deps.OnEncounter(function(incoming)
		event = incoming
		if incoming.state == "won" or incoming.state == "reset" then
			resultUntil = os.clock() + RESULT_SEC
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return BossController

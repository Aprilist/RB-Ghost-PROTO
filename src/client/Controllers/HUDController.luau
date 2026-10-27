--!strict
-- HUD driven only by server snapshots: level and EXP, HP, spirit gauge (or
-- transform time left), essence, coins (display only for now, per Director)
-- and skill/dash cooldowns, and (M2-B) season, day and time of day.
-- Times are server clock.
-- Sits top-left so it never overlaps the touch thumbstick or action buttons,
-- and is non-interactive so it never eats camera drags.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Contracts = require(ReplicatedStorage.Shared.Types.Contracts)
local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local Seals = require(ReplicatedStorage.Shared.Definitions.Seals)
local World = require(ReplicatedStorage.Shared.Definitions.World)
local WorldClock = require(ReplicatedStorage.Shared.Util.WorldClock)

type Network = {
	OnSnapshot: ((Contracts.SnapshotEvent) -> ()) -> (),
	GetSnapshot: () -> Contracts.SnapshotEvent?,
}

local HP_RED = Color3.fromRGB(220, 70, 70)
local SPIRIT_BLUE = Color3.fromRGB(110, 170, 255)
local GUARDIAN_WHITE = Color3.fromRGB(225, 240, 255)
local AMBER = Color3.fromRGB(255, 196, 120)
local COIN_GOLD = Color3.fromRGB(240, 210, 120)
local EXP_GREEN = Color3.fromRGB(150, 220, 140)
local PANEL = Color3.fromRGB(24, 22, 40)

local HUDController = {}

type Bar = { fill: Frame, label: TextLabel }

local network: Network
local levelLabel: TextLabel
local xpBar: Bar
local hpBar: Bar
local gaugeBar: Bar
local essenceLabel: TextLabel
local coinLabel: TextLabel
local clockLabel: TextLabel
local sealLabel: TextLabel
local skillChip: TextLabel
local dashChip: TextLabel
local statusLabel: TextLabel

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, textSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = Enum.Font.GothamBold
	l.TextSize = textSize
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.6
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Active = false
	l.Parent = parent
	return l
end

local function bar(parent: Instance, y: number, color: Color3, x: number?, height: number?, textSize: number?): Bar
	local left = x or 8
	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, -(left + 8), 0, height or 18)
	back.Position = UDim2.fromOffset(left, y)
	back.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
	back.BorderSizePixel = 0
	back.Active = false
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Active = false
	fill.Parent = back
	local text = label(back, "", UDim2.fromScale(1, 1), UDim2.fromOffset(6, 0), textSize or 13)
	return { fill = fill, label = text }
end

local function chip(parent: Instance, x: number, y: number): TextLabel
	local c = label(parent, "", UDim2.fromOffset(118, 22), UDim2.fromOffset(x, y), 13)
	c.BackgroundTransparency = 0.3
	c.BackgroundColor3 = Color3.fromRGB(40, 40, 64)
	c.TextXAlignment = Enum.TextXAlignment.Center
	return c
end

local function remaining(endsAt: number?, now: number): number
	return if endsAt then math.max(0, endsAt - now) else 0
end

local function render()
	local snapshot = network.GetSnapshot()
	if not snapshot then
		return
	end
	local s = snapshot.session
	local p = snapshot.profile
	local now = workspace:GetServerTimeNow()

	levelLabel.Text = string.format("Lv %d", p.level)
	local xpToNext = p.xpToNext
	if xpToNext then
		xpBar.fill.Size = UDim2.fromScale(math.clamp(p.xp / xpToNext, 0, 1), 1)
		xpBar.label.Text = string.format("EXP %d / %d", p.xp, xpToNext)
	else
		xpBar.fill.Size = UDim2.fromScale(1, 1)
		xpBar.label.Text = "EXP MAX"
	end

	hpBar.fill.Size = UDim2.fromScale(math.clamp(s.hp / s.maxHp, 0, 1), 1)
	local shield = if s.shieldEndsAt and now < s.shieldEndsAt then s.shieldHp else 0
	hpBar.label.Text = if shield > 0
		then string.format("HP %d / %d  +โล่ %d", s.hp, s.maxHp, shield)
		else string.format("HP %d / %d", s.hp, s.maxHp)

	local transformLeft = remaining(s.transformEndsAt, now)
	if transformLeft > 0 then
		gaugeBar.fill.BackgroundColor3 = GUARDIAN_WHITE
		gaugeBar.fill.Size = UDim2.fromScale(transformLeft / Prototype.Spirit.TransformDurationSec, 1)
		gaugeBar.label.Text = string.format("ร่างผู้พิทักษ์ %.1f วิ", transformLeft)
		gaugeBar.label.TextColor3 = Color3.fromRGB(20, 30, 60)
	else
		gaugeBar.fill.BackgroundColor3 = SPIRIT_BLUE
		gaugeBar.fill.Size = UDim2.fromScale(math.clamp(s.spiritGauge / Prototype.Spirit.GaugeMax, 0, 1), 1)
		gaugeBar.label.Text = string.format("วิญญาณ %d / %d", s.spiritGauge, Prototype.Spirit.GaugeMax)
		gaugeBar.label.TextColor3 = Color3.new(1, 1, 1)
	end

	essenceLabel.Text = string.format("แก่นวิญญาณ %d", p.essence)
	coinLabel.Text = string.format("เหรียญ %d", p.coins)
	-- Same real-time clock as the server lighting (Util/WorldClock).
	local moment = WorldClock.At(now)
	clockLabel.Text = string.format("%s · วันที่ %d · %s", World.Clock.SeasonNamesTH[moment.season] or moment.season, moment.day, WorldClock.Format(moment.hour))

	local sealDef = if p.equippedSealId then Seals[p.equippedSealId] else nil
	if not sealDef then
		sealLabel.Text = "ผนึก: ยังไม่มี"
	else
		local wardLeft = if p.equippedSealId == "ward" then remaining(s.cooldowns.ward, now) else 0
		sealLabel.Text = if wardLeft > 0
			then string.format("ผนึก: %s · คูลดาวน์ %.0f วิ", sealDef.displayNameTH, wardLeft)
			else "ผนึก: " .. sealDef.displayNameTH
	end

	local skillLeft = remaining(s.cooldowns[Prototype.Skill.Id], now)
	skillChip.Text = if skillLeft > 0 then string.format("วิชา E  %.1f", skillLeft) else "วิชา E  พร้อม"
	local dashLeft = remaining(s.cooldowns.dash, now)
	dashChip.Text = if dashLeft > 0 then string.format("พุ่ง Q  %.1f", dashLeft) else "พุ่ง Q  พร้อม"

	if not s.alive then
		statusLabel.Text = "ตายแล้ว — กำลังเกิดใหม่"
		statusLabel.Visible = true
	elseif transformLeft <= 0 and s.spiritGauge >= Prototype.Spirit.GaugeMax then
		statusLabel.Text = "พร้อมแปลงร่าง — กด R"
		-- Pulse so readiness is not shown by colour alone.
		statusLabel.TextTransparency = 0.35 + 0.35 * math.sin(os.clock() * 6)
		statusLabel.Visible = true
	else
		statusLabel.Visible = false
	end
end

function HUDController.Start(deps: Network)
	network = deps

	local gui = Instance.new("ScreenGui")
	gui.Name = "SpiritWardHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(260, 174)
	panel.Position = UDim2.fromOffset(12, 44)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.35
	panel.BorderSizePixel = 0
	panel.Active = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	levelLabel = label(panel, "", UDim2.fromOffset(48, 20), UDim2.fromOffset(10, 5), 15)
	xpBar = bar(panel, 9, EXP_GREEN, 60, 13, 11)
	xpBar.label.TextColor3 = Color3.new(1, 1, 1)
	hpBar = bar(panel, 30, HP_RED)
	gaugeBar = bar(panel, 54, SPIRIT_BLUE)
	essenceLabel = label(panel, "", UDim2.fromOffset(124, 20), UDim2.fromOffset(10, 79), 13)
	essenceLabel.TextColor3 = AMBER
	coinLabel = label(panel, "", UDim2.fromOffset(110, 20), UDim2.fromOffset(140, 79), 13)
	coinLabel.TextColor3 = COIN_GOLD
	skillChip = chip(panel, 8, 106)
	dashChip = chip(panel, 134, 106)
	clockLabel = label(panel, "", UDim2.fromOffset(240, 18), UDim2.fromOffset(10, 132), 12)
	clockLabel.TextColor3 = Color3.fromRGB(210, 214, 240)
	sealLabel = label(panel, "", UDim2.fromOffset(240, 18), UDim2.fromOffset(10, 150), 12)
	sealLabel.TextColor3 = AMBER

	statusLabel = label(gui, "", UDim2.fromOffset(320, 30), UDim2.new(0.5, -160, 0.72, 0), 20)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Center
	statusLabel.TextColor3 = GUARDIAN_WHITE
	statusLabel.Visible = false

	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(render)
end

return HUDController

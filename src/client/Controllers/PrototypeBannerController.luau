--!strict
-- Always-visible "PROTOTYPE — progress resets" label, plus a short local
-- line showing which action was pressed while combat is not wired (P1-A).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)

local PrototypeBannerController = {}

local actionLabel: TextLabel? = nil
local lastShown = 0

function PrototypeBannerController.ShowAction(text: string)
	local label = actionLabel
	if not label then
		return
	end
	label.Text = text
	label.Visible = true
	lastShown += 1
	local shown = lastShown
	task.delay(1.2, function()
		if shown == lastShown then
			label.Visible = false
		end
	end)
end

function PrototypeBannerController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpiritWardPrototypeBanner"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 10

	local banner = Instance.new("TextLabel")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 6)
	banner.Size = UDim2.fromOffset(300, 26)
	banner.BackgroundColor3 = Color3.fromRGB(28, 26, 48)
	banner.BackgroundTransparency = 0.25
	banner.TextColor3 = Color3.fromRGB(255, 196, 120)
	banner.Font = Enum.Font.GothamBold
	banner.TextSize = 14
	banner.Text = Prototype.Label
	banner.Active = false
	banner.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = banner

	local action = Instance.new("TextLabel")
	action.Name = "ActionEcho"
	action.AnchorPoint = Vector2.new(0.5, 0)
	action.Position = UDim2.new(0.5, 0, 0, 38)
	action.Size = UDim2.fromOffset(300, 22)
	action.BackgroundTransparency = 1
	action.TextColor3 = Color3.fromRGB(210, 214, 255)
	action.TextStrokeTransparency = 0.5
	action.Font = Enum.Font.Gotham
	action.TextSize = 14
	action.Visible = false
	action.Active = false
	action.Parent = gui
	actionLabel = action

	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
end

return PrototypeBannerController

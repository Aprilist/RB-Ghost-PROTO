--!strict
-- House plots in the village (M2-B). One plot per player slot: a joining
-- player gets the lowest free plot and a starter house with their name; on
-- leave it goes back to the "free" look. Decorated houses and captured
-- spirits need persistence (later milestone); for now every house is the
-- starter house.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local Project = require(ReplicatedStorage.Shared.Definitions.Project)
local World = require(ReplicatedStorage.Shared.Definitions.World)
local PlotRules = require(script.Parent.Parent.Util.PlotRules)
local Village = require(script.Parent.Parent.Scene.Village)

local PlotService = {}

local COUNT = math.min(#World.Village.plots, Project.TargetPlayersPerServer)

local owners: PlotRules.Plots = {}

local function plotModel(index: number): Model?
	local root = workspace:FindFirstChild(Prototype.WorldNamespace)
	local regions = root and root:FindFirstChild("Regions")
	local village = regions and regions:FindFirstChild("Village")
	local plots = village and village:FindFirstChild("Plots")
	local m = plots and plots:FindFirstChild("Plot" .. index)
	return if m and m:IsA("Model") then m else nil
end

function PlotService.GetPlot(player: Player): number?
	return PlotRules.Find(owners, player.UserId, COUNT)
end

local function onJoin(player: Player)
	local index = PlotRules.Assign(owners, player.UserId, COUNT)
	if not index then
		warn("[PlotService] no free plot for", player.UserId)
		return
	end
	local m = plotModel(index)
	if m then
		m:SetAttribute("OwnerUserId", player.UserId)
		Village.BuildPlotHouse(m, World.Village.plots[index], player.DisplayName)
	end
end

local function onLeave(player: Player)
	local index = PlotRules.Release(owners, player.UserId, COUNT)
	local m = index and plotModel(index)
	if index and m then
		m:SetAttribute("OwnerUserId", 0)
		Village.BuildPlotLocked(m, World.Village.plots[index])
	end
end

function PlotService.Init() end

function PlotService.Start()
	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(onLeave)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
end

PlotService.Count = COUNT

return PlotService

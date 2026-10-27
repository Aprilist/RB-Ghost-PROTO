--!strict
-- World clock (M2-B): drives Lighting from the shared real-time clock
-- (Util/WorldClock) and switches night-only glow and lights. Every server
-- computes the same hour and season, so nothing is replicated by remote;
-- clients read the same clock for the HUD.
-- Seasons: only autumn has built visuals; other seasons show autumn visuals
-- and set the Season attribute so later art passes can hook in.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local World = require(ReplicatedStorage.Shared.Definitions.World)
local WorldClock = require(ReplicatedStorage.Shared.Util.WorldClock)
local Kit = require(script.Parent.Parent.Scene.Kit)
local Sky = require(script.Parent.Parent.Scene.Sky)

local ATMOSPHERE_NAME = Prototype.WorldNamespace .. "Atmosphere"

local WorldClockService = {}

local night: boolean? = nil

local function applyGlow(part: Instance, isNight: boolean)
	if part:IsA("BasePart") then
		part.Material = if isNight then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.Color = if isNight then Kit.Palette.PaperLit else Kit.Palette.Paper
	end
end

local function applyLight(light: Instance, isNight: boolean)
	if light:IsA("Light") then
		light.Enabled = isNight
	end
end

local function setNight(isNight: boolean)
	if night == isNight then
		return
	end
	night = isNight
	for _, p in CollectionService:GetTagged(Kit.NightGlowTag) do
		applyGlow(p, isNight)
	end
	for _, l in CollectionService:GetTagged(Kit.NightLightTag) do
		applyLight(l, isNight)
	end
end

-- One step at server time `now`; exposed for tests.
function WorldClockService.Step(now: number): WorldClock.Moment
	local moment = WorldClock.At(now)
	local k = Sky.At(moment.hour)
	Lighting.ClockTime = moment.hour
	Lighting.Brightness = k.brightness
	Lighting.Ambient = k.ambient
	Lighting.OutdoorAmbient = k.outdoor
	Lighting.ColorShift_Top = k.shiftTop
	Lighting.ColorShift_Bottom = k.shiftBottom
	local atmosphere = Lighting:FindFirstChild(ATMOSPHERE_NAME)
	if atmosphere and atmosphere:IsA("Atmosphere") then
		atmosphere.Color = k.atmColor
		atmosphere.Decay = k.atmDecay
		atmosphere.Density = k.atmDensity
		atmosphere.Haze = k.atmHaze
	end
	workspace:SetAttribute("SpiritWardSeason", moment.season)
	workspace:SetAttribute("SpiritWardVisualSeason", WorldClock.VisualSeason(moment.season))
	setNight(WorldClock.IsNight(moment.hour))
	return moment
end

function WorldClockService.Init() end

function WorldClockService.Start()
	-- Pieces built after a switch (a new owned plot) take the current state.
	CollectionService:GetInstanceAddedSignal(Kit.NightGlowTag):Connect(function(p)
		applyGlow(p, night == true)
	end)
	CollectionService:GetInstanceAddedSignal(Kit.NightLightTag):Connect(function(l)
		applyLight(l, night == true)
	end)
	task.spawn(function()
		while true do
			WorldClockService.Step(workspace:GetServerTimeNow())
			task.wait(World.Clock.LightingStepSec)
		end
	end)
end

return WorldClockService

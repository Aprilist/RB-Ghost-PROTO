--!strict
-- Day/night lighting keys (M2-B). Dusk is the VB-01 look the Director
-- approved; the other keys keep combat readable (outdoor ambient never drops
-- below a cool mid-blue at night). Visual only.

export type Key = {
	hour: number,
	brightness: number,
	ambient: Color3,
	outdoor: Color3,
	shiftTop: Color3,
	shiftBottom: Color3,
	atmColor: Color3,
	atmDecay: Color3,
	atmDensity: number,
	atmHaze: number,
}

local rgb = Color3.fromRGB

local NIGHT = {
	brightness = 1,
	ambient = rgb(44, 48, 86),
	outdoor = rgb(78, 86, 138),
	shiftTop = rgb(130, 150, 230),
	shiftBottom = rgb(40, 48, 100),
	atmColor = rgb(64, 70, 124),
	atmDecay = rgb(24, 26, 66),
	atmDensity = 0.32,
	atmHaze = 1.8,
}
local DAWN = {
	brightness = 1.8,
	ambient = rgb(72, 66, 92),
	outdoor = rgb(132, 122, 152),
	shiftTop = rgb(255, 184, 160),
	shiftBottom = rgb(70, 70, 120),
	atmColor = rgb(160, 136, 172),
	atmDecay = rgb(92, 72, 112),
	atmDensity = 0.3,
	atmHaze = 1.4,
}
local DAY = {
	brightness = 2.6,
	ambient = rgb(92, 92, 104),
	outdoor = rgb(140, 140, 152),
	shiftTop = rgb(255, 240, 220),
	shiftBottom = rgb(90, 96, 120),
	atmColor = rgb(196, 198, 214),
	atmDecay = rgb(110, 118, 136),
	atmDensity = 0.28,
	atmHaze = 1,
}
-- VB-01 values (SceneService.applyLighting).
local DUSK = {
	brightness = 2.2,
	ambient = rgb(58, 60, 96),
	outdoor = rgb(104, 110, 156),
	shiftTop = rgb(255, 196, 150),
	shiftBottom = rgb(60, 70, 120),
	atmColor = rgb(104, 106, 168),
	atmDecay = rgb(46, 42, 96),
	atmDensity = 0.3,
	atmHaze = 1.6,
}

local function key(hour: number, k: { [string]: any }): Key
	local copy = table.clone(k)
	copy.hour = hour
	return copy :: any
end

local Sky = {}

Sky.Keys = {
	key(0, NIGHT),
	key(4.6, NIGHT),
	key(6, DAWN),
	key(8, DAY),
	key(16.4, DAY),
	key(18.4, DUSK),
	key(19.8, NIGHT),
	key(24, NIGHT),
}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Lighting key for `hour`, blended between the two surrounding keys.
function Sky.At(hour: number): Key
	local keys = Sky.Keys
	local h = hour % 24
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if h >= a.hour and h <= b.hour then
			local t = if b.hour > a.hour then (h - a.hour) / (b.hour - a.hour) else 0
			return {
				hour = h,
				brightness = lerp(a.brightness, b.brightness, t),
				ambient = a.ambient:Lerp(b.ambient, t),
				outdoor = a.outdoor:Lerp(b.outdoor, t),
				shiftTop = a.shiftTop:Lerp(b.shiftTop, t),
				shiftBottom = a.shiftBottom:Lerp(b.shiftBottom, t),
				atmColor = a.atmColor:Lerp(b.atmColor, t),
				atmDecay = a.atmDecay:Lerp(b.atmDecay, t),
				atmDensity = lerp(a.atmDensity, b.atmDensity, t),
				atmHaze = lerp(a.atmHaze, b.atmHaze, t),
			}
		end
	end
	return keys[1]
end

return Sky

--!strict
-- Pure world clock (M2-B): unix time → in-game hour, day and season.
-- Server lighting and the client HUD both call this with synced server time
-- (workspace:GetServerTimeNow()), so they always agree without a remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Definitions.World)

local C = World.Clock

export type Moment = {
	hour: number, -- 0 ≤ hour < 24
	day: number, -- 1 .. DaysPerSeason
	season: string,
	seasonIndex: number, -- 1 .. #Seasons
	year: number, -- 1-based
}

local WorldClock = {}

function WorldClock.At(unixTime: number): Moment
	local elapsed = unixTime - C.EpochUnix
	local dayIndex = math.floor(elapsed / C.DaySec)
	local dayFrac = (elapsed - dayIndex * C.DaySec) / C.DaySec
	local seasonCount = #C.Seasons
	local seasonTotal = math.floor(dayIndex / C.DaysPerSeason)
	local seasonIndex = seasonTotal % seasonCount + 1
	return {
		hour = dayFrac * 24,
		day = dayIndex % C.DaysPerSeason + 1,
		season = C.Seasons[seasonIndex],
		seasonIndex = seasonIndex,
		year = math.floor(seasonTotal / seasonCount) + 1,
	}
end

-- Season whose visuals to show: the real one if built, else the first built.
function WorldClock.VisualSeason(season: string): string
	if C.BuiltSeasons[season] then
		return season
	end
	return C.Seasons[1]
end

function WorldClock.IsNight(hour: number): boolean
	return hour < 5.5 or hour >= 18.5
end

-- "18:24" for the HUD.
function WorldClock.Format(hour: number): string
	local minutes = math.floor(hour * 60) % (24 * 60)
	return string.format("%02d:%02d", minutes // 60, minutes % 60)
end

return WorldClock

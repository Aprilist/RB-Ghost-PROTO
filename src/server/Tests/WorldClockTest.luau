--!strict
-- WorldClock tests (pure): real time → hour, day, season, year.
-- Run in Studio (Edit or Play, server Command Bar):
--   require(game.ServerScriptService.Server.Tests.WorldClockTest).Run()
-- Prints one line per case and a summary; returns passed, failed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Definitions.World)
local WorldClock = require(ReplicatedStorage.Shared.Util.WorldClock)

local C = World.Clock
local E = C.EpochUnix
local SEASON_SEC = C.DaySec * C.DaysPerSeason

type Case = { name: string, run: () -> (boolean, string?) }

local cases: { Case } = {
	{
		name = "a season lasts 2 real hours (Director)",
		run = function()
			return SEASON_SEC == 2 * 3600, tostring(SEASON_SEC)
		end,
	},
	{
		name = "epoch is autumn, day 1, 00:00",
		run = function()
			local m = WorldClock.At(E)
			return m.season == "autumn" and m.day == 1 and m.hour == 0 and m.year == 1, m.season
		end,
	},
	{
		name = "half a day later is noon",
		run = function()
			local m = WorldClock.At(E + C.DaySec / 2)
			return math.abs(m.hour - 12) < 1e-9 and m.day == 1, WorldClock.Format(m.hour)
		end,
	},
	{
		name = "day and season roll over",
		run = function()
			local d10 = WorldClock.At(E + C.DaySec * 9 + 1)
			local next = WorldClock.At(E + SEASON_SEC)
			return d10.day == 10 and d10.season == "autumn" and next.day == 1 and next.season == "winter", next.season
		end,
	},
	{
		name = "four seasons make a year, then autumn again",
		run = function()
			local m = WorldClock.At(E + SEASON_SEC * #C.Seasons + 5)
			local summer = WorldClock.At(E + SEASON_SEC * 3)
			return m.season == "autumn" and m.year == 2 and summer.season == "summer", nil
		end,
	},
	{
		name = "times before the epoch stay in range",
		run = function()
			local m = WorldClock.At(E - 1)
			return m.hour >= 0 and m.hour < 24 and m.day == C.DaysPerSeason and m.season == "summer", string.format("%s d%d %.2f", m.season, m.day, m.hour)
		end,
	},
	{
		name = "format and night window",
		run = function()
			return WorldClock.Format(18.4) == "18:24" and WorldClock.Format(0) == "00:00"
				and WorldClock.IsNight(23) and WorldClock.IsNight(3) and not WorldClock.IsNight(12),
				WorldClock.Format(18.4)
		end,
	},
	{
		name = "unbuilt seasons show autumn visuals",
		run = function()
			return WorldClock.VisualSeason("autumn") == "autumn" and WorldClock.VisualSeason("winter") == "autumn", nil
		end,
	},
}

local WorldClockTest = {}

function WorldClockTest.Run(): (number, number)
	local passed, failed = 0, 0
	for _, case in cases do
		local ok, result, detail = pcall(case.run)
		if ok and result then
			passed += 1
			print("[WorldClockTest] PASS", case.name, detail or "")
		else
			failed += 1
			warn("[WorldClockTest] FAIL", case.name, if ok then detail else result)
		end
	end
	print(string.format("[WorldClockTest] %d passed, %d failed", passed, failed))
	return passed, failed
end

return WorldClockTest

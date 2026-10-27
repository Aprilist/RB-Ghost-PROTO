--!strict
-- Negative/positive tests for MovementRules (pure logic, no players needed).
-- Run in Studio (Edit or Play, server Command Bar):
--   require(game.ServerScriptService.Server.Tests.MovementRulesTest).Run()
-- Prints one line per case and a summary; returns passed, failed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local MovementRules = require(script.Parent.Parent.Util.MovementRules)

local M = Prototype.Movement
local WALK = 16
local DT = M.CheckIntervalSec
local DASH = Prototype.Dash.DistanceStuds

local PARAMS: MovementRules.Params = {
	speedTolerance = M.SpeedTolerance,
	slackStuds = M.SlackStuds,
	pendingGraceSec = M.PendingGraceSec,
	dashDistance = DASH,
	dashWindowSec = Prototype.Dash.DurationSec + M.DashLatencyGraceSec,
}

-- Fake map: an infinitely tall wall on the plane X = 10.
local function pathClear(a: Vector3, b: Vector3): boolean
	return (a.X < 10) == (b.X < 10)
end

local EAST = Vector3.new(1, 0, 0)
local NORTH = Vector3.new(0, 0, -1)

-- Feeds {time, position} samples; an accepted dash request is injected at
-- `dashAt` (before the first sample at or after that time).
local function simulate(samples: { { number | Vector3 } }, dashAt: number?, dashDir: Vector3?, dashMax: number?)
	local tracker = MovementRules.NewTracker(Vector3.zero, 0)
	local verdicts = {}
	local restores = {}
	local dashDone = false
	for _, sample in samples do
		local t = sample[1] :: number
		local pos = sample[2] :: Vector3
		if dashAt and not dashDone and t >= dashAt then
			MovementRules.BeginDash(tracker, dashDir or EAST, dashMax or DASH, dashAt, PARAMS)
			dashDone = true
		end
		local verdict, restore = MovementRules.Evaluate(tracker, pos, t, WALK, PARAMS, pathClear)
		table.insert(verdicts, verdict)
		table.insert(restores, restore or false)
	end
	return verdicts, restores, tracker
end

local function has(list: { string }, value: string): boolean
	return table.find(list, value) ~= nil
end

local cases: { { name: string, run: () -> (boolean, string?) } } = {
	{
		name = "walk at normal speed is always accepted",
		run = function()
			local samples = {}
			for i = 1, 12 do
				table.insert(samples, { i * DT, NORTH * (WALK * i * DT) })
			end
			local v = simulate(samples)
			return not has(v, "reconcile") and not has(v, "hold"), table.concat(v, ",")
		end,
	},
	{
		name = "NEG teleport 20 studs without dash → reconcile at once",
		run = function()
			local v, r = simulate({ { DT, NORTH * 20 } })
			return v[1] == "reconcile" and r[1] == Vector3.zero, v[1]
		end,
	},
	{
		name = "NEG predicted dash the server rejected (cooldown) → reconcile after grace",
		run = function()
			local v, r = simulate({ { DT, EAST * 9 }, { 2 * DT, EAST * 9 }, { 3 * DT, EAST * 9 } })
			local idx = table.find(v, "reconcile")
			return idx ~= nil and r[idx :: number] == Vector3.zero, table.concat(v, ",")
		end,
	},
	{
		name = "legit dash seen before its request → held, then accepted",
		run = function()
			local v = simulate({ { DT, EAST * 9 }, { 2 * DT, EAST * 9.5 }, { 3 * DT, EAST * 9.5 }, { 5 * DT, EAST * 9.5 } }, 1.2 * DT, EAST, 9.9)
			return v[1] == "hold" and not has(v, "reconcile"), table.concat(v, ",")
		end,
	},
	{
		name = "legit dash with request first → accepted",
		run = function()
			local v = simulate({ { DT, NORTH * 12 }, { 3 * DT, NORTH * 12 } }, 0.05, NORTH, DASH)
			return not has(v, "reconcile"), table.concat(v, ",")
		end,
	},
	{
		name = "NEG dash further than the server allows → reconcile to dash origin",
		run = function()
			local v, r = simulate({ { DT, NORTH * 25 } }, 0.05, NORTH, DASH)
			return v[1] == "reconcile" and r[1] == Vector3.zero, v[1]
		end,
	},
	{
		name = "NEG dash shortened by wall but client keeps going → reconcile",
		run = function()
			-- Server clear distance is 4 (wall ahead); client reports 12.
			local v = simulate({ { DT, NORTH * 12 } }, 0.05, NORTH, 4)
			return v[1] == "reconcile", v[1]
		end,
	},
	{
		name = "NEG dash sideways to the accepted direction → reconcile",
		run = function()
			local v = simulate({ { DT, Vector3.new(-12, 0, 0) } }, 0.05, NORTH, DASH)
			return v[1] == "reconcile", v[1]
		end,
	},
	{
		name = "NEG walk through wall (small step across X=10) → reconcile",
		run = function()
			local tracker = MovementRules.NewTracker(Vector3.new(9.5, 0, 0), 0)
			local verdict, restore = MovementRules.Evaluate(tracker, Vector3.new(10.5, 0, 0), DT, WALK, PARAMS, pathClear)
			return verdict == "reconcile" and restore == Vector3.new(9.5, 0, 0), verdict
		end,
	},
	{
		name = "NEG dash through wall even within distance → reconcile",
		run = function()
			local tracker = MovementRules.NewTracker(Vector3.new(5, 0, 0), 0)
			MovementRules.BeginDash(tracker, EAST, DASH, 0.01, PARAMS)
			local verdict = MovementRules.Evaluate(tracker, Vector3.new(15, 0, 0), DT, WALK, PARAMS, pathClear)
			return verdict == "reconcile", verdict
		end,
	},
	{
		name = "NEG speed hack 2x walk → reconciled",
		run = function()
			local samples = {}
			for i = 1, 8 do
				table.insert(samples, { i * DT, NORTH * (WALK * 2 * i * DT) })
			end
			local v = simulate(samples)
			return has(v, "reconcile"), table.concat(v, ",")
		end,
	},
	{
		name = "NEG two dashes back-to-back with one accepted → second reconciled",
		run = function()
			-- One accepted dash east, then another 12 studs right after the window closes.
			local window = PARAMS.dashWindowSec
			local v = simulate({ { DT, EAST * 9 }, { window + DT, EAST * 9 }, { window + 2 * DT, EAST * 9 + NORTH * 12 } }, 0.05, EAST, 9.9)
			return v[#v] ~= "accept", table.concat(v, ",")
		end,
	},
	{
		name = "NEG sustained speed 28 cannot repeatedly spend fresh jitter slack",
		run = function()
			local samples = {}
			for i = 1, 12 do
				table.insert(samples, { i * DT, NORTH * (28 * i * DT) })
			end
			local v = simulate(samples)
			return has(v, "reconcile"), table.concat(v, ",")
		end,
	},
	{
		name = "network burst within finite jitter reserve stays valid",
		run = function()
			local v = simulate({ { DT, NORTH * 6 }, { 2 * DT, NORTH * 8 }, { 3 * DT, NORTH * 12 } })
			return not has(v, "reconcile") and not has(v, "hold"), table.concat(v, ",")
		end,
	},
	{
		name = "falling/jumping (vertical only) is never reconciled",
		run = function()
			local v = simulate({ { DT, Vector3.new(0, 8, 0) }, { 2 * DT, Vector3.new(0, -30, 0) } })
			return not has(v, "reconcile") and not has(v, "hold"), table.concat(v, ",")
		end,
	},
}

local MovementRulesTest = {}

function MovementRulesTest.Run(): (number, number)
	local passed, failed = 0, 0
	for _, case in cases do
		local ok, result, detail = pcall(case.run)
		if ok and result then
			passed += 1
			print("[MovementRulesTest] PASS", case.name)
		else
			failed += 1
			warn("[MovementRulesTest] FAIL", case.name, if ok then detail else result)
		end
	end
	print(string.format("[MovementRulesTest] %d passed, %d failed", passed, failed))
	return passed, failed
end

return MovementRulesTest

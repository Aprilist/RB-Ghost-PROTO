--!strict
-- BossRules tests (pure, M2-F part 1): arc and circle hits, the move
-- rotation, where ring circles and summoned helpers land, arena bounds, damage
-- with the opening bonus, the 5% reward rule, and sanity checks on the boss
-- catalog numbers.
-- Run in Studio (Edit or Play, server Command Bar):
--   require(game.ServerScriptService.Server.Tests.BossRulesTest).Run()
-- Prints one line per case and a summary; returns passed, failed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Definitions = ReplicatedStorage.Shared.Definitions
local Bosses = require(Definitions.Bosses)
local Enemies = require(Definitions.Enemies)
local BossRules = require(script.Parent.Parent.Util.BossRules)
local Models = require(script.Parent.Parent.Enemies.Models)

local DEF = Bosses.extinguished_keeper
local ORIGIN = Vector3.new(0, 5, 0)
local FORWARD = Vector3.new(0, 0, 1)

local function inArena(p: Vector3): boolean
	return BossRules.InArena(p, DEF)
end

type Case = { name: string, run: () -> (boolean, string?) }

local cases: { Case } = {
	{
		name = "arc hits in front within reach and arc, not behind, wide or far",
		run = function()
			local s = DEF.sweep
			local front = BossRules.InArc(ORIGIN, FORWARD, Vector3.new(0, 3, s.reachStuds - 1), s.reachStuds, s.arcDeg)
			local far = BossRules.InArc(ORIGIN, FORWARD, Vector3.new(0, 3, s.reachStuds + 1), s.reachStuds, s.arcDeg)
			local behind = BossRules.InArc(ORIGIN, FORWARD, Vector3.new(0, 3, -5), s.reachStuds, s.arcDeg)
			-- 60° off the line is inside a 140° arc (±70°); 80° is outside.
			local function at(deg: number): Vector3
				return Vector3.new(math.sin(math.rad(deg)) * 8, 3, math.cos(math.rad(deg)) * 8)
			end
			local inside = BossRules.InArc(ORIGIN, FORWARD, at(60), s.reachStuds, s.arcDeg)
			local outside = BossRules.InArc(ORIGIN, FORWARD, at(80), s.reachStuds, s.arcDeg)
			local onTop = BossRules.InArc(ORIGIN, FORWARD, Vector3.new(0, 3, 0), s.reachStuds, s.arcDeg)
			return front and not far and not behind and inside and not outside and onTop, nil
		end,
	},
	{
		name = "circle hits inside its radius only, ignoring height",
		run = function()
			local c = Vector3.new(10, 1, 10)
			local r = DEF.ring.radiusStuds
			return BossRules.InCircle(c, Vector3.new(10 + r - 0.1, 8, 10), r) and not BossRules.InCircle(c, Vector3.new(10 + r + 0.1, 1, 10), r), nil
		end,
	},
	{
		name = "moves rotate through the sequence and wrap",
		run = function()
			local seq = DEF.sequence
			local index, order = 1, {}
			for _ = 1, #seq * 2 do
				local move, nextIndex = BossRules.NextMove(seq, index)
				table.insert(order, move)
				index = nextIndex
			end
			local ok = true
			for i, move in order do
				ok = ok and move == seq[((i - 1) % #seq) + 1]
			end
			return ok and index == 1, table.concat(order, ",")
		end,
	},
	{
		name = "ring circles land on players first, then spread; all inside the arena",
		run = function()
			local players = { Vector3.new(5, 3, 5), Vector3.new(-10, 3, 8) }
			local spots = BossRules.RingSpots(players, DEF)
			local alone = BossRules.RingSpots({}, DEF)
			local one = BossRules.RingSpots({ Vector3.new(1, 3, 2) }, DEF)
			local allIn = true
			for _, list in { spots, alone, one } do
				for _, p in list do
					allIn = allIn and inArena(p)
				end
			end
			return #spots == DEF.ring.spots and #alone == DEF.ring.spots and #one == DEF.ring.spots and allIn
				and (spots[1] - Vector3.new(5, 0, 5)).Magnitude < 1e-3 and (spots[2] - Vector3.new(-10, 0, 8)).Magnitude < 1e-3,
				string.format("%d/%d/%d", #spots, #alone, #one)
		end,
	},
	{
		name = "a player hugging the wall still gets a whole circle inside the arena",
		run = function()
			local spots = BossRules.RingSpots({ Vector3.new(49.5, 3, -49.5) }, DEF)
			local edge = DEF.arenaHalfStuds - DEF.ring.radiusStuds
			return math.abs(spots[1].X) <= edge + 1e-6 and math.abs(spots[1].Z) <= edge + 1e-6, tostring(spots[1])
		end,
	},
	{
		name = "summoned helpers appear round the boss inside the arena",
		run = function()
			local spots = BossRules.SummonSpots(Vector3.new(0, 5, -22), DEF.summon.count, DEF)
			local allIn = #spots == DEF.summon.count
			for _, p in spots do
				allIn = allIn and inArena(p)
			end
			local apart = #spots < 2 or (spots[1] - spots[2]).Magnitude > 4
			return allIn and apart, nil
		end,
	},
	{
		name = "open window multiplies damage and damage never exceeds HP left",
		run = function()
			local hp1, a1 = BossRules.ApplyDamage(100, 20, false, 1.5)
			local hp2, a2 = BossRules.ApplyDamage(100, 20, true, 1.5)
			local hp3, a3 = BossRules.ApplyDamage(10, 20, true, 1.5)
			local hp4, a4 = BossRules.ApplyDamage(0, 20, false, 1.5)
			local hp5, a5 = BossRules.ApplyDamage(50, 0, false, 1.5)
			return hp1 == 80 and a1 == 20 and hp2 == 70 and a2 == 30 and hp3 == 0 and a3 == 10 and hp4 == 0 and a4 == 0 and hp5 == 50 and a5 == 0, nil
		end,
	},
	{
		name = "5% of max HP qualifies for the reward, just under does not",
		run = function()
			local f = DEF.rewardMinDamageFraction
			local line = DEF.maxHp * f
			return f == 0.05 and BossRules.Qualifies(line, DEF.maxHp, f) and not BossRules.Qualifies(line - 0.5, DEF.maxHp, f) and not BossRules.Qualifies(0, DEF.maxHp, f),
				tostring(line)
		end,
	},
	{
		name = "boss catalog: moves, timing and numbers are sane",
		run = function()
			local function pos(n: number): boolean
				return n == n and n > 0 and n < math.huge
			end
			local seen: { [string]: boolean } = {}
			for _, m in DEF.sequence do
				seen[m] = true
				if m ~= "sweep" and m ~= "ring" and m ~= "summon" then
					return false, "unknown move " .. m
				end
			end
			if not (seen.sweep and seen.ring and seen.summon) or not seen[DEF.openAfter] then
				return false, "sequence must use all three moves and contain openAfter"
			end
			for _, t in { DEF.sweep.telegraphSec, DEF.ring.telegraphSec, DEF.summon.telegraphSec } do
				if t < 0.8 then
					return false, "telegraph under 0.8 s is not readable"
				end
			end
			local spawnInside = inArena(Vector3.new(DEF.spawnX, 0, DEF.spawnZ))
			local add = Enemies[DEF.summon.addId]
			return pos(DEF.maxHp) and pos(DEF.sweep.damage) and pos(DEF.ring.damage) and pos(DEF.openWindowSec) and DEF.openDamageMultiplier >= 1
				and DEF.sweep.startRangeStuds < DEF.sweep.reachStuds and spawnInside and add ~= nil and not add.draft and Models.Has(DEF.summon.addId)
				and DEF.summon.count <= DEF.summon.maxAlive and DEF.ring.spots >= 1,
				nil
		end,
	},
	{
		name = "solo time to kill at about 20 damage a second is 2 to 4 minutes (draft target)",
		run = function()
			local seconds = DEF.maxHp / 20
			return seconds >= 120 and seconds <= 240, string.format("%.0f s", seconds)
		end,
	},
}

local BossRulesTest = {}

function BossRulesTest.Run(): (number, number)
	local passed, failed = 0, 0
	for _, case in cases do
		local ok, result, detail = pcall(case.run)
		if ok and result then
			passed += 1
			print("[BossRulesTest] PASS", case.name, detail or "")
		else
			failed += 1
			warn("[BossRulesTest] FAIL", case.name, if ok then detail else result)
		end
	end
	print(string.format("[BossRulesTest] %d passed, %d failed", passed, failed))
	return passed, failed
end

return BossRulesTest

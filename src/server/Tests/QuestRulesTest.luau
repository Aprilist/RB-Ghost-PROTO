--!strict
-- QuestRules tests (pure, M2-D): start/prerequisites, objective counting,
-- one-time claim, the giver's "!" / "?" state, and the whole q01–q05 chain
-- with rewards paid through ProfileRules.
-- Run in Studio (Edit or Play, server Command Bar):
--   require(game.ServerScriptService.Server.Tests.QuestRulesTest).Run()
-- Prints one line per case and a summary; returns passed, failed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Quests = require(ReplicatedStorage.Shared.Definitions.Quests)
local QuestRules = require(ReplicatedStorage.Shared.Util.QuestRules)
local ProfileRules = require(script.Parent.Parent.Util.ProfileRules)

type QuestMap = QuestRules.QuestMap

local KEEPER = "npc_shrine_keeper"

local function fresh(): QuestMap
	local quests: QuestMap = {}
	QuestRules.AutoStart(quests)
	return quests
end

-- Brings q01 to claimed: talk, claim.
local function afterQ01(): QuestMap
	local quests = fresh()
	QuestRules.Record(quests, "talk", KEEPER, 1)
	QuestRules.Claim(quests, "q01_meet_keeper")
	return quests
end

type Case = { name: string, run: () -> (boolean, string?) }

local cases: { Case } = {
	{
		name = "first join starts only q01, and only once",
		run = function()
			local quests: QuestMap = {}
			local first = QuestRules.AutoStart(quests)
			local second = QuestRules.AutoStart(quests)
			local count = 0
			for _ in quests do
				count += 1
			end
			return #first == 1 and first[1] == "q01_meet_keeper" and #second == 0 and count == 1
				and quests.q01_meet_keeper.status == "active",
				string.format("%d started, %d entries", #first, count)
		end,
	},
	{
		name = "start needs the prerequisite claimed",
		run = function()
			local quests = fresh()
			local a = QuestRules.Start(quests, "q02_first_hunt")
			QuestRules.Record(quests, "talk", KEEPER, 1)
			local b = QuestRules.Start(quests, "q02_first_hunt") -- q01 ready, not claimed
			QuestRules.Claim(quests, "q01_meet_keeper")
			local c = QuestRules.Start(quests, "q02_first_hunt")
			local d = QuestRules.Start(quests, "q02_first_hunt")
			local e = QuestRules.Start(quests, "no_such_quest")
			return a == "PREREQUISITE" and b == "PREREQUISITE" and c == "OK" and d == "STARTED" and e == "UNKNOWN",
				table.concat({ a, b, c, d, e }, "/")
		end,
	},
	{
		name = "talking to the keeper finishes q01; other NPCs do not",
		run = function()
			local quests = fresh()
			QuestRules.Record(quests, "talk", "npc_smith", 1)
			local before = quests.q01_meet_keeper.status
			local _, ready = QuestRules.Record(quests, "talk", KEEPER, 1)
			return before == "active" and quests.q01_meet_keeper.status == "ready" and #ready == 1, before
		end,
	},
	{
		name = "kills count only for the quest's enemy, cap at the target, then ready",
		run = function()
			local quests = afterQ01()
			QuestRules.Start(quests, "q02_first_hunt")
			local need = Quests.q02_first_hunt.targetCount
			QuestRules.Record(quests, "defeat", "kodama", 1)
			local wrong = quests.q02_first_hunt.progress
			for _ = 1, need - 1 do
				QuestRules.Record(quests, "defeat", "hitodama", 1)
			end
			local almost = quests.q02_first_hunt.status
			QuestRules.Record(quests, "defeat", "hitodama", 1)
			QuestRules.Record(quests, "defeat", "hitodama", 3) -- after ready: ignored
			local r = quests.q02_first_hunt
			return wrong == 0 and almost == "active" and r.status == "ready" and r.progress == need,
				string.format("wrong=%d status=%s progress=%d", wrong, r.status, r.progress)
		end,
	},
	{
		name = "events before a quest is taken do not count",
		run = function()
			local quests = afterQ01()
			QuestRules.Record(quests, "defeat", "hitodama", 4)
			local wanted = QuestRules.Wants(quests, "defeat", "hitodama")
			QuestRules.Start(quests, "q02_first_hunt")
			return quests.q02_first_hunt.progress == 0 and not wanted and QuestRules.Wants(quests, "defeat", "hitodama"), nil
		end,
	},
	{
		name = "zero, negative or NaN amounts change nothing",
		run = function()
			local quests = afterQ01()
			QuestRules.Start(quests, "q02_first_hunt")
			local a = QuestRules.Record(quests, "defeat", "hitodama", 0)
			local b = QuestRules.Record(quests, "defeat", "hitodama", -2)
			local c = QuestRules.Record(quests, "defeat", "hitodama", 0 / 0)
			return #a == 0 and #b == 0 and #c == 0 and quests.q02_first_hunt.progress == 0, nil
		end,
	},
	{
		name = "claim works once and only when ready",
		run = function()
			local quests = fresh()
			local early = QuestRules.Claim(quests, "q01_meet_keeper")
			local missing = QuestRules.Claim(quests, "q02_first_hunt")
			local unknown = QuestRules.Claim(quests, "no_such_quest")
			QuestRules.Record(quests, "talk", KEEPER, 1)
			local ok = QuestRules.Claim(quests, "q01_meet_keeper")
			local again = QuestRules.Claim(quests, "q01_meet_keeper")
			return early == "QUEST_NOT_READY" and missing == "QUEST_NOT_READY" and unknown == "UNKNOWN"
				and ok == "OK" and again == "ALREADY_CLAIMED" and quests.q01_meet_keeper.status == "claimed",
				table.concat({ early, missing, unknown, ok, again }, "/")
		end,
	},
	{
		name = "giver state: claim (?), offer (!), waiting, none; q01 marks the keeper",
		run = function()
			local quests = fresh()
			local s1 = QuestRules.GiverState(quests, KEEPER) -- q01 active, nothing to offer
			local talk = QuestRules.WantsTalk(quests, KEEPER) and not QuestRules.WantsTalk(quests, "npc_smith")
			QuestRules.Record(quests, "talk", KEEPER, 1)
			local s2, id2 = QuestRules.GiverState(quests, KEEPER)
			QuestRules.Claim(quests, "q01_meet_keeper")
			local s3, id3 = QuestRules.GiverState(quests, KEEPER)
			local smith = QuestRules.GiverState(quests, "npc_smith")
			return talk and s1 == "waiting" and s2 == "claim" and id2 == "q01_meet_keeper" and s3 == "offer"
				and id3 == "q02_first_hunt" and smith == "none",
				table.concat({ s1, s2, s3, smith }, "/")
		end,
	},
	{
		name = "apply_seal with target any accepts every seal",
		run = function()
			local quests: QuestMap = {
				q01_meet_keeper = { status = "claimed", progress = 1 },
				q02_first_hunt = { status = "claimed", progress = 5 },
				q03_gather_traces = { status = "claimed", progress = 3 },
				q04_try_seal = { status = "active", progress = 0 },
			}
			local _, ready = QuestRules.Record(quests, "apply_seal", "ward", 1)
			return #ready == 1 and quests.q04_try_seal.status == "ready", nil
		end,
	},
	{
		name = "whole chain q01–q05 with rewards keeps the profile valid",
		run = function()
			local profile = ProfileRules.New(1, "blade")
			QuestRules.AutoStart(profile.quests)
			local events: { { string } } = {
				{ "talk", KEEPER },
				{ "defeat", "hitodama" },
				{ "collect", "veil_trace" },
				{ "apply_seal", "ember" },
				{ "defeat_boss", "extinguished_keeper" },
			}
			local xp, coins, essence = 0, 0, 0
			for i, id in QuestRules.Order() do
				local def = Quests[id]
				if i > 1 and QuestRules.Start(profile.quests, id) ~= "OK" then
					return false, id .. " start"
				end
				for _ = 1, def.targetCount do
					QuestRules.Record(profile.quests, events[i][1], events[i][2], 1)
				end
				if QuestRules.Claim(profile.quests, id) ~= "OK" then
					return false, id .. " claim"
				end
				ProfileRules.AddXp(profile, def.rewardXp)
				ProfileRules.AddCurrency(profile, "coins", def.rewardCoins)
				ProfileRules.AddCurrency(profile, "essence", def.rewardEssence)
				xp += def.rewardXp
				coins += def.rewardCoins
				essence += def.rewardEssence
			end
			local valid, field = ProfileRules.Validate(profile)
			local state = QuestRules.GiverState(profile.quests, KEEPER)
			return valid and state == "none" and profile.coins == coins and profile.essence == essence and profile.level > 1,
				string.format("valid=%s field=%s level=%d xp total=%d", tostring(valid), tostring(field), profile.level, xp)
		end,
	},
}

local QuestRulesTest = {}

function QuestRulesTest.Run(): (number, number)
	local passed, failed = 0, 0
	for _, case in cases do
		local ok, result, detail = pcall(case.run)
		if ok and result then
			passed += 1
			print("[QuestRulesTest] PASS", case.name, detail or "")
		else
			failed += 1
			warn("[QuestRulesTest] FAIL", case.name, if ok then detail else result)
		end
	end
	print(string.format("[QuestRulesTest] %d passed, %d failed", passed, failed))
	return passed, failed
end

return QuestRulesTest

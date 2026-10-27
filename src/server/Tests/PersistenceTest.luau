--!strict
-- Persistence tests (M3-A): lease and fencing between two servers, load
-- failures that must not write, migrations, save round trip and SaveQueue
-- ordering. Uses MemoryStore as a fake DataStore (two ProfileStorage
-- objects over one store = two servers), so this proves the rules, not
-- Roblox DataStore behaviour.
-- Run in Studio (Play, server Command Bar):
--   require(game.ServerScriptService.Server.Tests.PersistenceTest).Run()
-- Prints one line per case and a summary; returns passed, failed.

local Util = script.Parent.Parent.Util
local LeaseRules = require(Util.LeaseRules)
local MemoryStore = require(Util.MemoryStore)
local ProfileMigrations = require(Util.ProfileMigrations)
local ProfileRules = require(Util.ProfileRules)
local ProfileStorage = require(Util.ProfileStorage)
local SaveQueue = require(Util.SaveQueue)

local USER = 4242
local KEY = ProfileStorage.Key(USER)

local now = 1000
local function clock(): number
	return now
end

-- Two servers sharing one store.
local function setup()
	now = 1000
	local store = MemoryStore.new()
	return store, ProfileStorage.new(store, "jobA", clock), ProfileStorage.new(store, "jobB", clock)
end

local function stored(store: MemoryStore.MemoryStore): any
	return store.data[KEY]
end

type Case = { name: string, run: () -> (boolean, string?) }

local cases: { Case } = {
	{
		name = "first join creates a valid profile and takes the lease",
		run = function()
			local store, a = setup()
			local p, token, outcome = a:Load(USER, "blade")
			local env = stored(store)
			return p ~= nil and token ~= nil and outcome == "created" and ProfileRules.Validate(p :: any)
				and env.session.token == token and env.session.jobId == "jobA" and env.envelopeVersion == 1,
				outcome
		end,
	},
	{
		name = "NEG second server cannot take a held lease and writes nothing",
		run = function()
			local store, a, b = setup()
			local _, tokenA = a:Load(USER, "blade")
			local p, tokenB, outcome = b:Load(USER, "blade")
			return p == nil and tokenB == nil and outcome == "held" and stored(store).session.token == tokenA, outcome
		end,
	},
	{
		name = "NEG stale owner cannot save after another server took an expired lease",
		run = function()
			local store, a, b = setup()
			local pA, tokenA = a:Load(USER, "blade")
			now += LeaseRules.LeaseSec + 1
			local pB, tokenB, outcomeB = b:Load(USER, "blade")
			assert(pA and tokenA and pB and tokenB)
			pB.coins = 77
			local saveB = b:Save(USER, tokenB, pB, false)
			pA.coins = 999
			local saveA = a:Save(USER, tokenA, pA, false)
			local env = stored(store)
			return outcomeB == "acquired" and saveB == "saved" and saveA == "lease_lost" and env.profile.coins == 77
				and env.session.token == tokenB,
				string.format("%s/%s/%s coins=%d", outcomeB, saveB, saveA, env.profile.coins)
		end,
	},
	{
		name = "rejoining the same server takes its own lease back",
		run = function()
			local _, a = setup()
			a:Load(USER, "blade")
			local p, _, outcome = a:Load(USER, "blade")
			return p ~= nil and outcome == "acquired", outcome
		end,
	},
	{
		name = "release on leave lets another server load at once with the saved data",
		run = function()
			local store, a, b = setup()
			local p, token = a:Load(USER, "blade")
			assert(p and token)
			p.level, p.xp, p.coins, p.essence = 3, 4, 12, 40
			p.inventory[ProfileRules.StartingWeaponInstanceId].sealId = "ember"
			p.quests.q01_meet_keeper = { status = "claimed", progress = 1 }
			p.checkpointId = "mistwood_checkpoint"
			local saved = a:Save(USER, token, p, true)
			local q, _, outcome = b:Load(USER, "blade")
			return saved == "saved" and stored(store).session ~= nil and outcome == "acquired" and q ~= nil
				and q.level == 3 and q.xp == 4 and q.coins == 12 and q.essence == 40
				and q.inventory[ProfileRules.StartingWeaponInstanceId].sealId == "ember"
				and q.quests.q01_meet_keeper.status == "claimed" and q.checkpointId == "mistwood_checkpoint",
				outcome
		end,
	},
	{
		name = "NEG load error writes no default (missing key stays missing)",
		run = function()
			local store, a = setup()
			store.failNext = 1
			local p, _, outcome = a:Load(USER, "blade")
			return p == nil and outcome == "error" and stored(store) == nil, outcome
		end,
	},
	{
		name = "NEG load error keeps the existing record untouched",
		run = function()
			local store, a, b = setup()
			local p, token = a:Load(USER, "blade")
			assert(p and token)
			p.coins = 55
			a:Save(USER, token, p, true)
			store.failNext = 1
			local q, _, outcome = b:Load(USER, "blade")
			local env = stored(store)
			return q == nil and outcome == "error" and env.profile.coins == 55 and env.session == nil, outcome
		end,
	},
	{
		name = "NEG broken records are refused and never overwritten",
		run = function()
			local store, a = setup()
			local bad: { [string]: any } = {
				notTable = "garbage",
				noProfile = { envelopeVersion = 1 },
				wrongUser = { envelopeVersion = 1, profile = ProfileRules.New(1, "blade"), savedAt = 0 },
				invalid = { envelopeVersion = 1, profile = { schemaVersion = 1, level = 99 }, savedAt = 0 },
				badShape = { envelopeVersion = 1, profile = { schemaVersion = 1, revision = 0, level = 1, xp = 0, coins = 0, essence = 0, inventory = 5 }, savedAt = 0 },
			}
			local out = {}
			for name, record in bad do
				store.data[KEY] = record
				local p, _, outcome = a:Load(USER, "blade")
				-- MemoryStore deep-copies on write, so same reference = never written
				if p ~= nil or stored(store) ~= record or (outcome ~= "bad_record" and outcome ~= "bad_profile") then
					return false, name .. "=" .. outcome
				end
				table.insert(out, name .. "=" .. outcome)
			end
			return true, table.concat(out, " ")
		end,
	},
	{
		name = "NEG a newer envelope or schema is refused, not downgraded",
		run = function()
			local store, a = setup()
			local newer = ProfileRules.New(USER, "blade")
			newer.schemaVersion = 99
			store.data[KEY] = { envelopeVersion = 1, profile = newer, savedAt = 0 }
			local p1, _, o1 = a:Load(USER, "blade")
			local v1 = stored(store).profile.schemaVersion
			store.data[KEY] = { envelopeVersion = 2, profile = ProfileRules.New(USER, "blade"), savedAt = 0 }
			local p2, _, o2 = a:Load(USER, "blade")
			return p1 == nil and o1 == "too_new" and v1 == 99 and p2 == nil and o2 == "too_new"
				and stored(store).envelopeVersion == 2,
				o1 .. "/" .. o2
		end,
	},
	{
		name = "migration steps run one version at a time; gaps and newer are refused",
		run = function()
			local order = {}
			local steps = {
				[1] = function(p: any)
					table.insert(order, "1>2")
					p.added = true
				end,
				[2] = function(p: any)
					table.insert(order, "2>3")
					p.renamed = p.added
				end,
			}
			local migrated = ProfileMigrations.Migrate({ schemaVersion = 1 }, steps, 3)
			local gap = select(2, ProfileMigrations.Migrate({ schemaVersion = 1 }, { [2] = steps[2] }, 3))
			local newer = select(2, ProfileMigrations.Migrate({ schemaVersion = 4 }, steps, 3))
			local junk = select(2, ProfileMigrations.Migrate({ schemaVersion = 1.5 }, steps, 3))
			local current = ProfileMigrations.Load(ProfileRules.New(USER, "blade"))
			return migrated ~= nil and migrated.schemaVersion == 3 and migrated.renamed == true
				and table.concat(order, ",") == "1>2,2>3" and gap == "no_step_1" and newer == "too_new"
				and junk == "schemaVersion" and current ~= nil,
				table.concat(order, ",") .. " " .. tostring(gap)
		end,
	},
	{
		name = "session state (gauge, transform, hp, cooldowns) is never stored",
		run = function()
			local store, a = setup()
			local p, token = a:Load(USER, "blade")
			assert(p and token)
			a:Save(USER, token, p, false)
			local env = stored(store)
			local banned = { "spiritGauge", "transformEndsAt", "hp", "maxHp", "cooldowns", "alive", "profileReady", "shieldHp" }
			for _, field in banned do
				if env[field] ~= nil or env.profile[field] ~= nil then
					return false, field
				end
			end
			local keys = {}
			for k in env do
				table.insert(keys, k)
			end
			table.sort(keys)
			return table.concat(keys, ",") == "envelopeVersion,profile,savedAt,session", table.concat(keys, ",")
		end,
	},
	{
		name = "SaveQueue: a burst during a slow save becomes one more save of the latest value",
		run = function()
			local value, seen = 0, {}
			local q = SaveQueue.new(function()
				local v = value
				task.wait() -- the store call yields
				table.insert(seen, v)
				return "saved"
			end, {})
			value = 1
			q:Request("k")
			for i = 2, 6 do
				value = i
				q:Request("k")
			end
			while q:Busy("k") do
				task.wait()
			end
			return table.concat(seen, ",") == "1,6", table.concat(seen, ",")
		end,
	},
	{
		name = "SaveQueue: errors retry after each delay, lease_lost stops at once",
		run = function()
			local waits, calls = {}, 0
			local q = SaveQueue.new(function()
				calls += 1
				return if calls < 3 then "error" else "saved"
			end, { 1, 2, 4 }, function(sec)
				table.insert(waits, sec)
			end)
			q:Request("k")
			local retried = calls == 3 and table.concat(waits, ",") == "1,2" and not q:Busy("k")
			local lostCalls = 0
			local lost = SaveQueue.new(function()
				lostCalls += 1
				return "lease_lost"
			end, { 1, 2, 4 }, function() end)
			lost:Request("k")
			local gaveUp, giveCalls = 0, 0
			local never = SaveQueue.new(function()
				giveCalls += 1
				return "error"
			end, { 1, 2 }, function()
				gaveUp += 1
			end)
			never:Request("k")
			return retried and lostCalls == 1 and giveCalls == 3 and gaveUp == 2 and not never:Busy("k"),
				string.format("calls=%d waits=%s lost=%d give=%d", calls, table.concat(waits, ","), lostCalls, giveCalls)
		end,
	},
	{
		name = "SaveQueue: release asked during a save is used by the follow-up save",
		run = function()
			local releases = {}
			local q = SaveQueue.new(function(_, release)
				task.wait()
				table.insert(releases, tostring(release))
				return "saved"
			end, {})
			q:Request("k")
			q:Request("k", true)
			while q:Busy("k") do
				task.wait()
			end
			return table.concat(releases, ",") == "false,true", table.concat(releases, ",")
		end,
	},
}

local PersistenceTest = {}

function PersistenceTest.Run(): (number, number)
	local passed, failed = 0, 0
	for _, case in cases do
		local ok, result, detail = pcall(case.run)
		if ok and result then
			passed += 1
			print("[PersistenceTest] PASS", case.name, detail or "")
		else
			failed += 1
			warn("[PersistenceTest] FAIL", case.name, if ok then detail else result)
		end
	end
	print(string.format("[PersistenceTest] %d passed, %d failed", passed, failed))
	return passed, failed
end

return PersistenceTest

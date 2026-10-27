--!strict
-- ProfileV1 owner (M2-A, store + lease M3-A, DataStore M3-B). Profiles load
-- through ProfileStorage (session lease + migration) and save through one
-- SaveQueue: on leave, every AUTOSAVE_SEC (which also renews the lease) and
-- on shutdown. Mode is "datastore" on a published place with API access,
-- else "memory" (Studio only; progress resets when the server closes).
-- Every authoritative change goes through Mutate, which bumps the profile
-- revision, re-checks ProfileRules and rolls back a change that breaks a
-- rule. Listeners hear each committed change once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local Util = script.Parent.Parent.Util
local DataStoreStore = require(Util.DataStoreStore)
local MemoryStore = require(Util.MemoryStore)
local ProfileRules = require(Util.ProfileRules)
local ProfileStorage = require(Util.ProfileStorage)
local SaveQueue = require(Util.SaveQueue)

type ProfileV1 = ProfileRules.ProfileV1

local ProfileService = {}

ProfileService.Mode = "memory" -- set in Init; labelled so nothing claims progress is saved

-- shortcut: one "dev" store for the test place (Director Q1); name the
-- production store before the place is published publicly.
local STORE_NAME = "SpiritWardProfile_dev"
local SAVE_RETRY_SEC = { 1, 2, 4 }
local LOAD_RETRY_SEC = { 1, 2, 4 }
local REJOIN_WAIT_SEC = 10
local AUTOSAVE_SEC = 60 -- Director Q2
local CLOSE_WAIT_SEC = 25
local LEASE_LOST_MESSAGE = "ข้อมูลของคุณถูกเปิดจากเซิร์ฟเวอร์อื่น กรุณาออกแล้วเข้าเกมใหม่"

-- Keyed by UserId so a leaving player's last save can still read it.
type Record = { profile: ProfileV1, token: string, active: boolean }
local records: { [number]: Record } = {}
local mutating: { [Player]: boolean } = {}
local changedListeners: { (Player, ProfileV1) -> () } = {}
local loading: { [number]: boolean } = {}

local storage: ProfileStorage.ProfileStorage

local queue = SaveQueue.new(function(userId: number, release: boolean): string
	local record = records[userId]
	if not record then
		return "saved"
	end
	local outcome = storage:Save(userId, record.token, record.profile, release)
	if outcome == "lease_lost" then
		-- Director Q3: stop rewards at once (Get/Mutate see no profile), then kick.
		warn("[ProfileService] lease lost for", userId, "- progress is no longer saved")
		record.active = false
		local player = Players:GetPlayerByUserId(userId)
		if player then
			task.defer(player.Kick, player, LEASE_LOST_MESSAGE)
		end
	end
	if release and outcome ~= "error" and not record.active then
		records[userId] = nil
	end
	return outcome
end, SAVE_RETRY_SEC)

-- Read-only view for other services; change it only through Mutate.
function ProfileService.Get(player: Player): ProfileV1?
	local record = records[player.UserId]
	return if record and record.active then record.profile else nil
end

local function loadFromStore(player: Player): ProfileV1?
	local userId = player.UserId
	-- Rejoined this server while the leave save still runs: wait for it so
	-- the store, not the older copy, is what loads.
	local waited = 0
	while queue:Busy(userId) and waited < REJOIN_WAIT_SEC do
		waited += task.wait(0.1)
	end
	local profile, token, outcome, detail = storage:Load(userId, Prototype.ClassId)
	-- Only a store error or another server's lease can clear up by itself;
	-- broken or newer records never will.
	local attempt = 0
	while (outcome == "error" or outcome == "held") and attempt < #LOAD_RETRY_SEC and player.Parent ~= nil do
		attempt += 1
		task.wait(LOAD_RETRY_SEC[attempt])
		profile, token, outcome, detail = storage:Load(userId, Prototype.ClassId)
	end
	if not profile or not token then
		warn("[ProfileService] load failed for", userId, outcome, detail or "")
		return nil
	end
	if player.Parent == nil then
		-- left while loading: give the lease straight back
		records[userId] = { profile = profile, token = token, active = false }
		queue:Request(userId, true)
		return nil
	end
	records[userId] = { profile = profile, token = token, active = true }
	return profile
end

-- Loads the profile and takes its lease. Safe to call more than once.
-- Returns nil if it could not be loaded; nothing is written in that case.
function ProfileService.Load(player: Player): ProfileV1?
	local userId = player.UserId
	local existing = records[userId]
	if existing and existing.active then
		return existing.profile
	end
	-- Several services call Load on join; only the first talks to the store,
	-- or a second lease token would fence out the first.
	if loading[userId] then
		while loading[userId] do
			task.wait(0.1)
		end
		return ProfileService.Get(player)
	end
	loading[userId] = true
	local profile = loadFromStore(player)
	loading[userId] = nil
	return profile
end

-- Applies `mutator` to a copy and commits it only if it still passes
-- ProfileRules. Returns false (profile unchanged) if the player has no
-- profile or the result is invalid. Mutations run one at a time per player:
-- the mutator must not yield, and a nested Mutate for the same player errors,
-- so two grants can never interleave on one profile.
function ProfileService.Mutate(player: Player, mutator: (ProfileV1) -> ()): boolean
	local record = records[player.UserId]
	if not record or not record.active then
		return false
	end
	local current = record.profile
	assert(not mutating[player], "ProfileService.Mutate is not re-entrant")
	mutating[player] = true
	local draft = ProfileRules.Clone(current)
	local ran, err = pcall(mutator, draft)
	mutating[player] = nil
	if not ran then
		warn("[ProfileService] mutation error for", player.UserId, err)
		return false
	end
	draft.revision = current.revision + 1
	local ok, field = ProfileRules.Validate(draft)
	if not ok then
		warn("[ProfileService] rejected mutation for", player.UserId, "field", field)
		return false
	end
	record.profile = draft
	for _, callback in changedListeners do
		callback(player, draft)
	end
	return true
end

function ProfileService.OnChanged(callback: (Player, ProfileV1) -> ())
	table.insert(changedListeners, callback)
end

-- DataStore when this server may use it. Studio falls back to memory
-- (unpublished place, API access off); a live server never does, so an
-- outage fails loads closed instead of handing out fresh profiles.
local function pickStore(): (MemoryStore.Store, string, string)
	if RunService:IsStudio() and game.PlaceId == 0 then
		return MemoryStore.new(), "memory", "unpublished place"
	end
	local store, err = DataStoreStore.new(STORE_NAME)
	if store then
		local ok, probeErr = store:Probe()
		if ok or not RunService:IsStudio() then
			return store, "datastore", probeErr or "ok"
		end
		err = probeErr
	end
	assert(RunService:IsStudio(), "[ProfileService] no DataStore on a live server: " .. tostring(err))
	return MemoryStore.new(), "memory", tostring(err)
end

local function anySaveRunning(): boolean
	for userId in records do
		if queue:Busy(userId) then
			return true
		end
	end
	return false
end

function ProfileService.Init()
	local store, mode, why = pickStore()
	ProfileService.Mode = mode
	game:GetService("ReplicatedStorage"):SetAttribute(Prototype.ProfileModeAttribute, mode)
	storage = ProfileStorage.new(store, if game.JobId ~= "" then game.JobId else "studio")
	if ProfileService.Mode == "datastore" then
		print("[ProfileService] datastore mode:", STORE_NAME, why)
	else
		warn("[ProfileService] memory mode: progress resets when the server closes (" .. why .. ")")
	end
end

function ProfileService.Start()
	Players.PlayerRemoving:Connect(function(player)
		mutating[player] = nil
		local record = records[player.UserId]
		if record then
			record.active = false
			queue:Request(player.UserId, true)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SEC)
			for userId, record in records do
				if record.active then
					queue:Request(userId)
				end
			end
		end
	end)

	game:BindToClose(function()
		for userId, record in records do
			record.active = false
			queue:Request(userId, true)
		end
		local waited = 0
		while anySaveRunning() and waited < CLOSE_WAIT_SEC do
			waited += task.wait(0.5)
		end
	end)
end

return ProfileService

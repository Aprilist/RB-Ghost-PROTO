--!strict
-- Load/save one profile through a store with the lease (M3-A). One object
-- per server (jobId); tests make two over one MemoryStore to play two
-- servers. Each call is a single store Update: no retry here, the caller
-- (ProfileService, SaveQueue) decides when to try again.

local HttpService = game:GetService("HttpService")

local LeaseRules = require(script.Parent.LeaseRules)
local MemoryStore = require(script.Parent.MemoryStore)
local ProfileMigrations = require(script.Parent.ProfileMigrations)
local ProfileRules = require(script.Parent.ProfileRules)

local ProfileStorage = {}
ProfileStorage.__index = ProfileStorage

export type LoadOutcome = LeaseRules.AcquireOutcome | "error"
export type SaveOutcome = LeaseRules.SaveOutcome | "error"

export type ProfileStorage = typeof(setmetatable(
	{} :: { store: MemoryStore.Store, jobId: string, clock: () -> number },
	ProfileStorage
))

function ProfileStorage.Key(userId: number): string
	return "u_" .. userId
end

function ProfileStorage.new(store: MemoryStore.Store, jobId: string, clock: (() -> number)?): ProfileStorage
	return setmetatable({ store = store, jobId = jobId, clock = clock or os.time }, ProfileStorage)
end

-- Returns the profile and this session's token when the lease was taken
-- ("created" or "acquired"); otherwise nil and why. Nothing is written for
-- "held", a broken record, or a store error.
function ProfileStorage.Load(
	self: ProfileStorage,
	userId: number,
	classId: string
): (ProfileRules.ProfileV1?, string?, LoadOutcome, string?)
	local token = HttpService:GenerateGUID(false)
	local now = self.clock()
	local profile: any, outcome: LoadOutcome, detail: string? = nil, "error", nil
	local function migrate(stored: any): (any?, string?)
		if stored.userId ~= userId then
			return nil, "userId"
		end
		return ProfileMigrations.Load(stored)
	end
	local ok, err = self.store:Update(ProfileStorage.Key(userId), function(stored)
		local envelope, result, why = LeaseRules.Acquire(stored, self.jobId, token, now, function()
			return ProfileRules.New(userId, classId)
		end, migrate)
		profile, outcome, detail = if envelope then envelope.profile else nil, result, why
		return envelope
	end)
	if not ok then
		return nil, nil, "error", err
	end
	if profile == nil then
		return nil, nil, outcome, detail
	end
	return profile, token, outcome, detail
end

function ProfileStorage.Save(
	self: ProfileStorage,
	userId: number,
	token: string,
	profile: ProfileRules.ProfileV1,
	release: boolean
): SaveOutcome
	local now = self.clock()
	local outcome: SaveOutcome = "error"
	local ok = self.store:Update(ProfileStorage.Key(userId), function(stored)
		local envelope, result = LeaseRules.Save(stored, token, profile, now, release)
		outcome = result
		return envelope
	end)
	return if ok then outcome else "error"
end

return ProfileStorage

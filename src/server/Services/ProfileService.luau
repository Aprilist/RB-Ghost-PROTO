--!strict
-- ProfileV1 owner (M2-A). MEMORY MODE: profiles live only for the server
-- session and reset on leave; DataStore persistence and the session lease are
-- M2-E and wait on DEC-008. Every authoritative change goes through Mutate,
-- which bumps the profile revision, re-checks ProfileRules and rolls back a
-- change that breaks a rule. Listeners hear each committed change once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)
local ProfileRules = require(script.Parent.Parent.Util.ProfileRules)

type ProfileV1 = ProfileRules.ProfileV1

local ProfileService = {}

ProfileService.Mode = "memory" -- labelled so nothing claims progress is saved

local profiles: { [Player]: ProfileV1 } = {}
local mutating: { [Player]: boolean } = {}
local changedListeners: { (Player, ProfileV1) -> () } = {}

-- Read-only view for other services; change it only through Mutate.
function ProfileService.Get(player: Player): ProfileV1?
	return profiles[player]
end

-- Loads (in memory mode: creates) the profile. Safe to call more than once.
function ProfileService.Load(player: Player): ProfileV1
	local existing = profiles[player]
	if existing then
		return existing
	end
	local profile = ProfileRules.New(player.UserId, Prototype.ClassId)
	profiles[player] = profile
	return profile
end

-- Applies `mutator` to a copy and commits it only if it still passes
-- ProfileRules. Returns false (profile unchanged) if the player has no
-- profile or the result is invalid. Mutations run one at a time per player:
-- the mutator must not yield, and a nested Mutate for the same player errors,
-- so two grants can never interleave on one profile.
function ProfileService.Mutate(player: Player, mutator: (ProfileV1) -> ()): boolean
	local current = profiles[player]
	if not current then
		return false
	end
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
	profiles[player] = draft
	for _, callback in changedListeners do
		callback(player, draft)
	end
	return true
end

function ProfileService.OnChanged(callback: (Player, ProfileV1) -> ())
	table.insert(changedListeners, callback)
end

function ProfileService.Init()
	warn("[ProfileService] memory mode: progress resets when you leave (no DataStore yet)")
end

function ProfileService.Start()
	Players.PlayerRemoving:Connect(function(player)
		profiles[player] = nil
		mutating[player] = nil
	end)
end

return ProfileService

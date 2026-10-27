--!strict
-- Stored profile → current ProfileV1 (M3-A, pure). Steps upgrade one
-- version at a time; a profile from a newer server is refused, never
-- downgraded. The result must still pass ProfileRules.Validate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Project = require(ReplicatedStorage.Shared.Definitions.Project)
local ProfileRules = require(script.Parent.ProfileRules)

local ProfileMigrations = {}

-- STEPS[n] upgrades a version-n profile in place to version n+1.
local STEPS: { [number]: (any) -> () } = {}

-- Runs steps on `profile` (in place) up to `target`. Exposed with explicit
-- steps/target so tests can exercise a chain before a real v2 exists.
function ProfileMigrations.Migrate(profile: any, steps: { [number]: (any) -> () }, target: number): (any?, string?)
	local version = profile.schemaVersion
	if type(version) ~= "number" or version ~= math.floor(version) or version < 1 then
		return nil, "schemaVersion"
	end
	if version > target then
		return nil, "too_new"
	end
	while version < target do
		local step = steps[version]
		if not step then
			return nil, "no_step_" .. version
		end
		step(profile)
		version += 1
		profile.schemaVersion = version
	end
	return profile
end

-- What ProfileService uses: the real steps, then the full rule check.
function ProfileMigrations.Load(profile: any): (ProfileRules.ProfileV1?, string?)
	local migrated, err = ProfileMigrations.Migrate(profile, STEPS, Project.ProfileSchemaVersion)
	if migrated == nil then
		return nil, err
	end
	-- Stored data is untrusted in shape: Validate indexes nested tables.
	local ran, ok, field = pcall(ProfileRules.Validate, migrated)
	if not ran then
		return nil, "shape"
	end
	if not ok then
		return nil, field
	end
	return migrated
end

return ProfileMigrations

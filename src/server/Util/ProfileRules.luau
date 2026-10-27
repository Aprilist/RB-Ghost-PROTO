--!strict
-- Pure ProfileV1 rules (docs/CONTRACTS.md "ProfileV1"): defaults, range
-- checks and the level curve. No Instances, no services, so tests can run
-- them directly. ProfileService is the only caller that mutates a live profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Definitions = ReplicatedStorage.Shared.Definitions
local Items = require(Definitions.Items)
local Progression = require(Definitions.Progression)
local Project = require(Definitions.Project)

export type ItemInstance = {
	definitionId: string,
	upgradeLevel: number,
	sealId: string?,
}

export type QuestStatus = "active" | "ready" | "claimed"

export type QuestRecord = {
	status: QuestStatus,
	progress: number,
}

export type ProfileV1 = {
	schemaVersion: number,
	revision: number,
	userId: number,
	classId: string,
	level: number,
	xp: number,
	coins: number,
	essence: number,
	inventory: { [string]: ItemInstance },
	equippedWeaponId: string,
	quests: { [string]: QuestRecord },
	checkpointId: string,
	tutorialCompleted: boolean,
}

export type Currency = "coins" | "essence"

local ProfileRules = {}

ProfileRules.StartingWeaponInstanceId = "w1"
ProfileRules.StartingCheckpointId = "p1_checkpoint"

-- The slice cap (Progression) never exceeds the alpha cap in Project.
ProfileRules.LevelCap = math.min(Progression.LevelCap, Project.AlphaLevelCap)

function ProfileRules.New(userId: number, classId: string): ProfileV1
	return {
		schemaVersion = Project.ProfileSchemaVersion,
		revision = 0,
		userId = userId,
		classId = classId,
		level = 1,
		xp = 0,
		coins = 0,
		essence = 0,
		inventory = {
			[ProfileRules.StartingWeaponInstanceId] = {
				definitionId = Progression.StartingWeaponId,
				upgradeLevel = 0,
			},
		},
		equippedWeaponId = ProfileRules.StartingWeaponInstanceId,
		quests = {},
		checkpointId = ProfileRules.StartingCheckpointId,
		tutorialCompleted = false,
	}
end

-- EXP needed to leave `level`, or nil at the cap.
function ProfileRules.XpToNext(level: number): number?
	if level >= ProfileRules.LevelCap then
		return nil
	end
	return Progression.XpToNext[level]
end

function ProfileRules.MaxHp(level: number): number
	local clamped = math.clamp(math.floor(level), 1, ProfileRules.LevelCap)
	return Progression.MaxHpByLevel[clamped]
end

-- Adds EXP and applies the curve one step at a time. At the cap xp stays 0
-- and the remainder is dropped (contract). Returns levels gained.
function ProfileRules.AddXp(profile: ProfileV1, amount: number): number
	if amount <= 0 then
		return 0
	end
	local gained = 0
	local xp = profile.xp + amount
	local need = ProfileRules.XpToNext(profile.level)
	while need ~= nil and xp >= need do
		xp -= need
		profile.level += 1
		gained += 1
		need = ProfileRules.XpToNext(profile.level)
	end
	profile.xp = if need == nil then 0 else xp
	return gained
end

-- Adds coins or essence up to Project.CurrencyCap. Returns the amount
-- actually added and whether the cap cut it, so the caller can report it
-- instead of granting past the cap silently.
function ProfileRules.AddCurrency(profile: ProfileV1, currency: Currency, amount: number): (number, boolean)
	if amount <= 0 then
		return 0, false
	end
	local before = if currency == "coins" then profile.coins else profile.essence
	local after = math.min(Project.CurrencyCap, before + amount)
	if currency == "coins" then
		profile.coins = after
	else
		profile.essence = after
	end
	return after - before, after - before < amount
end

local function finiteInRange(n: any, low: number, high: number): boolean
	return type(n) == "number" and n == n and n >= low and n <= high and n % 1 == 0
end

-- Checks every ProfileV1 rule. Returns false and the first broken field.
function ProfileRules.Validate(profile: ProfileV1): (boolean, string?)
	if profile.schemaVersion ~= Project.ProfileSchemaVersion then
		return false, "schemaVersion"
	end
	if not finiteInRange(profile.revision, 0, math.huge - 1) then
		return false, "revision"
	end
	if not finiteInRange(profile.level, 1, ProfileRules.LevelCap) then
		return false, "level"
	end
	local need = ProfileRules.XpToNext(profile.level)
	if not finiteInRange(profile.xp, 0, if need then need - 1 else 0) then
		return false, "xp"
	end
	if not finiteInRange(profile.coins, 0, Project.CurrencyCap) then
		return false, "coins"
	end
	if not finiteInRange(profile.essence, 0, Project.CurrencyCap) then
		return false, "essence"
	end
	for instanceId, item in profile.inventory do
		if Items[item.definitionId] == nil then
			return false, "inventory." .. instanceId
		end
		if not finiteInRange(item.upgradeLevel, 0, 10) then
			return false, "inventory." .. instanceId .. ".upgradeLevel"
		end
	end
	local equipped = profile.inventory[profile.equippedWeaponId]
	if not equipped or Items[equipped.definitionId].slot ~= "weapon" then
		return false, "equippedWeaponId"
	end
	for questId, quest in profile.quests do
		if quest.status ~= "active" and quest.status ~= "ready" and quest.status ~= "claimed" then
			return false, "quests." .. questId
		end
		if not finiteInRange(quest.progress, 0, 1000) then
			return false, "quests." .. questId .. ".progress"
		end
	end
	return true, nil
end

-- Deep copy, used to roll back a mutation that breaks a rule.
function ProfileRules.Clone(profile: ProfileV1): ProfileV1
	local copy = table.clone(profile)
	copy.inventory = {}
	for id, item in profile.inventory do
		copy.inventory[id] = table.clone(item)
	end
	copy.quests = {}
	for id, quest in profile.quests do
		copy.quests[id] = table.clone(quest)
	end
	return copy
end

return ProfileRules

--!strict
-- Pure reward rules for normal enemies (docs/CONTRACTS.md "Combat, rewards
-- และ death"): a contributor gets a personal reward only while alive, within
-- RewardRadiusStuds of the death, in the same zone as the enemy, and only if
-- that zone pays rewards. No gauge while transformed. Boss rules come in M2-F.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Definitions = ReplicatedStorage.Shared.Definitions
local Enemies = require(Definitions.Enemies)
local Prototype = require(Definitions.Prototype)
local Zones = require(Definitions.Zones)

export type Grant = {
	xp: number,
	coins: number,
	essence: number,
	gauge: number,
}

export type Check = {
	alive: boolean,
	distance: number?, -- nil when the player has no character root
	playerZoneId: string?,
	enemyZoneId: string?,
}

export type Refusal = "dead" | "far" | "zone" | "zone_closed"

local RewardRules = {}

function RewardRules.Eligible(check: Check): (boolean, Refusal?)
	if not check.alive or check.distance == nil then
		return false, "dead"
	end
	if check.distance > Prototype.Spirit.RewardRadiusStuds then
		return false, "far"
	end
	if check.enemyZoneId == nil or check.playerZoneId ~= check.enemyZoneId then
		return false, "zone"
	end
	local zone = Zones[check.enemyZoneId]
	if not zone or not zone.rewardEligible then
		return false, "zone_closed"
	end
	return true, nil
end

-- The reward one contributor gets for one defeat of `enemyId`.
function RewardRules.ForEnemy(enemyId: string, transformed: boolean): Grant?
	local def = Enemies[enemyId]
	if not def then
		return nil
	end
	return {
		xp = def.xpReward,
		coins = def.coinReward,
		essence = def.essenceReward,
		gauge = if transformed then 0 else def.gaugeReward,
	}
end

return RewardRules

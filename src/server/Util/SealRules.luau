--!strict
-- Pure seal rules (M2-E): buying a seal for a weapon, the ember hit counter,
-- the ward soul counter and the shield pool. No Instances, no services, so
-- tests run them directly. SealService is the only caller that changes a live
-- profile (inside ProfileService.Mutate) or live session state.
--
-- DEC-008 (duplicate apply_seal): the check "this weapon already carries this
-- seal" and the essence charge happen in the same Mutate, so a repeated or
-- replayed request can never charge twice, even after the requestId cache
-- expires. No expected-revision field is needed in the payload.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Definitions.Items)
local Seals = require(ReplicatedStorage.Shared.Definitions.Seals)
local ProfileRules = require(script.Parent.ProfileRules)

type ProfileV1 = ProfileRules.ProfileV1

export type ApplyCode =
	"OK"
	| "INVALID_PAYLOAD"
	| "NOT_OWNED"
	| "ALREADY_SEALED"
	| "INSUFFICIENT_ESSENCE"

local SealRules = {}

-- The NPC whose stall is the seal station (apply_seal range is measured to it).
SealRules.StationNpcId = "npc_smith"
-- Extra distance over the NPC's talk range that apply_seal still accepts.
SealRules.RangeSlackStuds = 6

-- Seal on the equipped weapon, or nil.
function SealRules.EquippedSealId(profile: ProfileV1): string?
	local item = profile.inventory[profile.equippedWeaponId]
	return if item then item.sealId else nil
end

-- Checks and applies in one go; changes `profile` only on "OK". Replacing a
-- different seal costs the new seal's essence again and drops the old one
-- (one seal per weapon). Cost is deducted here, never anywhere else.
function SealRules.Apply(profile: ProfileV1, itemInstanceId: string, sealId: string): ApplyCode
	local seal = Seals[sealId]
	if seal == nil then
		return "INVALID_PAYLOAD"
	end
	local item = profile.inventory[itemInstanceId]
	if item == nil then
		return "NOT_OWNED"
	end
	local def = Items[item.definitionId]
	if def == nil or def.slot ~= "weapon" then
		return "NOT_OWNED"
	end
	if item.sealId == sealId then
		return "ALREADY_SEALED"
	end
	if profile.essence < seal.essenceCost then
		return "INSUFFICIENT_ESSENCE"
	end
	profile.essence -= seal.essenceCost
	item.sealId = sealId
	return "OK"
end

-- Ember: every Nth landed basic hit triggers. Returns the new counter and
-- whether this hit triggers (the counter restarts at 0 on a trigger).
function SealRules.EmberStep(count: number, hitsToBurn: number): (number, boolean)
	local nextCount = count + 1
	if nextCount >= hitsToBurn then
		return 0, true
	end
	return nextCount, false
end

-- Burn never stacks and never refreshes: a new burn is accepted only when the
-- target is not burning right now.
function SealRules.CanIgnite(burnEndsAt: number?, now: number): boolean
	return burnEndsAt == nil or now >= burnEndsAt
end

-- Ward: souls counted only while the cooldown is over. Returns the new
-- counter and whether the shield triggers (counter restarts at 0 on a trigger).
function SealRules.WardStep(souls: number, soulsToShield: number, onCooldown: boolean): (number, boolean)
	if onCooldown then
		return souls, false
	end
	local nextSouls = souls + 1
	if nextSouls >= soulsToShield then
		return 0, true
	end
	return nextSouls, false
end

-- Shield pool: damage eats the shield first while it lasts. Returns the shield
-- HP left, when it ends (nil once gone or expired) and the damage that gets
-- through to HP.
function SealRules.Absorb(shieldHp: number, shieldEndsAt: number?, now: number, amount: number): (number, number?, number)
	if shieldEndsAt == nil or now >= shieldEndsAt or shieldHp <= 0 then
		return 0, nil, amount
	end
	local absorbed = math.min(shieldHp, amount)
	local left = shieldHp - absorbed
	return left, if left > 0 then shieldEndsAt else nil, amount - absorbed
end

-- Shield HP the owner may show right now (0 once expired).
function SealRules.ShieldNow(shieldHp: number, shieldEndsAt: number?, now: number): number
	if shieldEndsAt == nil or now >= shieldEndsAt then
		return 0
	end
	return math.max(0, shieldHp)
end

return SealRules

--!strict
-- Luau types for the P1 subset of docs/CONTRACTS.md v0.2, plus the M2-A
-- profile fields. Implements ready/basic_attack/cast_skill/dash/transform and
-- snapshot/combat_fx. apply_seal, claim_quest and profile lease are out of scope.

export type ActionName = "ready" | "basic_attack" | "cast_skill" | "dash" | "transform"

export type ResultCode =
	"OK"
	| "NOT_READY"
	| "INVALID_PAYLOAD"
	| "RATE_LIMITED"
	| "COOLDOWN"
	| "DEAD"
	| "OUT_OF_RANGE"
	| "NOT_OWNED"
	| "INSUFFICIENT_ESSENCE"
	| "QUEST_NOT_READY"
	| "ALREADY_CLAIMED"
	| "CAP_REACHED"
	| "INTERNAL_ERROR"

export type ReadyPayload = {}
export type BasicAttackPayload = { sequence: number, aimDirection: Vector3 }
export type CastSkillPayload = { skillId: string, aimDirection: Vector3 }
export type DashPayload = { moveDirection: Vector3 }
export type TransformPayload = {}

-- client → server (ActionRequest)
export type ActionRequest = {
	requestId: string,
	action: ActionName,
	payload: { [string]: any },
}

-- server → owner (ActionResult)
export type ActionResult = {
	requestId: string,
	ok: boolean,
	code: ResultCode,
	revision: number,
}

-- The subset of ProfileV1 the owner's HUD needs (M2-A). Progress is still
-- memory-only (ProfileService.Mode). xpToNext is nil at the level cap.
export type PublicOwnProfile = {
	classId: string,
	level: number,
	xp: number,
	xpToNext: number?,
	coins: number,
	essence: number,
}

-- Times are server clock (workspace:GetServerTimeNow()).
export type PublicOwnSession = {
	hp: number,
	maxHp: number,
	alive: boolean,
	spiritGauge: number,
	transformEndsAt: number?,
	cooldowns: { [string]: number }, -- action/skill id → endsAt
	profileReady: boolean,
}

-- revision is a per-server-session counter in P1 (see PROTOTYPE_BRIEF.md);
-- clients drop snapshots with a lower revision than the latest seen.
export type SnapshotEvent = {
	kind: "snapshot",
	revision: number,
	profile: PublicOwnProfile,
	session: PublicOwnSession,
}

export type CombatFxEvent = {
	kind: "combat_fx",
	eventId: string,
	actorUserId: number?,
	enemyId: string?,
	effectId: string,
	position: Vector3,
}

export type StateEvent = SnapshotEvent | CombatFxEvent

return {
	RemoteFolderName = "SpiritWardRemotes",
	ActionRequestName = "ActionRequest",
	ActionResultName = "ActionResult",
	StateEventName = "StateEvent",
	MaxRequestIdBytes = 64,
	DirectionMaxAbsY = 0.01,
	DirectionMinMagnitude = 0.99,
	DirectionMaxMagnitude = 1.01,
	RequestCacheTtlSec = 120,
	-- rate limit: tokens per second / burst, per contract table
	RateLimits = {
		ready = { perSec = 1, burst = 2 },
		basic_attack = { perSec = 6, burst = 6 },
		cast_skill = { perSec = 5, burst = 5 },
		dash = { perSec = 3, burst = 3 },
		transform = { perSec = 1, burst = 2 },
	},
}

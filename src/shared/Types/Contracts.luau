--!strict
-- Luau types for the P1 subset of docs/CONTRACTS.md v0.2, plus the M2-A
-- profile fields and the M2-D quest pieces (claim_quest, profile.quests,
-- StateEvent kinds dialogue and notice; proposed in
-- handoff/M2D_CONTRACT_PROPOSALS.md) and the M2-E seal pieces (apply_seal,
-- ALREADY_SEALED, profile equippedWeaponId/equippedSealId, session shield,
-- StateEvent kind seal_menu; proposed in handoff/M2E_CONTRACT_PROPOSALS.md).
-- Profile lease is out of scope.

export type ActionName =
	"ready"
	| "basic_attack"
	| "cast_skill"
	| "dash"
	| "transform"
	| "claim_quest"
	| "apply_seal"

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
	| "ALREADY_SEALED"
	| "CAP_REACHED"
	| "INTERNAL_ERROR"

export type ReadyPayload = {}
export type BasicAttackPayload = { sequence: number, aimDirection: Vector3 }
export type CastSkillPayload = { skillId: string, aimDirection: Vector3 }
export type DashPayload = { moveDirection: Vector3 }
export type TransformPayload = {}
export type ClaimQuestPayload = { questId: string }
export type ApplySealPayload = { itemInstanceId: string, sealId: string }

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
-- quests (M2-D) is the whole ProfileV1 quests map: questId → {status, progress}.
export type PublicQuestRecord = { status: "active" | "ready" | "claimed", progress: number }

export type PublicOwnProfile = {
	classId: string,
	level: number,
	xp: number,
	xpToNext: number?,
	coins: number,
	essence: number,
	quests: { [string]: PublicQuestRecord },
	-- M2-E: the instance id apply_seal names, and the seal on it (nil = none).
	equippedWeaponId: string,
	equippedSealId: string?,
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
	-- M2-E ward shield: HP left (0 = none) and when it runs out (server clock).
	shieldHp: number,
	shieldEndsAt: number?,
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

-- What an NPC says to the one player who talked to them (M2-D). questId is
-- the quest the lines are about; claimQuestId is set when the player can
-- press "claim" (sends claim_quest).
export type DialogueEvent = {
	kind: "dialogue",
	npcId: string,
	speakerTH: string,
	lines: { string },
	questId: string?,
	claimQuestId: string?,
}

-- One short line for the owner (quest progress, pickup feedback).
export type NoticeEvent = {
	kind: "notice",
	textTH: string,
}

-- Opens the seal menu for the player who used the seal station NPC (M2-E).
-- The menu text comes from Definitions/Seals; money and ownership from the
-- latest snapshot. The server re-checks everything on apply_seal.
export type SealMenuEvent = {
	kind: "seal_menu",
	npcId: string,
	speakerTH: string,
}

-- Boss encounter state for the players in (or just out of) the arena (M2-F).
-- `kind = "encounter"` is in docs/CONTRACTS.md; `joined` is the proposed
-- addition (handoff/M2F_CONTRACT_PROPOSALS.md): false when this player is not
-- part of the fight (arrived after the lock, or died/left it).
--   open      endsAt = when the fight locks (server clock)
--   fighting  the boss is up; HP and open-window state are on the boss model
--   won       the boss is down
--   reset     the fight was abandoned; the boss is back at full HP
export type EncounterState = "open" | "fighting" | "won" | "reset"

export type EncounterEvent = {
	kind: "encounter",
	encounterId: string,
	state: EncounterState,
	endsAt: number?,
	joined: boolean,
}

export type StateEvent = SnapshotEvent | CombatFxEvent | DialogueEvent | NoticeEvent | SealMenuEvent | EncounterEvent

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
		claim_quest = { perSec = 2, burst = 2 },
		apply_seal = { perSec = 2, burst = 2 },
	},
}

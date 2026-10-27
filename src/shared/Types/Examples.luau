--!strict
-- Example packets for P1 and M2-A. Reference only; nothing requires this at runtime.
local Contracts = require(script.Parent.Contracts)

local basicAttack: Contracts.ActionRequest = {
	requestId = "c1-000042",
	action = "basic_attack",
	payload = { sequence = 2, aimDirection = Vector3.new(0, 0, -1) },
}

local dash: Contracts.ActionRequest = {
	requestId = "c1-000043",
	action = "dash",
	payload = { moveDirection = Vector3.new(0.7071, 0, 0.7071) },
}

local cooldownResult: Contracts.ActionResult = {
	requestId = "c1-000043",
	ok = false,
	code = "COOLDOWN",
	revision = 17,
}

local snapshot: Contracts.SnapshotEvent = {
	kind = "snapshot",
	revision = 18,
	profile = { classId = "blade", level = 2, xp = 12, xpToNext = 60, coins = 14, essence = 30 },
	session = {
		hp = 90,
		maxHp = 100,
		alive = true,
		spiritGauge = 30,
		transformEndsAt = nil,
		cooldowns = { dash = 1234.5, blade_sweep = 1238.0 },
		profileReady = true,
	},
}

local hitFx: Contracts.CombatFxEvent = {
	kind = "combat_fx",
	eventId = "fx-000101",
	actorUserId = 1,
	enemyId = "lantern_wisp#7",
	effectId = "slash_hit",
	position = Vector3.new(4, 4, -10),
}

return {
	basicAttack = basicAttack,
	dash = dash,
	cooldownResult = cooldownResult,
	snapshot = snapshot,
	hitFx = hitFx,
}

--!strict
-- Pure encounter rules (M2-F part 2): when the boss fight opens, locks and
-- falls back to waiting, and who is paid when the boss dies (docs/CONTRACTS.md:
-- members only, still alive and in the arena, at least 5% of max HP dealt).
-- No Instances and no services, so tests run them directly. EncounterService
-- is the only caller that acts on the answers.
--
-- States:
--   idle      nobody in the arena; the boss waits
--   open      someone is in; others may still join until the deadline
--   fighting  locked: the members at the deadline, nobody else joins
--   won       the boss is down; the next fight opens after its respawn

local EncounterRules = {}

export type State = "idle" | "open" | "fighting" | "won"

-- Next state from what the encounter sees this tick. `presentCount` is the
-- number of living players in the arena (while open) or living members
-- (while fighting). A fight that loses every member is reset by the boss
-- service, which the encounter hears as `bossReset`; a defeat as `bossDefeated`.
function EncounterRules.Next(
	state: State,
	presentCount: number,
	now: number,
	joinDeadline: number?,
	bossDefeated: boolean,
	bossReset: boolean
): State
	if bossDefeated then
		return "won"
	end
	if bossReset then
		return if presentCount > 0 then "open" else "idle"
	end
	if state == "idle" then
		return if presentCount > 0 then "open" else "idle"
	elseif state == "open" then
		if presentCount == 0 then
			return "idle"
		end
		if joinDeadline ~= nil and now >= joinDeadline then
			return "fighting"
		end
		return "open"
	end
	return state
end

export type Payout = "paid" | "not_member" | "dead" | "left" | "too_little"

-- Whether one player gets the boss reward. Order matters for the reason shown.
function EncounterRules.Payout(member: boolean, alive: boolean, inArena: boolean, damageDealt: number, maxHp: number, fraction: number): Payout
	if not member then
		return "not_member"
	end
	if not alive then
		return "dead"
	end
	if not inArena then
		return "left"
	end
	if damageDealt < maxHp * fraction then
		return "too_little"
	end
	return "paid"
end

return EncounterRules

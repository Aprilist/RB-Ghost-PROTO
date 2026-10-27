--!strict
-- Boss catalog (M2-F). One boss in the slice: the Extinguished Keeper, a
-- masked guardian in a courtyard of cold lanterns (GAME_DESIGN v0.2: three
-- moves, every move telegraphed, an opening after the last one, 2–4 minutes
-- solo). All numbers are draft proposals to tune in playtest.
--
-- The fight loops through `sequence`; each entry names one move table below.
-- After `openAfter` the boss stands still for `openWindowSec` and takes
-- `openDamageMultiplier` times damage. Attack areas are fixed when the
-- telegraph starts, so the warning on the ground is exactly what hits.
--
-- Solo time check (draft): the P1 basic hit is 20 every 0.5 s (40/s at best,
-- about 20/s with dodging); 3000 HP is about 2.5 minutes. TTK is not measured.

export type MoveId = "sweep" | "ring" | "summon"

export type SweepMove = {
	telegraphSec: number,
	recoverSec: number,
	damage: number,
	reachStuds: number, -- measured from the boss's centre on the ground
	arcDeg: number,
	startRangeStuds: number, -- the boss walks until its target is this close
}

export type RingMove = {
	telegraphSec: number,
	recoverSec: number,
	damage: number,
	radiusStuds: number, -- of each circle
	spots: number, -- circles per cast: on players first, then spread round the first
	spreadStuds: number,
}

export type SummonMove = {
	telegraphSec: number,
	recoverSec: number,
	addId: string, -- Definitions/Enemies id of the helper spirit
	count: number,
	maxAlive: number,
	spreadStuds: number,
}

export type BossDef = {
	id: string,
	displayNameTH: string,
	maxHp: number,
	bodyRadiusStuds: number, -- hit tolerance for player attacks
	moveSpeedStudsSec: number,
	arenaCenterX: number,
	arenaCenterZ: number,
	arenaHalfStuds: number, -- the boss and the fight stay inside this square
	spawnX: number,
	spawnZ: number,
	-- M2-F part 2: after the first player steps into the arena the fight stays
	-- open to others for this long, then locks (nobody joins mid-fight).
	joinWindowSec: number,
	gapSec: number, -- pause between a move's recovery and the next move
	sequence: { MoveId },
	openAfter: MoveId,
	openWindowSec: number,
	openDamageMultiplier: number,
	sweep: SweepMove,
	ring: RingMove,
	summon: SummonMove,
	-- Reward for each participant who dealt at least rewardMinDamageFraction
	-- of maxHp and is still alive (docs/CONTRACTS.md). Paid in M2-F part 2.
	rewardXp: number,
	rewardCoins: number,
	rewardEssence: number,
	rewardMinDamageFraction: number,
	resetAfterEmptySec: number, -- nobody alive in the arena for this long → reset
	respawnSec: number, -- after a defeat, until the boss is back for the next fight
	draft: boolean,
}

local Bosses: { [string]: BossDef } = {
	extinguished_keeper = {
		id = "extinguished_keeper",
		displayNameTH = "ผู้เฝ้าโคมดับ",
		maxHp = 3000,
		bodyRadiusStuds = 4,
		moveSpeedStudsSec = 7,
		-- The VB-01 courtyard: 100×100 at the origin. Players come in by the
		-- south gate (+Z), so the boss waits at the far end.
		arenaCenterX = 0,
		arenaCenterZ = 0,
		arenaHalfStuds = 50,
		spawnX = 0,
		spawnZ = -22,
		joinWindowSec = 8,
		gapSec = 0.6,
		sequence = { "sweep", "ring", "sweep", "summon" },
		openAfter = "summon",
		openWindowSec = 3.5,
		openDamageMultiplier = 1.5,
		sweep = {
			telegraphSec = 1.3,
			recoverSec = 0.8,
			damage = 24,
			reachStuds = 15,
			arcDeg = 140,
			startRangeStuds = 12,
		},
		ring = {
			telegraphSec = 1.7,
			recoverSec = 1,
			damage = 22,
			radiusStuds = 6.5,
			spots = 3,
			spreadStuds = 10,
		},
		summon = {
			telegraphSec = 1.5,
			recoverSec = 0.5,
			addId = "lantern_wisp",
			count = 2,
			maxAlive = 2,
			spreadStuds = 9,
		},
		rewardXp = 60,
		rewardCoins = 20,
		rewardEssence = 15,
		rewardMinDamageFraction = 0.05,
		resetAfterEmptySec = 5,
		respawnSec = 45,
		draft = true,
	},
}

return Bosses

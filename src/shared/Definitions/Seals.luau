--!strict
-- Seal catalog (M2-E). Read by SealService (server) and SealController
-- (client menu text). Costs from GAME_DESIGN v0.2 ("ผนึกแรก 30 essence");
-- effect params are proposals to tune in playtest (draft = true).
-- Effect keys: ember = hitsToBurn, burnDps, burnSec;
--              ward  = soulsToShield, shieldHp, shieldSec, cooldownSec.

export type SealDef = {
	id: string,
	displayNameTH: string,
	essenceCost: number,
	effect: { [string]: number },
	draft: boolean,
}

local Seals: { [string]: SealDef } = {
	ember = {
		id = "ember",
		displayNameTH = "ผนึกถ่านไฟ",
		essenceCost = 30,
		-- every Nth landed basic hit applies burn; burn does not stack
		effect = { hitsToBurn = 3, burnDps = 4, burnSec = 3 },
		draft = true,
	},
	ward = {
		id = "ward",
		displayNameTH = "ผนึกปราการ",
		essenceCost = 30,
		-- absorbing N souls grants a shield, then a cooldown
		effect = { soulsToShield = 3, shieldHp = 25, shieldSec = 8, cooldownSec = 15 },
		draft = true,
	},
}

return Seals

--!strict
-- Item catalog (M2-A). Schema proposed in handoff/M2_PLAN_PROPOSAL.md.
-- Skill damage = item baseDamage × skill damageMultiplier.

export type ItemDef = {
	id: string,
	displayNameTH: string,
	slot: "weapon",
	baseDamage: number,
}

local Items: { [string]: ItemDef } = {
	training_blade = {
		id = "training_blade",
		displayNameTH = "คาตานะฝึก",
		slot = "weapon",
		baseDamage = 20,
	},
}

return Items

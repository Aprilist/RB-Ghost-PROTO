--!strict
-- Level curve (M2-A). Director (27 Oct 2026): levels in M2 for testing;
-- slice cap 5, alpha cap stays Project.AlphaLevelCap (10).
-- xpToNext[n] = EXP needed to go from level n to n+1. Level 1 HP is the P1 value.

return table.freeze({
	LevelCap = 5,
	XpToNext = table.freeze({ 30, 60, 100, 150 }),
	MaxHpByLevel = table.freeze({ 100, 110, 120, 130, 140 }),
	StartingWeaponId = "training_blade",
})

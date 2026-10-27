--!strict
-- Level curve. M2-A slice cap was 5; Director 28 Oct 2026: cap 20 for the
-- skill system (GAME_DESIGN "ระบบสกิล"). Levels 1–4 keep the M2 numbers.
-- xpToNext[n] = EXP needed to go from level n to n+1. Level 1 HP is the P1 value.
-- Draft numbers; tune after playtest.

local xpToNext = { 30, 60, 100, 150 }
for level = 5, 19 do
	-- +10 more each level than the step before (210, 280, 360, ...).
	local prev = xpToNext[level - 1]
	table.insert(xpToNext, prev + (prev - xpToNext[level - 2]) + 10)
end

local maxHp = {}
for level = 1, 20 do
	maxHp[level] = 100 + (level - 1) * 10
end

return table.freeze({
	LevelCap = 20,
	XpToNext = table.freeze(xpToNext),
	MaxHpByLevel = table.freeze(maxHp),
	SkillPointsPerLevel = 2,
	StartingWeaponId = "training_blade",
})

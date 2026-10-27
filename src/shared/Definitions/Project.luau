--!strict
-- Planning defaults only. Balance values require playtesting.
return table.freeze({
	ContractVersion = "0.2-draft",
	ProfileSchemaVersion = 2, -- v2 (M4): classChosen, skillPoints, skills
	WorkingTitle = "Spirit Ward",
	PrototypeClassId = "blade",
	CameraMode = "ThirdPerson3D", -- Confirmed DEC-001; controller not implemented.
	Theme = "JapaneseFantasy", -- Japanese theme confirmed; art details are proposed.
	AlphaLevelCap = 20, -- Director 28 Oct 2026 (was 10)
	TargetPlayersPerServer = 12, -- Director 27 Oct 2026: one village house per player, 12 houses.
	SpiritGaugeMax = 100,
	PrototypeGaugePerEnemy = 10,
	TransformDurationSeconds = 12,
	CurrencyCap = 1000000,
})

--!strict
-- VB-01 shared colour language for actors and combat FX (docs/ART_DIRECTION.md).
-- Server visuals (katana, wisp, guardian form) and client FX read from here so
-- the same meaning always has the same colour:
--   player power  indigo-sky / white
--   soul          the HUD spirit-gauge blue, so an orb reads as "fills the gauge"
--   danger        red-orange plus a rim/pulse, kept apart from lantern amber
--   ember         warm amber: lanterns, wisp flame, enemy death
--   level up      pale gold, brighter than ember
-- Visual only: no gameplay value lives here.

local VisualPalette = {
	PlayerSlash = Color3.fromRGB(150, 200, 255),
	PlayerSlashCore = Color3.fromRGB(236, 244, 255),
	HitSpark = Color3.fromRGB(255, 246, 226),
	Soul = Color3.fromRGB(120, 180, 255),
	SoulCore = Color3.fromRGB(220, 236, 255),
	Guardian = Color3.fromRGB(190, 225, 255),
	GuardianAura = Color3.fromRGB(110, 170, 255),
	GuardianMark = Color3.fromRGB(96, 120, 255),

	Danger = Color3.fromRGB(255, 92, 54),
	DangerRim = Color3.fromRGB(255, 56, 40),
	DangerFill = Color3.fromRGB(110, 34, 28),
	DamageFlash = Color3.fromRGB(200, 40, 40),

	-- Progress (M2-A): level-up burst, kept warmer than soul blue
	LevelUp = Color3.fromRGB(255, 228, 150),

	Ember = Color3.fromRGB(255, 176, 84),
	EmberDeath = Color3.fromRGB(255, 196, 120),

	-- Katana
	Steel = Color3.fromRGB(196, 204, 220),
	SteelEdge = Color3.fromRGB(190, 215, 255),
	Iron = Color3.fromRGB(52, 48, 54),
	Gold = Color3.fromRGB(196, 160, 84),
	Wrap = Color3.fromRGB(32, 32, 54),
	Lacquer = Color3.fromRGB(26, 22, 30),
	Cord = Color3.fromRGB(70, 84, 150),

	-- Lantern wisp
	Paper = Color3.fromRGB(240, 226, 186),
	PaperAngry = Color3.fromRGB(255, 132, 84),
	Rib = Color3.fromRGB(92, 64, 48),
	LanternWood = Color3.fromRGB(40, 34, 40),
	WispEye = Color3.fromRGB(255, 238, 190),
	WispMouth = Color3.fromRGB(46, 20, 26),
	WispTongue = Color3.fromRGB(214, 84, 96),

	-- M2-C Mistwood yokai. Ghost fire is green-white so it stays apart from
	-- the blue soul orb and the red-orange danger warning.
	GhostFire = Color3.fromRGB(120, 235, 190),
	GhostFireCore = Color3.fromRGB(228, 255, 240),
	GhostFireEye = Color3.fromRGB(24, 48, 44),
	KodamaSkin = Color3.fromRGB(232, 234, 222),
	KodamaHole = Color3.fromRGB(30, 32, 30),
	KodamaGlow = Color3.fromRGB(200, 240, 210),
	KodamaLeaf = Color3.fromRGB(110, 150, 70),
	Wagasa = Color3.fromRGB(116, 60, 92),
	WagasaDark = Color3.fromRGB(70, 36, 58),
	KarakasaLeg = Color3.fromRGB(196, 170, 140),

	-- M2-F boss (the Extinguished Keeper): dark indigo robe that reddens while
	-- it winds up, a dim half-dead lantern that flares, cracked white mask.
	BossRobe = Color3.fromRGB(34, 30, 56),
	BossRobeAngry = Color3.fromRGB(120, 44, 52),
	BossRobeOpen = Color3.fromRGB(88, 110, 170),
	BossLanternDim = Color3.fromRGB(150, 128, 96),
	BossCrack = Color3.fromRGB(30, 24, 34),

	-- Guardian mask
	MaskWhite = Color3.fromRGB(236, 238, 244),
}

return VisualPalette

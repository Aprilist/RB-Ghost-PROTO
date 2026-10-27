--!strict
-- P1 playable prototype tuning. Every value is a hypothesis to revise after
-- Director playtest (docs/PROTOTYPE_BRIEF.md). UI and services read from here;
-- do not duplicate these numbers elsewhere.
-- M2-A: player, combat, skill, enemy and reward numbers now come from the
-- catalogs (Enemies, Items, Skills, Progression); this file keeps the P1 keys
-- so existing services read the same values. Tests/CatalogTest locks them.

local Enemies = require(script.Parent.Enemies)
local Items = require(script.Parent.Items)
local Progression = require(script.Parent.Progression)
local Skills = require(script.Parent.Skills)

local weapon = Items[Progression.StartingWeaponId]
local basic = Skills.blade_basic
local sweep = Skills.blade_sweep
local wave = Skills.guardian_wave
local wisp = Enemies.lantern_wisp

local Prototype = {
	Label = "PROTOTYPE — progress resets",
	LabelSaved = "PROTOTYPE — progress saved", -- profile on DataStore (M3)
	-- ReplicatedStorage attribute: ProfileService.Mode ("memory" | "datastore")
	ProfileModeAttribute = "ProfileMode",
	WorldNamespace = "SpiritWardPrototype",
	ClassId = "blade",

	Player = {
		MaxHp = Progression.MaxHpByLevel[1],
		RespawnSec = 3,
	},

	Camera = {
		MinZoomStuds = 6,
		MaxZoomStuds = 32,
	},

	Combat = {
		BasicDamage = weapon.baseDamage * basic.damageMultiplier,
		BasicIntervalSec = basic.cooldownSec,
		BasicReachStuds = basic.rangeStuds,
		BasicComboSteps = 3,
		BasicArcDeg = basic.arcDeg,
		ComboResetSec = 1.2,
		-- Server accepts a swing after this fraction of the interval (latency slack).
		CadenceTolerance = 0.85,
		MaxHeightDiffStuds = 4,
		SoftAimConeDeg = 35,
		FxRadiusStuds = 120,
	},

	Skill = {
		Id = sweep.id,
		Damage = weapon.baseDamage * sweep.damageMultiplier,
		CooldownSec = sweep.cooldownSec,
		ReachStuds = sweep.rangeStuds,
		ArcDeg = sweep.arcDeg,
	},

	Dash = {
		DistanceStuds = 12,
		CooldownSec = 1.5,
		Invulnerable = false,
		DurationSec = 0.18,
	},

	-- Server movement authority (MovementService). Walking is checked as an
	-- average over each interval; anything faster must be an accepted dash.
	Movement = {
		CheckIntervalSec = 0.25,
		SpeedTolerance = 1.3,
		SlackStuds = 2.5, -- network jitter per check
		PendingGraceSec = 0.4, -- wait this long for a dash request to explain travel
		DashLatencyGraceSec = 0.4, -- added to Dash.DurationSec for the dash window
		WallProbeLiftStuds = 3, -- second probe above low ledges/cover
		DashProbeRadiusStuds = 1,
	},

	Enemy = {
		Id = wisp.id,
		MaxHp = wisp.maxHp,
		AttackDamage = wisp.attackDamage,
		TelegraphSec = wisp.telegraphSec,
		RecoverSec = wisp.recoverSec,
		RespawnSec = wisp.respawnSec,
		MaxAlive = wisp.tuning.maxAlive,
		AttackRangeStuds = wisp.attackRangeStuds, -- starts telegraph inside this range
		AttackHitRangeStuds = wisp.tuning.attackHitRangeStuds, -- hit check at end of telegraph
		DetectionRangeStuds = wisp.detectionRangeStuds,
		LeashStuds = wisp.tuning.leashStuds,
		MoveSpeedStudsSec = wisp.moveSpeedStudsSec,
		HoverHeightStuds = wisp.tuning.hoverHeightStuds,
		BodyRadiusStuds = wisp.tuning.bodyRadiusStuds,
		AiTickSec = wisp.tuning.aiTickSec,
	},

	Spirit = {
		GaugeMax = 100,
		GaugePerDefeat = wisp.gaugeReward,
		TransformDurationSec = 12,
		TransformAttackReachStuds = wave.rangeStuds,
		TransformAttackDamage = weapon.baseDamage * wave.damageMultiplier,
		TransformAttackArcDeg = wave.arcDeg,
		EssencePerDefeat = wisp.essenceReward,
		RewardRadiusStuds = 120,
	},

	Arena = {
		SizeStuds = 100,
		FloorTopY = 1,
	},

	-- Canonical action → bindings. Touch buttons come from ContextActionService
	-- so they sink touches and never rotate the camera.
	Input = {
		basic_attack = {
			Keys = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 },
			TouchTitle = "ฟัน",
			TouchPosition = UDim2.fromOffset(70, 0),
		},
		cast_skill = {
			Keys = { Enum.KeyCode.E, Enum.KeyCode.ButtonY },
			TouchTitle = "วิชา",
			TouchPosition = UDim2.fromOffset(0, 0),
		},
		dash = {
			Keys = { Enum.KeyCode.Q, Enum.KeyCode.ButtonB },
			TouchTitle = "พุ่ง",
			TouchPosition = UDim2.fromOffset(70, 60),
		},
		transform = {
			Keys = { Enum.KeyCode.R, Enum.KeyCode.ButtonL2 },
			TouchTitle = "แปลง",
			TouchPosition = UDim2.fromOffset(0, 60),
		},
	},
}

return Prototype

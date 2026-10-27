--!strict
-- Server entry (P1 loop + M2-A foundation + M2-B world + M2-C enemies + M2-D quests). Explicit wiring: require all
-- services → Init with dependencies → Start, in order. No framework, no
-- circular requires.

local Services = script.Parent.Services

local SceneService = require(Services.SceneService)
local NetworkService = require(Services.NetworkService)
local ProfileService = require(Services.ProfileService)
local PlayerStateService = require(Services.PlayerStateService)
local PlayerService = require(Services.PlayerService)
local EnemyService = require(Services.EnemyService)
local MovementService = require(Services.MovementService)
local CombatService = require(Services.CombatService)
local SpiritService = require(Services.SpiritService)
local ZoneService = require(Services.ZoneService)
local RewardService = require(Services.RewardService)
local PlotService = require(Services.PlotService)
local WorldClockService = require(Services.WorldClockService)
local QuestService = require(Services.QuestService)
local NpcService = require(Services.NpcService)
local SealService = require(Services.SealService)
local BossService = require(Services.BossService)
local TargetService = require(Services.TargetService)
local EncounterService = require(Services.EncounterService)

SceneService.Init()
NetworkService.Init()
ProfileService.Init()
PlayerStateService.Init({ Network = NetworkService, Profiles = ProfileService })
PlayerService.Init({ SceneService = SceneService })
EnemyService.Init({ Network = NetworkService, PlayerState = PlayerStateService })
MovementService.Init({ PlayerState = PlayerStateService })
BossService.Init({ Network = NetworkService, PlayerState = PlayerStateService, Enemies = EnemyService })
TargetService.Init({ Enemies = EnemyService, Boss = BossService })
CombatService.Init({
	Network = NetworkService,
	PlayerState = PlayerStateService,
	Enemies = TargetService,
	Movement = MovementService,
})
SpiritService.Init({ Network = NetworkService, PlayerState = PlayerStateService })
ZoneService.Init()
RewardService.Init({
	Network = NetworkService,
	PlayerState = PlayerStateService,
	Profiles = ProfileService,
	Enemies = EnemyService,
	Zones = ZoneService,
})
PlotService.Init()
WorldClockService.Init()
QuestService.Init({
	Network = NetworkService,
	Profiles = ProfileService,
	PlayerState = PlayerStateService,
	Rewards = RewardService,
})
SealService.Init({
	Network = NetworkService,
	Profiles = ProfileService,
	PlayerState = PlayerStateService,
	Enemies = TargetService,
	Combat = CombatService,
	Rewards = RewardService,
	Quests = QuestService,
})
EncounterService.Init({
	Network = NetworkService,
	PlayerState = PlayerStateService,
	Boss = BossService,
	Rewards = RewardService,
	Quests = QuestService,
})
NpcService.Init({ Quests = QuestService, PlayerState = PlayerStateService, Seals = SealService })

SceneService.Start() -- courtyard + Mistwood + village
ZoneService.Start() -- needs the arena root
WorldClockService.Start()
ProfileService.Start()
PlayerStateService.Start()
PlayerService.Start()
EnemyService.Start()
BossService.Start() -- needs the scene root
MovementService.Start()
CombatService.Start()
SpiritService.Start()
RewardService.Start()
PlotService.Start()
QuestService.Start() -- after PlayerStateService so profiles exist on join
SealService.Start() -- after Combat/Reward/Quest so their hooks exist
EncounterService.Start() -- takes the boss over from its auto-engage
NpcService.Start() -- needs the scene root
-- Remotes start listening last, once every handler is registered.
NetworkService.Start()

print("[SpiritWard] M2-F server started: courtyard, Mistwood, village, zones, world clock, profile (memory), network, player state, movement, enemies (wisp, hitodama, kodama, karakasa), combat, spirit, rewards, plots, quests, NPCs, seals, boss, encounter.")

-- Studio only: run the pure rule tests and the arena layout check so a Play
-- session prints "[MovementRulesTest] ...", "[SceneLayoutTest] ...",
-- "[CatalogTest] ...", "[ProfileRulesTest] ...", "[RewardRulesTest] ...",
-- "[WorldClockTest] ...", "[PlotRulesTest] ...", "[WorldLayoutTest] ...",
-- "[EnemyAttackRulesTest] ...", "[QuestRulesTest] ...", "[QuestWorldTest] ..."
-- "[SealRulesTest] ...", "[BossRulesTest] ..." and "[EncounterRulesTest] ..."
-- without any manual step.
if game:GetService("RunService"):IsStudio() then
	task.defer(function()
		require(script.Parent.Tests.MovementRulesTest).Run()
		require(script.Parent.Tests.SceneLayoutTest).Run()
		require(script.Parent.Tests.CatalogTest).Run()
		require(script.Parent.Tests.ProfileRulesTest).Run()
		require(script.Parent.Tests.RewardRulesTest).Run()
		require(script.Parent.Tests.WorldClockTest).Run()
		require(script.Parent.Tests.PlotRulesTest).Run()
		require(script.Parent.Tests.WorldLayoutTest).Run()
		require(script.Parent.Tests.EnemyAttackRulesTest).Run()
		require(script.Parent.Tests.QuestRulesTest).Run()
		require(script.Parent.Tests.QuestWorldTest).Run()
		require(script.Parent.Tests.SealRulesTest).Run()
		require(script.Parent.Tests.BossRulesTest).Run()
		require(script.Parent.Tests.EncounterRulesTest).Run()
	end)
end

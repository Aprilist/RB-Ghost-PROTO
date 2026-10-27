--!strict
-- Server entry (P1 loop + M2-A foundation + M2-B world + M2-C enemies). Explicit wiring: require all
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

SceneService.Init()
NetworkService.Init()
ProfileService.Init()
PlayerStateService.Init({ Network = NetworkService, Profiles = ProfileService })
PlayerService.Init({ SceneService = SceneService })
EnemyService.Init({ Network = NetworkService, PlayerState = PlayerStateService })
MovementService.Init({ PlayerState = PlayerStateService })
CombatService.Init({
	Network = NetworkService,
	PlayerState = PlayerStateService,
	Enemies = EnemyService,
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

SceneService.Start() -- courtyard + Mistwood + village
ZoneService.Start() -- needs the arena root
WorldClockService.Start()
ProfileService.Start()
PlayerStateService.Start()
PlayerService.Start()
EnemyService.Start()
MovementService.Start()
CombatService.Start()
SpiritService.Start()
RewardService.Start()
PlotService.Start()
-- Remotes start listening last, once every handler is registered.
NetworkService.Start()

print("[SpiritWard] M2-C server started: courtyard, Mistwood, village, zones, world clock, profile (memory), network, player state, movement, enemies (wisp, hitodama, kodama, karakasa), combat, spirit, rewards, plots.")

-- Studio only: run the pure rule tests and the arena layout check so a Play
-- session prints "[MovementRulesTest] ...", "[SceneLayoutTest] ...",
-- "[CatalogTest] ...", "[ProfileRulesTest] ...", "[RewardRulesTest] ...",
-- "[WorldClockTest] ...", "[PlotRulesTest] ...", "[WorldLayoutTest] ..." and
-- "[EnemyAttackRulesTest] ..."
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
	end)
end

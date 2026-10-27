--!strict
-- Client entry (P1 + M2-D quest UI + M2-E seal menu + M2-F boss bar). Explicit wiring of controllers; no gameplay authority here.

local Controllers = script.Parent.Controllers

local NetworkClient = require(Controllers.NetworkClient)
local CameraController = require(Controllers.CameraController)
local InputController = require(Controllers.InputController)
local EffectsController = require(Controllers.EffectsController)
local CombatController = require(Controllers.CombatController)
local PrototypeBannerController = require(Controllers.PrototypeBannerController)
local HUDController = require(Controllers.HUDController)
local QuestController = require(Controllers.QuestController)
local SealController = require(Controllers.SealController)
local BossController = require(Controllers.BossController)
local ClassController = require(Controllers.ClassController)
local SkillController = require(Controllers.SkillController)

PrototypeBannerController.Start()
CameraController.Start()
EffectsController.Start(NetworkClient)
CombatController.Init({
	Network = NetworkClient,
	Camera = CameraController,
	Effects = EffectsController,
	Banner = PrototypeBannerController,
})
CombatController.Start()
HUDController.Start(NetworkClient)
QuestController.Start(NetworkClient)
SealController.Start(NetworkClient)
BossController.Start(NetworkClient)
ClassController.Start(NetworkClient)
SkillController.Start({ Network = NetworkClient, Combat = CombatController })

if not NetworkClient.Start() then
	if NetworkClient.ProfileNotReady() then
		PrototypeBannerController.ShowAction("โหลดข้อมูลตัวละครไม่ได้ ออกแล้วเข้าใหม่อีกครั้ง", true)
		warn("[SpiritWard] Profile did not load (ready answered NOT_READY).")
	else
		PrototypeBannerController.ShowAction("เชื่อม server ไม่ได้ ลองออกแล้วเข้าใหม่", true)
		warn("[SpiritWard] Could not reach server remotes or ready failed.")
	end
	return
end

InputController.OnAction(CombatController.Handle)
InputController.Start()

print("[SpiritWard] P1 client started: network ready, combat input active.")

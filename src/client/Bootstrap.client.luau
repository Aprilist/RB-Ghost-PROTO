--!strict
-- P1 client entry. Explicit wiring of controllers; no gameplay authority here.

local Controllers = script.Parent.Controllers

local NetworkClient = require(Controllers.NetworkClient)
local CameraController = require(Controllers.CameraController)
local InputController = require(Controllers.InputController)
local EffectsController = require(Controllers.EffectsController)
local CombatController = require(Controllers.CombatController)
local PrototypeBannerController = require(Controllers.PrototypeBannerController)
local HUDController = require(Controllers.HUDController)

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

if not NetworkClient.Start() then
	PrototypeBannerController.ShowAction("เชื่อม server ไม่ได้ ลองออกแล้วเข้าใหม่")
	warn("[SpiritWard] Could not reach server remotes or ready failed.")
	return
end

InputController.OnAction(CombatController.Handle)
InputController.Start()

print("[SpiritWard] P1 client started: network ready, combat input active.")

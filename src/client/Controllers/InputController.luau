--!strict
-- Maps keyboard/mouse/gamepad/touch to canonical actions (Prototype.Input).
-- Movement, jump and camera stay on the standard Roblox controls.
-- Touch buttons come from ContextActionService using its default layout
-- around the jump button; they sink their touches, so pressing them never rotates the camera.
-- CombatController turns these actions into server requests.
-- M4: keys 1–5 fire "skill_1".."skill_5" (hotbar; E stays slot 1). They have
-- no CAS touch button: touch players tap the hotbar (SkillController).

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prototype = require(ReplicatedStorage.Shared.Definitions.Prototype)

export type ActionName = "basic_attack" | "cast_skill" | "dash" | "transform" | string

local ORDER: { ActionName } = { "basic_attack", "cast_skill", "dash", "transform" }

local InputController = {}

local listeners: { (ActionName) -> () } = {}

function InputController.OnAction(callback: (ActionName) -> ())
	table.insert(listeners, callback)
end

local function fire(action: ActionName)
	for _, callback in listeners do
		task.spawn(callback, action)
	end
end

function InputController.Start()
	for _, action in ORDER do
		local binding = Prototype.Input[action]
		local bindName = "SpiritWard_" .. action
		ContextActionService:BindAction(bindName, function(_, state: Enum.UserInputState, input: InputObject)
			if state == Enum.UserInputState.Begin then
				fire(action)
			end
			-- Sink touch so the camera never sees it; pass mouse/keys so default controls still work.
			if input.UserInputType == Enum.UserInputType.Touch then
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, true, table.unpack(binding.Keys))
		ContextActionService:SetTitle(bindName, binding.TouchTitle)
		-- Explicit compact layout: CAS defaults can place the fourth action
		-- below the safe viewport on landscape phones (observed on iPhone XR).
		ContextActionService:SetPosition(bindName, binding.TouchPosition)
	end
	local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }
	for slot, key in keys do
		ContextActionService:BindAction("SpiritWard_skill_" .. slot, function(_, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				fire("skill_" .. slot)
			end
			return Enum.ContextActionResult.Pass
		end, false, key)
	end
end

return InputController

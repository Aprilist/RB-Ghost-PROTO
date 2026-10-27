--!strict
-- One-time class pick (M4, pure). Director 28 Oct 2026: pick on first join,
-- no changing back. ClassService dry-runs this on a copy, then runs it again
-- inside Mutate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Definitions.Classes)
local ProfileRules = require(script.Parent.ProfileRules)

export type ChooseCode = "OK" | "INVALID_PAYLOAD" | "NOT_OWNED" | "CLASS_LOCKED"

local ClassRules = {}

function ClassRules.Choose(profile: ProfileRules.ProfileV1, classId: string): ChooseCode
	local class = Classes.Get(classId)
	if not class then
		return "INVALID_PAYLOAD"
	end
	if not class.available then
		return "NOT_OWNED"
	end
	if profile.classChosen then
		return "CLASS_LOCKED"
	end
	profile.classId = class.id
	profile.classChosen = true
	return "OK"
end

return ClassRules

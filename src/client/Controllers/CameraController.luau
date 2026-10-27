--!strict
-- Standard Roblox third-person camera (zoom limits and Zoom occlusion are set
-- by the server in PlayerService). This controller only exposes the flat aim
-- direction that combat requests send, per the contract direction rules.
-- Soft aim inside a cone is added with combat in P1-B.

local CameraController = {}

local function flatten(v: Vector3): Vector3?
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude < 1e-3 then
		return nil
	end
	return flat.Unit
end

-- Unit Vector3 on X/Z from the camera look direction, falling back to the
-- character facing when the camera points straight down.
function CameraController.GetAimDirection(rootPart: BasePart?): Vector3
	local camera = workspace.CurrentCamera
	local aim = camera and flatten(camera.CFrame.LookVector)
	if aim then
		return aim
	end
	local facing = rootPart and flatten(rootPart.CFrame.LookVector)
	return facing or Vector3.new(0, 0, -1)
end

function CameraController.Start() end

return CameraController

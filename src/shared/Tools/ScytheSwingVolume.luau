--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local toolsFolder = sharedFolder:WaitForChild("Tools") :: Folder

local ScytheConfig = require(toolsFolder:WaitForChild("ScytheConfig") :: ModuleScript)

export type SwingHitboxSlice = {
	cframe: CFrame,
	size: Vector3,
}

local SWING_HITBOX_SLICE_COUNT = 7
local MINIMUM_SLICE_WIDTH = 0.2
local MINIMUM_SLICE_DEPTH = 0.15

local ScytheSwingVolume = {}

local function getPlanarOriginCFrame(originCFrame: CFrame): CFrame?
	local lookVector = originCFrame.LookVector
	local planarLookVector = Vector3.new(lookVector.X, 0, lookVector.Z)
	if planarLookVector.Magnitude <= 0.001 then
		return nil
	end

	return CFrame.lookAt(originCFrame.Position, originCFrame.Position + planarLookVector.Unit, Vector3.yAxis)
end

function ScytheSwingVolume.getSwingHitboxSlices(originCFrame: CFrame): { SwingHitboxSlice }
	local planarOriginCFrame = getPlanarOriginCFrame(originCFrame)
	if planarOriginCFrame == nil then
		return {}
	end

	local slices = table.create(SWING_HITBOX_SLICE_COUNT)
	local height = ScytheConfig.swingVerticalTolerance * 2
	local tangent = math.tan(math.rad(ScytheConfig.swingHalfAngleDegrees))

	for sliceIndex = 1, SWING_HITBOX_SLICE_COUNT do
		local nearAlpha = (sliceIndex - 1) / SWING_HITBOX_SLICE_COUNT
		local farAlpha = sliceIndex / SWING_HITBOX_SLICE_COUNT
		local nearDistance = nearAlpha * ScytheConfig.swingRange
		local farDistance = farAlpha * ScytheConfig.swingRange
		local centerDistance = (nearDistance + farDistance) * 0.5
		local sliceDepth = math.max(farDistance - nearDistance, MINIMUM_SLICE_DEPTH)
		local sliceWidth = math.max(2 * centerDistance * tangent, MINIMUM_SLICE_WIDTH)

		slices[sliceIndex] = {
			cframe = planarOriginCFrame * CFrame.new(0, 0, -centerDistance),
			size = Vector3.new(sliceWidth, height, sliceDepth),
		}
	end

	return slices
end

return table.freeze(ScytheSwingVolume)

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsCodeFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingTypes = require(buildingsCodeFolder:WaitForChild("BuildingTypes") :: ModuleScript)

type BuildingId = BuildingTypes.BuildingId

local VISUAL_MODEL_NAMES: { string } = {
	"CurrentVisual",
	"NextVisual",
	"PreviousVisual",
}

local function destroyReplicatedServerVisuals(rootPart: BasePart)
	for _, visualModelName in ipairs(VISUAL_MODEL_NAMES) do
		local visual = rootPart:FindFirstChild(visualModelName)
		if visual ~= nil then
			visual:Destroy()
		end
	end
end

local BuildingVisualService = {}

function BuildingVisualService.setGrowthStageVisual(rootPart: BasePart, _buildingId: BuildingId, _stageModelName: string)
	destroyReplicatedServerVisuals(rootPart)
end

return table.freeze(BuildingVisualService)

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsCodeFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingAssetUtils = require(buildingsCodeFolder:WaitForChild("BuildingAssetUtils") :: ModuleScript)
local BuildingCatalog = require(buildingsCodeFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsCodeFolder:WaitForChild("BuildingTypes") :: ModuleScript)

type BuildingDefinition = BuildingTypes.BuildingDefinition
type BuildingId = BuildingTypes.BuildingId

local VISUAL_MODEL_NAME = "CurrentVisual"
local PLACEMENT_BOX_NAME = "PlacementBox"

local function setBasePartVisualProperties(basePart: BasePart)
	basePart.Anchored = true
	basePart.CanCollide = false
	basePart.CanQuery = false
	basePart.CanTouch = false
	basePart.CastShadow = false
end

local BuildingVisualService = {}

function BuildingVisualService.setGrowthStageVisual(rootPart: BasePart, buildingId: BuildingId, stageModelName: string)
	local existingVisual = rootPart:FindFirstChild(VISUAL_MODEL_NAME)
	if existingVisual ~= nil then
		existingVisual:Destroy()
	end

	local buildingDefinition = BuildingCatalog.getBuildingDefinition(buildingId)
	local stageModel = BuildingAssetUtils.getStageModel(buildingDefinition, stageModelName):Clone()
	BuildingAssetUtils.normalizeStageModel(stageModel)
	stageModel.Name = VISUAL_MODEL_NAME
	stageModel:PivotTo(rootPart.CFrame)

	for _, descendant in ipairs(stageModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			setBasePartVisualProperties(descendant)
			if descendant.Name == PLACEMENT_BOX_NAME then
				descendant.Transparency = 1
			end
		end
	end

	stageModel.Parent = rootPart
end

return table.freeze(BuildingVisualService)

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsCodeFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local buildingAssetsFolder = ReplicatedStorage:WaitForChild("Buildings") :: Folder

local BuildingTypes = require(buildingsCodeFolder:WaitForChild("BuildingTypes") :: ModuleScript)

type BuildingDefinition = BuildingTypes.BuildingDefinition

local PLACEMENT_BOX_NAME = "PlacementBox"

local BuildingAssetUtils = {}

function BuildingAssetUtils.getStageModel(buildingDefinition: BuildingDefinition, stageModelName: string): Model
	local buildingFolder = buildingAssetsFolder:WaitForChild(buildingDefinition.growthVisualConfig.assetFolderName) :: Folder
	local stageModel = buildingFolder:WaitForChild(stageModelName)
	assert(stageModel:IsA("Model"), string.format("%s.%s must be a Model", buildingDefinition.growthVisualConfig.assetFolderName, stageModelName))

	return stageModel
end

function BuildingAssetUtils.getPlacementBox(model: Model): BasePart
	local placementBox = model:FindFirstChild(PLACEMENT_BOX_NAME, true)
	assert(placementBox ~= nil and placementBox:IsA("BasePart"), string.format("%s must contain a BasePart named %s", model.Name, PLACEMENT_BOX_NAME))

	return placementBox
end

function BuildingAssetUtils.getPlacementFootprint(buildingDefinition: BuildingDefinition): Vector3
	local stageModel = BuildingAssetUtils.getStageModel(buildingDefinition, buildingDefinition.growthVisualConfig.stages[1].modelName)
	local placementBox = BuildingAssetUtils.getPlacementBox(stageModel)
	return placementBox.Size
end

function BuildingAssetUtils.normalizeStageModel(model: Model)
	local placementBox = BuildingAssetUtils.getPlacementBox(model)
	model.PrimaryPart = placementBox
end

return table.freeze(BuildingAssetUtils)

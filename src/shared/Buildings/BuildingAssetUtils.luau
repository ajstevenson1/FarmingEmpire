--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsCodeFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local buildingAssetsFolder = ReplicatedStorage:WaitForChild("Buildings") :: Folder

local BuildingTypes = require(buildingsCodeFolder:WaitForChild("BuildingTypes") :: ModuleScript)

type BuildingDefinition = BuildingTypes.BuildingDefinition

local PLACEMENT_BOX_NAME = "PlacementBox"
local missingAssetWarnings: { [string]: boolean } = {}

local BuildingAssetUtils = {}

local function warnMissingAssetOnce(assetKey: string)
	if missingAssetWarnings[assetKey] == true then
		return
	end

	missingAssetWarnings[assetKey] = true
	warn(string.format("[BuildingAssetUtils] Missing building asset %s, using placeholder visuals", assetKey))
end

local function createPlaceholderStageModel(buildingDefinition: BuildingDefinition, stageModelName: string): Model
	local model = Instance.new("Model")
	model.Name = stageModelName

	local placementBox = Instance.new("Part")
	placementBox.Name = PLACEMENT_BOX_NAME
	placementBox.Size = buildingDefinition.placementSize
	placementBox.Transparency = 1
	placementBox.Anchored = true
	placementBox.CanCollide = false
	placementBox.CanQuery = false
	placementBox.CanTouch = false
	placementBox.Parent = model

	local visibleBody = Instance.new("Part")
	visibleBody.Name = "PlaceholderBody"
	visibleBody.Size = Vector3.new(
		math.max(2, buildingDefinition.placementSize.X * 0.7),
		math.max(2, buildingDefinition.placementSize.Y * 0.7),
		math.max(2, buildingDefinition.placementSize.Z * 0.7)
	)
	visibleBody.Color = Color3.fromRGB(184, 154, 107)
	visibleBody.Material = Enum.Material.WoodPlanks
	visibleBody.Anchored = true
	visibleBody.CanCollide = false
	visibleBody.CanQuery = false
	visibleBody.CanTouch = false
	visibleBody.Position = placementBox.Position + Vector3.new(0, (visibleBody.Size.Y - placementBox.Size.Y) * 0.5, 0)
	visibleBody.Parent = model

	return model
end

function BuildingAssetUtils.getStageModel(buildingDefinition: BuildingDefinition, stageModelName: string): Model
	local buildingFolder = buildingAssetsFolder:FindFirstChild(buildingDefinition.growthVisualConfig.assetFolderName)
	if buildingFolder == nil or not buildingFolder:IsA("Folder") then
		warnMissingAssetOnce(buildingDefinition.growthVisualConfig.assetFolderName)
		return createPlaceholderStageModel(buildingDefinition, stageModelName)
	end

	local stageModel = buildingFolder:FindFirstChild(stageModelName)
	if stageModel == nil or not stageModel:IsA("Model") then
		warnMissingAssetOnce(string.format("%s/%s", buildingDefinition.growthVisualConfig.assetFolderName, stageModelName))
		return createPlaceholderStageModel(buildingDefinition, stageModelName)
	end

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

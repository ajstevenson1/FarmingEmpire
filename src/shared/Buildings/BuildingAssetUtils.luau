--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsCodeFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingTypes = require(buildingsCodeFolder:WaitForChild("BuildingTypes") :: ModuleScript)

type BuildingDefinition = BuildingTypes.BuildingDefinition
type SingleBuildingVisualConfig = BuildingTypes.SingleBuildingVisualConfig
type StagedBuildingVisualConfig = BuildingTypes.StagedBuildingVisualConfig

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

local function createPlaceholderModel(buildingDefinition: BuildingDefinition, modelName: string): Model
	local model = Instance.new("Model")
	model.Name = modelName

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

local function findCategoryFolder(categoryFolderName: string): Folder?
	local directCategoryFolder = ReplicatedStorage:FindFirstChild(categoryFolderName)
	if directCategoryFolder ~= nil and directCategoryFolder:IsA("Folder") then
		return directCategoryFolder
	end

	local legacyBuildingsFolder = ReplicatedStorage:FindFirstChild("Buildings")
	if legacyBuildingsFolder == nil or not legacyBuildingsFolder:IsA("Folder") then
		return nil
	end

	local legacyCategoryFolder = legacyBuildingsFolder:FindFirstChild(categoryFolderName)
	if legacyCategoryFolder == nil or not legacyCategoryFolder:IsA("Folder") then
		return nil
	end

	return legacyCategoryFolder
end

local function findAssetFolder(categoryFolder: Folder, assetName: string): Folder?
	local assetFolder = categoryFolder:FindFirstChild(assetName)
	if assetFolder == nil or not assetFolder:IsA("Folder") then
		return nil
	end

	return assetFolder
end

local function findModel(parent: Instance, modelName: string): Model?
	local model = parent:FindFirstChild(modelName)
	if model == nil or not model:IsA("Model") then
		return nil
	end

	return model
end

local function getStagedVisualModel(
	buildingDefinition: BuildingDefinition,
	visualConfig: StagedBuildingVisualConfig,
	stageModelName: string
): Model
	local categoryFolder = findCategoryFolder(visualConfig.categoryFolderName)
	if categoryFolder == nil then
		warnMissingAssetOnce(visualConfig.categoryFolderName)
		return createPlaceholderModel(buildingDefinition, stageModelName)
	end

	local assetFolder = findAssetFolder(categoryFolder, visualConfig.assetName)
	if assetFolder ~= nil then
		local stageModel = findModel(assetFolder, stageModelName)
		if stageModel ~= nil then
			return stageModel
		end
	end

	local fallbackAssetFolder = findAssetFolder(categoryFolder, visualConfig.fallbackAssetName)
	if fallbackAssetFolder ~= nil then
		local fallbackStageModel = findModel(fallbackAssetFolder, stageModelName)
		if fallbackStageModel ~= nil then
			if assetFolder == nil then
				warnMissingAssetOnce(string.format("%s/%s", visualConfig.categoryFolderName, visualConfig.assetName))
			else
				warnMissingAssetOnce(string.format("%s/%s/%s", visualConfig.categoryFolderName, visualConfig.assetName, stageModelName))
			end

			return fallbackStageModel
		end
	end

	warnMissingAssetOnce(string.format("%s/%s/%s", visualConfig.categoryFolderName, visualConfig.assetName, stageModelName))
	return createPlaceholderModel(buildingDefinition, stageModelName)
end

local function getSingleVisualModel(buildingDefinition: BuildingDefinition, visualConfig: SingleBuildingVisualConfig): Model
	local categoryFolder = findCategoryFolder(visualConfig.categoryFolderName)
	if categoryFolder == nil then
		warnMissingAssetOnce(visualConfig.categoryFolderName)
		return createPlaceholderModel(buildingDefinition, visualConfig.assetName)
	end

	local model = findModel(categoryFolder, visualConfig.assetName)
	if model ~= nil then
		return model
	end

	local fallbackModel = findModel(categoryFolder, visualConfig.fallbackAssetName)
	if fallbackModel ~= nil then
		warnMissingAssetOnce(string.format("%s/%s", visualConfig.categoryFolderName, visualConfig.assetName))
		return fallbackModel
	end

	warnMissingAssetOnce(string.format("%s/%s", visualConfig.categoryFolderName, visualConfig.assetName))
	return createPlaceholderModel(buildingDefinition, visualConfig.assetName)
end

function BuildingAssetUtils.getVisualModel(buildingDefinition: BuildingDefinition, stageModelName: string?): Model
	local visualConfig = buildingDefinition.visualConfig
	if visualConfig.kind == "Staged" then
		local stagedModelName = stageModelName
		assert(stagedModelName ~= nil, string.format("%s requires a staged visual model name", buildingDefinition.id))
		return getStagedVisualModel(buildingDefinition, visualConfig, stagedModelName)
	end

	return getSingleVisualModel(buildingDefinition, visualConfig)
end

function BuildingAssetUtils.getPlacementPreviewModel(buildingDefinition: BuildingDefinition): Model
	local visualConfig = buildingDefinition.visualConfig
	if visualConfig.kind == "Staged" then
		return BuildingAssetUtils.getVisualModel(buildingDefinition, visualConfig.placementPreviewStageModelName)
	end

	return BuildingAssetUtils.getVisualModel(buildingDefinition, nil)
end

local function getFootprintSourceModel(buildingDefinition: BuildingDefinition): Model
	local visualConfig = buildingDefinition.visualConfig
	if visualConfig.kind == "Staged" then
		return BuildingAssetUtils.getVisualModel(buildingDefinition, visualConfig.stages[1].modelName)
	end

	return BuildingAssetUtils.getVisualModel(buildingDefinition, nil)
end

function BuildingAssetUtils.getPlacementBox(model: Model): BasePart
	local placementBox = model:FindFirstChild(PLACEMENT_BOX_NAME, true)
	assert(placementBox ~= nil and placementBox:IsA("BasePart"), string.format("%s must contain a BasePart named %s", model.Name, PLACEMENT_BOX_NAME))

	return placementBox
end

function BuildingAssetUtils.getPlacementFootprint(buildingDefinition: BuildingDefinition): Vector3
	local placementBox = BuildingAssetUtils.getPlacementBox(getFootprintSourceModel(buildingDefinition))
	return placementBox.Size
end

function BuildingAssetUtils.normalizeStageModel(model: Model)
	local placementBox = BuildingAssetUtils.getPlacementBox(model)
	model.PrimaryPart = placementBox
end

return table.freeze(BuildingAssetUtils)

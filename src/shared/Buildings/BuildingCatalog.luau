--!strict

local BuildingTypes = require(script.Parent.BuildingTypes)
local progressionFolder = script.Parent.Parent:WaitForChild("Progression") :: Folder
local ProgressionConfig = require(progressionFolder:WaitForChild("ProgressionConfig") :: ModuleScript)

type BuildingDefinition = BuildingTypes.BuildingDefinition
type BuildingId = BuildingTypes.BuildingId
type GrowthVisualStage = BuildingTypes.GrowthVisualStage
type SingleBuildingVisualConfig = BuildingTypes.SingleBuildingVisualConfig
type StagedBuildingVisualConfig = BuildingTypes.StagedBuildingVisualConfig
type MillTierDefinition = ProgressionConfig.MillTierDefinition
type TreeTierDefinition = ProgressionConfig.TreeTierDefinition

local TREES_CATEGORY_FOLDER_NAME = "Trees"
local MILLS_CATEGORY_FOLDER_NAME = "Mills"
local OAK_TREE_ASSET_NAME = "OakTree"
local CIDER_MILL_ASSET_NAME = "CiderMill"
local SINGLE_VISUAL_STAGE_NAME = "Single"
local MAX_APPLE_HARVEST_EFFECT_COUNT = 3

local TREE_STAGES: { GrowthVisualStage } = table.freeze({
	table.freeze({
		modelName = "Stage0",
		minProgress = 0,
	}),
	table.freeze({
		modelName = "Stage1",
		minProgress = 0.2,
	}),
	table.freeze({
		modelName = "Stage2",
		minProgress = 0.4,
	}),
	table.freeze({
		modelName = "Stage3",
		minProgress = 0.6,
	}),
	table.freeze({
		modelName = "Stage4",
		minProgress = 0.8,
	}),
	table.freeze({
		modelName = "Stage5",
		minProgress = 1,
	}),
})

local SINGLE_VISUAL_STAGE: GrowthVisualStage = table.freeze({
	modelName = SINGLE_VISUAL_STAGE_NAME,
	minProgress = 0,
})

local TREE_PLACEMENT_PREVIEW_STAGE_MODEL_NAME = "Stage5"

local function createStagedTreeVisualConfig(assetName: string): StagedBuildingVisualConfig
	return table.freeze({
		kind = "Staged",
		categoryFolderName = TREES_CATEGORY_FOLDER_NAME,
		assetName = assetName,
		fallbackAssetName = OAK_TREE_ASSET_NAME,
		stages = TREE_STAGES,
		placementPreviewStageModelName = TREE_PLACEMENT_PREVIEW_STAGE_MODEL_NAME,
	}) :: StagedBuildingVisualConfig
end

local function createSingleMillVisualConfig(assetName: string): SingleBuildingVisualConfig
	return table.freeze({
		kind = "Single",
		categoryFolderName = MILLS_CATEGORY_FOLDER_NAME,
		assetName = assetName,
		fallbackAssetName = CIDER_MILL_ASSET_NAME,
	}) :: SingleBuildingVisualConfig
end

local function createAppleTreeDefinition(treeDefinition: TreeTierDefinition): BuildingDefinition
	return table.freeze({
		id = treeDefinition.id,
		displayName = treeDefinition.displayName,
		sellPrice = treeDefinition.sellPrice,
		placementSize = Vector3.new(6, 6, 6),
		productionConfig = table.freeze({
			behaviorId = "TimedStorageProducer",
			produceIntervalSeconds = ProgressionConfig.getTreeProduceIntervalSeconds(),
			outputResourceId = "Apple",
			outputAmountPerInterval = treeDefinition.fruitPerInterval,
			storageCap = treeDefinition.storageCap,
		}),
		offlineEarningsConfig = table.freeze({
			ciderPerSecond = treeDefinition.offlineCiderPerSecond,
		}),
		visualConfig = createStagedTreeVisualConfig(treeDefinition.id),
		harvestVisualConfig = table.freeze({
			appleModelName = treeDefinition.appleModelName,
			maxAppleEffectCount = MAX_APPLE_HARVEST_EFFECT_COUNT,
		}),
	})
end

local function createCiderMillDefinition(millDefinition: MillTierDefinition): BuildingDefinition
	return table.freeze({
		id = millDefinition.id,
		displayName = millDefinition.displayName,
		sellPrice = millDefinition.sellPrice,
		placementSize = Vector3.new(4, 6, 4),
		productionConfig = table.freeze({
			behaviorId = "InputProcessor",
			cycleDurationSeconds = 1,
			inputResourceId = "Apple",
			inputAmount = millDefinition.inputAmount,
			outputResourceId = "Cider",
			outputAmount = millDefinition.outputAmount,
			outputStorageMode = "Unlimited",
			idleStatusText = "Idle",
			blockedStatusText = "Need apples",
		}),
		offlineEarningsConfig = table.freeze({
			ciderPerSecond = millDefinition.offlineCiderPerSecond,
		}),
		visualConfig = createSingleMillVisualConfig(millDefinition.id),
		harvestVisualConfig = nil,
	})
end

local buildingsById: { [BuildingId]: BuildingDefinition } = {}

for _, treeDefinition: TreeTierDefinition in ipairs(ProgressionConfig.getTreeDefinitions()) do
	buildingsById[treeDefinition.id] = createAppleTreeDefinition(treeDefinition)
end

for _, millDefinition: MillTierDefinition in ipairs(ProgressionConfig.getMillDefinitions()) do
	buildingsById[millDefinition.id] = createCiderMillDefinition(millDefinition)
end

local BuildingCatalog = {}

function BuildingCatalog.getBuildingDefinition(buildingId: BuildingId): BuildingDefinition
	return buildingsById[buildingId]
end

function BuildingCatalog.getGrowthStageForProgress(buildingDefinition: BuildingDefinition, progress: number): GrowthVisualStage
	local visualConfig = buildingDefinition.visualConfig
	if visualConfig.kind == "Single" then
		return SINGLE_VISUAL_STAGE
	end

	local clampedProgress = math.clamp(progress, 0, 1)
	local selectedStage = visualConfig.stages[1]

	for _, stage in ipairs(visualConfig.stages) do
		if clampedProgress >= stage.minProgress then
			selectedStage = stage
		else
			break
		end
	end

	return selectedStage
end

function BuildingCatalog.hasBuildingDefinition(buildingId: string): boolean
	return buildingsById[buildingId :: BuildingId] ~= nil
end

function BuildingCatalog.getAllBuildingDefinitions(): { [BuildingId]: BuildingDefinition }
	return buildingsById
end

return table.freeze(BuildingCatalog)

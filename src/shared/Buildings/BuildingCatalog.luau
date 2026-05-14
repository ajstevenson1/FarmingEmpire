--!strict

local BuildingTypes = require(script.Parent.BuildingTypes)
local progressionFolder = script.Parent.Parent:WaitForChild("Progression") :: Folder
local ProgressionConfig = require(progressionFolder:WaitForChild("ProgressionConfig") :: ModuleScript)

type BuildingDefinition = BuildingTypes.BuildingDefinition
type BuildingId = BuildingTypes.BuildingId
type GrowthVisualStage = BuildingTypes.GrowthVisualStage
type VisualVariantConfig = BuildingTypes.VisualVariantConfig
type MillTierDefinition = ProgressionConfig.MillTierDefinition
type TreeTierDefinition = ProgressionConfig.TreeTierDefinition

local TREE_STAGES: { GrowthVisualStage } = table.freeze({
	table.freeze({
		modelName = "Stage0",
		minProgress = 0,
	}),
	table.freeze({
		modelName = "Stage1",
		minProgress = 0.1,
	}),
	table.freeze({
		modelName = "Stage2",
		minProgress = 0.5,
	}),
	table.freeze({
		modelName = "Stage3",
		minProgress = 1,
	}),
})

local CIDER_MILL_STAGES: { GrowthVisualStage } = table.freeze({
	table.freeze({
		modelName = "Stage0",
		minProgress = 0,
	}),
	table.freeze({
		modelName = "Stage1",
		minProgress = 0.01,
	}),
})

local function createTreeVisualVariant(leafColor: Color3, fruitColor: Color3, fallbackColor: Color3): VisualVariantConfig
	return table.freeze({
		fallbackColor = fallbackColor,
		fallbackMaterial = nil,
		tintRules = table.freeze({
			table.freeze({
				partNameContains = "leaf",
				color = leafColor,
				material = Enum.Material.Grass,
			}),
			table.freeze({
				partNameContains = "leaves",
				color = leafColor,
				material = Enum.Material.Grass,
			}),
			table.freeze({
				partNameContains = "canopy",
				color = leafColor,
				material = Enum.Material.Grass,
			}),
			table.freeze({
				partNameContains = "apple",
				color = fruitColor,
				material = Enum.Material.SmoothPlastic,
			}),
			table.freeze({
				partNameContains = "fruit",
				color = fruitColor,
				material = Enum.Material.SmoothPlastic,
			}),
		}),
	})
end

local function createMillVisualVariant(accentColor: Color3, fallbackColor: Color3, fallbackMaterial: Enum.Material?): VisualVariantConfig
	return table.freeze({
		fallbackColor = fallbackColor,
		fallbackMaterial = fallbackMaterial,
		tintRules = table.freeze({
			table.freeze({
				partNameContains = "accent",
				color = accentColor,
				material = fallbackMaterial,
			}),
			table.freeze({
				partNameContains = "trim",
				color = accentColor,
				material = fallbackMaterial,
			}),
			table.freeze({
				partNameContains = "roof",
				color = accentColor,
				material = fallbackMaterial,
			}),
			table.freeze({
				partNameContains = "body",
				color = fallbackColor,
				material = fallbackMaterial,
			}),
		}),
	})
end

local function createAppleTreeDefinition(treeDefinition: TreeTierDefinition): BuildingDefinition
	return table.freeze({
		id = treeDefinition.id,
		displayName = treeDefinition.displayName,
		sellPrice = treeDefinition.sellPrice,
		placementSize = Vector3.new(6, 6, 6),
		productionConfig = table.freeze({
			behaviorId = "TimedStorageProducer",
			produceIntervalSeconds = 5,
			outputResourceId = "Apple",
			outputAmountPerInterval = treeDefinition.fruitPerInterval,
			storageCap = treeDefinition.storageCap,
		}),
		offlineEarningsConfig = table.freeze({
			ciderPerSecond = treeDefinition.offlineCiderPerSecond,
		}),
		growthVisualConfig = table.freeze({
			assetFolderName = "BasicTree",
			stages = TREE_STAGES,
		}),
		visualVariantConfig = createTreeVisualVariant(
			treeDefinition.leafColor,
			treeDefinition.fruitColor,
			treeDefinition.fallbackColor
		),
	})
end

local function createCiderMillDefinition(millDefinition: MillTierDefinition): BuildingDefinition
	return table.freeze({
		id = millDefinition.id,
		displayName = millDefinition.displayName,
		sellPrice = millDefinition.sellPrice,
		placementSize = Vector3.new(8, 6, 8),
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
		growthVisualConfig = table.freeze({
			assetFolderName = "CiderMill",
			stages = CIDER_MILL_STAGES,
		}),
		visualVariantConfig = createMillVisualVariant(
			millDefinition.accentColor,
			millDefinition.fallbackColor,
			Enum.Material.Metal
		),
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
	local clampedProgress = math.clamp(progress, 0, 1)
	local selectedStage = buildingDefinition.growthVisualConfig.stages[1]

	for _, stage in ipairs(buildingDefinition.growthVisualConfig.stages) do
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

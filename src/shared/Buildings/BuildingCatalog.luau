--!strict

local BuildingTypes = require(script.Parent.BuildingTypes)

type BuildingDefinition = BuildingTypes.BuildingDefinition
type BuildingId = BuildingTypes.BuildingId
type GrowthVisualStage = BuildingTypes.GrowthVisualStage
type VisualVariantConfig = BuildingTypes.VisualVariantConfig

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

local function createAppleTreeDefinition(
	id: BuildingId,
	displayName: string,
	sellPrice: number,
	offlineCiderPerSecond: number,
	outputAmountPerInterval: number,
	storageCap: number,
	visualVariantConfig: VisualVariantConfig?
): BuildingDefinition
	return table.freeze({
		id = id,
		displayName = displayName,
		sellPrice = sellPrice,
		placementSize = Vector3.new(6, 6, 6),
		productionConfig = table.freeze({
			behaviorId = "TimedStorageProducer",
			produceIntervalSeconds = 5,
			outputResourceId = "Apple",
			outputAmountPerInterval = outputAmountPerInterval,
			storageCap = storageCap,
		}),
		offlineEarningsConfig = table.freeze({
			ciderPerSecond = offlineCiderPerSecond,
		}),
		growthVisualConfig = table.freeze({
			assetFolderName = "BasicTree",
			stages = TREE_STAGES,
		}),
		visualVariantConfig = visualVariantConfig,
	})
end

local function createCiderMillDefinition(
	id: BuildingId,
	displayName: string,
	sellPrice: number,
	offlineCiderPerSecond: number,
	inputAmount: number,
	outputAmount: number,
	visualVariantConfig: VisualVariantConfig?
): BuildingDefinition
	return table.freeze({
		id = id,
		displayName = displayName,
		sellPrice = sellPrice,
		placementSize = Vector3.new(8, 6, 8),
		productionConfig = table.freeze({
			behaviorId = "InputProcessor",
			cycleDurationSeconds = 1,
			inputResourceId = "Apple",
			inputAmount = inputAmount,
			outputResourceId = "Cider",
			outputAmount = outputAmount,
			outputStorageMode = "Unlimited",
			idleStatusText = "Idle",
			blockedStatusText = "Need apples",
		}),
		offlineEarningsConfig = table.freeze({
			ciderPerSecond = offlineCiderPerSecond,
		}),
		growthVisualConfig = table.freeze({
			assetFolderName = "CiderMill",
			stages = CIDER_MILL_STAGES,
		}),
		visualVariantConfig = visualVariantConfig,
	})
end

local buildingsById: { [BuildingId]: BuildingDefinition } = {
	BasicTree = createAppleTreeDefinition("BasicTree", "Apple Tree", 25, 0.05, 1, 10, nil),
	RubyAppleTree = createAppleTreeDefinition(
		"RubyAppleTree",
		"Ruby Apple Tree",
		75,
		0.12,
		2,
		18,
		createTreeVisualVariant(Color3.fromRGB(190, 48, 68), Color3.fromRGB(255, 92, 105), Color3.fromRGB(143, 48, 64))
	),
	GoldenAppleTree = createAppleTreeDefinition(
		"GoldenAppleTree",
		"Golden Apple Tree",
		325,
		0.35,
		4,
		35,
		createTreeVisualVariant(Color3.fromRGB(232, 184, 57), Color3.fromRGB(255, 226, 99), Color3.fromRGB(196, 150, 45))
	),
	CrystalAppleTree = createAppleTreeDefinition(
		"CrystalAppleTree",
		"Crystal Apple Tree",
		1250,
		1,
		7,
		60,
		createTreeVisualVariant(Color3.fromRGB(112, 214, 229), Color3.fromRGB(178, 241, 255), Color3.fromRGB(86, 169, 202))
	),
	CiderMill = createCiderMillDefinition("CiderMill", "Cider Mill", 50, 0.1, 1, 1, nil),
	CopperCiderMill = createCiderMillDefinition(
		"CopperCiderMill",
		"Copper Cider Mill",
		175,
		0.3,
		1,
		2,
		createMillVisualVariant(Color3.fromRGB(196, 108, 50), Color3.fromRGB(171, 95, 51), Enum.Material.Metal)
	),
	SteelCiderMill = createCiderMillDefinition(
		"SteelCiderMill",
		"Steel Cider Mill",
		600,
		0.8,
		2,
		5,
		createMillVisualVariant(Color3.fromRGB(142, 151, 158), Color3.fromRGB(116, 128, 135), Enum.Material.Metal)
	),
	RoyalCiderMill = createCiderMillDefinition(
		"RoyalCiderMill",
		"Royal Cider Mill",
		2250,
		2,
		3,
		10,
		createMillVisualVariant(Color3.fromRGB(135, 77, 183), Color3.fromRGB(196, 159, 62), Enum.Material.Metal)
	),
}

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

--!strict

local BuildingTypes = require(script.Parent.BuildingTypes)

type BuildingDefinition = BuildingTypes.BuildingDefinition
type BuildingId = BuildingTypes.BuildingId
type GrowthVisualStage = BuildingTypes.GrowthVisualStage

local buildingsById: { [BuildingId]: BuildingDefinition } = {
	BasicTree = table.freeze({
		id = "BasicTree",
		displayName = "Apple Tree",
		placementSize = Vector3.new(6, 6, 6),
		productionConfig = table.freeze({
			behaviorId = "GrowAndHarvest",
			cycleDurationSeconds = 25,
			outputResourceId = "Apple",
			outputAmount = 3,
			storageCap = 3,
		}),
		growthVisualConfig = table.freeze({
			assetFolderName = "BasicTree",
			stages = table.freeze({
				table.freeze({
					modelName = "Stage0",
					minProgress = 0,
				}),
				table.freeze({
					modelName = "Stage1",
					minProgress = 0.34,
				}),
				table.freeze({
					modelName = "Stage2",
					minProgress = 0.67,
				}),
				table.freeze({
					modelName = "Stage3",
					minProgress = 1,
				}),
			}),
		}),
	}),
	CiderMill = table.freeze({
		id = "CiderMill",
		displayName = "Cider Mill",
		placementSize = Vector3.new(8, 6, 8),
		productionConfig = table.freeze({
			behaviorId = "InputProcessor",
			cycleDurationSeconds = 12,
			inputResourceId = "Apple",
			inputAmount = 3,
			outputResourceId = "Cider",
			outputAmount = 1,
			idleStatusText = "Idle",
			blockedStatusText = "Need apples",
		}),
		growthVisualConfig = table.freeze({
			assetFolderName = "CiderMill",
			stages = table.freeze({
				table.freeze({
					modelName = "Stage0",
					minProgress = 0,
				}),
				table.freeze({
					modelName = "Stage1",
					minProgress = 0.01,
				}),
			}),
		}),
	}),
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

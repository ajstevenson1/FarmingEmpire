--!strict

local BuildingTypes = require(script.Parent.BuildingTypes)

type BuildingDefinition = BuildingTypes.BuildingDefinition
type BuildingId = BuildingTypes.BuildingId

local buildingsById: { [BuildingId]: BuildingDefinition } = {
	WheatField = table.freeze({
		id = "WheatField",
		displayName = "Wheat Field",
		productionConfig = table.freeze({
			behaviorId = "GrowAndHarvest",
			cycleDurationSeconds = 15,
			outputResourceName = "Wheat",
			outputAmount = 1,
			storageCap = 1,
		}),
	}),
}

local BuildingCatalog = {}

function BuildingCatalog.getBuildingDefinition(buildingId: BuildingId): BuildingDefinition
	return buildingsById[buildingId]
end

function BuildingCatalog.hasBuildingDefinition(buildingId: string): boolean
	return buildingsById[buildingId :: BuildingId] ~= nil
end

function BuildingCatalog.getAllBuildingDefinitions(): { [BuildingId]: BuildingDefinition }
	return buildingsById
end

return table.freeze(BuildingCatalog)

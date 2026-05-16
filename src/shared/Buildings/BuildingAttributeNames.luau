--!strict

local BuildingAttributeNames = {
	buildingId = "BuildingId",
	buildingDisplayName = "BuildingDisplayName",
	productionBehaviorId = "ProductionBehaviorId",
	productionState = "ProductionState",
	productionProgress = "ProductionProgress",
	productionTimeLeft = "ProductionTimeLeft",
	productionStatusText = "ProductionStatusText",
	productionDuration = "ProductionDuration",
	productionMultiplier = "ProductionMultiplier",
	productionOutputName = "ProductionOutputName",
	productionStoredAmount = "ProductionStoredAmount",
	productionStorageCap = "ProductionStorageCap",
	isReadyToHarvest = "IsReadyToHarvest",
	growthVisualStageName = "GrowthVisualStageName",
}

return table.freeze(BuildingAttributeNames)

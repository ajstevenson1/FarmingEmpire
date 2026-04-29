--!strict

export type BuildingId = "WheatField"

export type ProductionBehaviorId = "GrowAndHarvest" | "PassiveStockpile" | "InputProcessor"

export type ProductionState = "Growing" | "Ready"

export type GrowAndHarvestProductionConfig = {
	behaviorId: "GrowAndHarvest",
	cycleDurationSeconds: number,
	outputResourceName: string,
	outputAmount: number,
	storageCap: number,
}

export type BuildingDefinition = {
	id: BuildingId,
	displayName: string,
	productionConfig: GrowAndHarvestProductionConfig,
}

return {}

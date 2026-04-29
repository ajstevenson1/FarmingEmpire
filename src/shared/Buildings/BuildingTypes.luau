--!strict

export type BuildingId = "WheatField"

export type ProductionBehaviorId = "GrowAndHarvest" | "PassiveStockpile" | "InputProcessor"

export type ProductionState = "Growing" | "Ready"

export type GrowthVisualStage = {
	modelName: string,
	minProgress: number,
}

export type GrowthVisualConfig = {
	assetFolderName: string,
	stages: { GrowthVisualStage },
}

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
	growthVisualConfig: GrowthVisualConfig,
}

return {}

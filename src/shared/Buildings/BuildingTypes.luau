--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)

type ResourceId = ResourceTypes.ResourceId

export type BuildingId = "BasicTree" | "CiderMill"

export type ProductionBehaviorId = "GrowAndHarvest" | "TimedStorageProducer" | "InputProcessor"

export type ProductionState = "Growing" | "Ready" | "Idle" | "Processing" | "Blocked"

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
	outputResourceId: ResourceId,
	outputAmount: number,
	storageCap: number,
}

export type TimedStorageProducerProductionConfig = {
	behaviorId: "TimedStorageProducer",
	produceIntervalSeconds: number,
	outputResourceId: ResourceId,
	outputAmountPerInterval: number,
	storageCap: number,
}

export type InputProcessorProductionConfig = {
	behaviorId: "InputProcessor",
	cycleDurationSeconds: number,
	inputResourceId: ResourceId,
	inputAmount: number,
	outputResourceId: ResourceId,
	outputAmount: number,
	idleStatusText: string,
	blockedStatusText: string,
}

export type ProductionConfig = GrowAndHarvestProductionConfig | TimedStorageProducerProductionConfig | InputProcessorProductionConfig

export type ProductionRuntimeState = {
	state: ProductionState,
	cycleStartedAt: number,
	cycleFinishesAt: number,
	progress: number,
	timeLeft: number,
	statusText: string,
	storedAmount: number,
	isReadyToHarvest: boolean,
}

export type HarvestOutput = {
	resourceId: ResourceId,
	amount: number,
}

export type ProductionBehaviorContext = {
	currentTime: number,
	ownerPlayer: Player?,
	getResourceAmount: (player: Player, resourceId: ResourceId) -> number,
	tryConsumeResource: (player: Player, resourceId: ResourceId, amount: number) -> boolean,
	addResource: (player: Player, resourceId: ResourceId, amount: number) -> (),
}

export type ProductionBehavior = {
	createRuntimeState: (config: ProductionConfig, currentTime: number) -> ProductionRuntimeState,
	updateRuntimeState: (
		runtimeState: ProductionRuntimeState,
		config: ProductionConfig,
		context: ProductionBehaviorContext
	) -> ProductionRuntimeState,
	harvest: ((runtimeState: ProductionRuntimeState, config: ProductionConfig, currentTime: number) -> (ProductionRuntimeState, HarvestOutput?))?,
}

export type BuildingDefinition = {
	id: BuildingId,
	displayName: string,
	placementSize: Vector3,
	productionConfig: ProductionConfig,
	growthVisualConfig: GrowthVisualConfig,
}

return {}

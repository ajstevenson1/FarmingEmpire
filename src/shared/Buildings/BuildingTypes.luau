--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)

type ResourceId = ResourceTypes.ResourceId

export type BuildingId =
	"OakTree"
	| "BirchTree"
	| "CherryTree"
	| "GoldenTree"
	| "EmeraldTree"
	| "SapphireTree"
	| "DiamondTree"
	| "InfernoTree"
	| "FrostbiteTree"
	| "VoidfruitTree"
	| "FalloutTree"
	| "RainbowPrismTree"
	| "GhostwoodTree"
	| "CandyTree"
	| "CyberTree"
	| "CiderMill"
	| "CopperCiderMill"
	| "SteelCiderMill"
	| "PlatinumCiderMill"
	| "DiamondCiderMill"
	| "RoyalCiderMill"
	| "IndustrialCiderMill"
	| "AdvancedCiderMill"
	| "MagmaCiderMill"
	| "WastelandCiderMill"
	| "AncientCiderMill"
	| "TitanCiderMill"
	| "QuantumReactorMill"
	| "DyingForgeMill"
	| "DeepSpaceMill"
	| "OfflineEarningsWindmill"
	| "CiderCashWindmill"

export type PlacementRotationQuarterTurns = number

export type ProductionBehaviorId = "GrowAndHarvest" | "TimedStorageProducer" | "InputProcessor" | "Passive"

export type ProductionState = "Growing" | "Ready" | "Idle" | "Processing" | "Blocked"

export type GrowthVisualStage = {
	modelName: string,
	minProgress: number,
}

export type StagedBuildingVisualConfig = {
	kind: "Staged",
	categoryFolderName: string,
	assetName: string,
	fallbackAssetName: string,
	stages: { GrowthVisualStage },
	placementPreviewStageModelName: string,
}

export type SingleBuildingVisualConfig = {
	kind: "Single",
	categoryFolderName: string,
	assetName: string,
	fallbackAssetName: string,
}

export type BuildingVisualConfig = StagedBuildingVisualConfig | SingleBuildingVisualConfig

export type HarvestVisualConfig = {
	appleModelName: string,
	maxAppleEffectCount: number,
}

export type OfflineEarningsConfig = {
	ciderPerSecond: number,
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
	outputStorageMode: "Unlimited",
	idleStatusText: string,
	blockedStatusText: string,
}

export type PassiveProductionConfig = {
	behaviorId: "Passive",
	statusText: string,
}

export type ProductionConfig =
	GrowAndHarvestProductionConfig | TimedStorageProducerProductionConfig | InputProcessorProductionConfig | PassiveProductionConfig

export type ProductionRuntimeState = {
	state: ProductionState,
	cycleStartedAt: number,
	cycleFinishesAt: number,
	progress: number,
	timeLeft: number,
	statusText: string,
	storedAmount: number,
	pendingOutputAmount: number?,
	isReadyToHarvest: boolean,
}

export type GrowAndHarvestSavedProductionState = {
	behaviorId: "GrowAndHarvest",
	state: ProductionState,
	storedAmount: number,
	secondsUntilReady: number,
}

export type TimedStorageProducerSavedProductionState = {
	behaviorId: "TimedStorageProducer",
	state: ProductionState,
	storedAmount: number,
	secondsUntilNextProduce: number,
}

export type InputProcessorSavedProductionState = {
	behaviorId: "InputProcessor",
	state: ProductionState,
	storedAmount: number,
	secondsUntilCycleFinishes: number?,
	pendingOutputAmount: number?,
}

export type SavedProductionState =
	GrowAndHarvestSavedProductionState | TimedStorageProducerSavedProductionState | InputProcessorSavedProductionState

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
	createRuntimeStateFromSavedState: (
		config: ProductionConfig,
		savedState: SavedProductionState,
		currentTime: number
	) -> ProductionRuntimeState?,
	createSavedState: (
		runtimeState: ProductionRuntimeState,
		config: ProductionConfig,
		currentTime: number
	) -> SavedProductionState?,
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
	sellPrice: number,
	placementSize: Vector3,
	productionConfig: ProductionConfig,
	offlineEarningsConfig: OfflineEarningsConfig?,
	visualConfig: BuildingVisualConfig,
	harvestVisualConfig: HarvestVisualConfig?,
}

return {}

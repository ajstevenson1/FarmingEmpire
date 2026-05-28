--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)

type HarvestOutput = BuildingTypes.HarvestOutput
type PassiveProductionConfig = BuildingTypes.PassiveProductionConfig
type ProductionBehaviorContext = BuildingTypes.ProductionBehaviorContext
type ProductionConfig = BuildingTypes.ProductionConfig
type ProductionRuntimeState = BuildingTypes.ProductionRuntimeState
type SavedProductionState = BuildingTypes.SavedProductionState

local PassiveBehavior = {}

local function getTypedConfig(config: ProductionConfig): PassiveProductionConfig
	assert(config.behaviorId == "Passive", "PassiveBehavior requires Passive config")
	return config
end

local function createState(config: PassiveProductionConfig, currentTime: number): ProductionRuntimeState
	return {
		state = "Idle",
		cycleStartedAt = currentTime,
		cycleFinishesAt = currentTime,
		progress = 1,
		timeLeft = 0,
		statusText = config.statusText,
		storedAmount = 0,
		pendingOutputAmount = nil,
		isReadyToHarvest = false,
	}
end

function PassiveBehavior.createRuntimeState(config: ProductionConfig, currentTime: number): ProductionRuntimeState
	return createState(getTypedConfig(config), currentTime)
end

function PassiveBehavior.createRuntimeStateFromSavedState(
	config: ProductionConfig,
	_savedState: SavedProductionState,
	currentTime: number
): ProductionRuntimeState?
	return createState(getTypedConfig(config), currentTime)
end

function PassiveBehavior.createSavedState(
	_runtimeState: ProductionRuntimeState,
	_config: ProductionConfig,
	_currentTime: number
): SavedProductionState?
	return nil
end

function PassiveBehavior.updateRuntimeState(
	runtimeState: ProductionRuntimeState,
	config: ProductionConfig,
	context: ProductionBehaviorContext
): ProductionRuntimeState
	local typedConfig = getTypedConfig(config)
	runtimeState.state = "Idle"
	runtimeState.cycleStartedAt = context.currentTime
	runtimeState.cycleFinishesAt = context.currentTime
	runtimeState.progress = 1
	runtimeState.timeLeft = 0
	runtimeState.statusText = typedConfig.statusText
	runtimeState.storedAmount = 0
	runtimeState.pendingOutputAmount = nil
	runtimeState.isReadyToHarvest = false
	return runtimeState
end

function PassiveBehavior.harvest(
	runtimeState: ProductionRuntimeState,
	_config: ProductionConfig,
	_currentTime: number
): (ProductionRuntimeState, HarvestOutput?)
	return runtimeState, nil
end

return table.freeze(PassiveBehavior)

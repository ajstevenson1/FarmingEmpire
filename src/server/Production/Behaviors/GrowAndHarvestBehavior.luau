--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)

type GrowAndHarvestProductionConfig = BuildingTypes.GrowAndHarvestProductionConfig
type HarvestOutput = BuildingTypes.HarvestOutput
type ProductionConfig = BuildingTypes.ProductionConfig
type ProductionRuntimeState = BuildingTypes.ProductionRuntimeState
type ProductionBehaviorContext = BuildingTypes.ProductionBehaviorContext
type SavedProductionState = BuildingTypes.SavedProductionState

local GrowAndHarvestBehavior = {}

local function getTypedConfig(config: ProductionConfig): GrowAndHarvestProductionConfig
	assert(config.behaviorId == "GrowAndHarvest", "GrowAndHarvestBehavior requires GrowAndHarvest config")
	return config
end

local function clampProgress(progress: number): number
	return math.clamp(progress, 0, 1)
end

local function getSafeCycleDuration(config: GrowAndHarvestProductionConfig): number
	return math.max(0.001, config.cycleDurationSeconds)
end

function GrowAndHarvestBehavior.createRuntimeState(config: ProductionConfig, currentTime: number): ProductionRuntimeState
	local typedConfig = getTypedConfig(config)
	local cycleDurationSeconds = getSafeCycleDuration(typedConfig)

	return {
		state = "Growing",
		cycleStartedAt = currentTime,
		cycleFinishesAt = currentTime + cycleDurationSeconds,
		progress = 0,
		timeLeft = cycleDurationSeconds,
		statusText = string.format("%ds", math.ceil(cycleDurationSeconds)),
		storedAmount = 0,
		isReadyToHarvest = false,
	}
end

function GrowAndHarvestBehavior.createRuntimeStateFromSavedState(
	config: ProductionConfig,
	savedState: SavedProductionState,
	currentTime: number
): ProductionRuntimeState?
	local typedConfig = getTypedConfig(config)
	if savedState.behaviorId ~= "GrowAndHarvest" then
		return nil
	end

	local cycleDurationSeconds = getSafeCycleDuration(typedConfig)
	if savedState.state == "Ready" then
		return {
			state = "Ready",
			cycleStartedAt = currentTime - cycleDurationSeconds,
			cycleFinishesAt = currentTime,
			progress = 1,
			timeLeft = 0,
			statusText = "Harvest",
			storedAmount = math.min(typedConfig.storageCap, typedConfig.outputAmount),
			isReadyToHarvest = true,
		}
	end

	local secondsUntilReady = math.clamp(savedState.secondsUntilReady, 0, cycleDurationSeconds)
	if secondsUntilReady <= 0 then
		return {
			state = "Ready",
			cycleStartedAt = currentTime - cycleDurationSeconds,
			cycleFinishesAt = currentTime,
			progress = 1,
			timeLeft = 0,
			statusText = "Harvest",
			storedAmount = math.min(typedConfig.storageCap, typedConfig.outputAmount),
			isReadyToHarvest = true,
		}
	end

	return {
		state = "Growing",
		cycleStartedAt = currentTime + secondsUntilReady - cycleDurationSeconds,
		cycleFinishesAt = currentTime + secondsUntilReady,
		progress = clampProgress((cycleDurationSeconds - secondsUntilReady) / cycleDurationSeconds),
		timeLeft = math.ceil(secondsUntilReady),
		statusText = string.format("%ds", math.ceil(secondsUntilReady)),
		storedAmount = math.max(0, math.floor(savedState.storedAmount)),
		isReadyToHarvest = false,
	}
end

function GrowAndHarvestBehavior.createSavedState(
	runtimeState: ProductionRuntimeState,
	config: ProductionConfig,
	currentTime: number
): SavedProductionState?
	local typedConfig = getTypedConfig(config)

	return {
		behaviorId = "GrowAndHarvest",
		state = runtimeState.state,
		storedAmount = math.clamp(math.floor(runtimeState.storedAmount), 0, typedConfig.storageCap),
		secondsUntilReady = math.max(0, runtimeState.cycleFinishesAt - currentTime),
	}
end

function GrowAndHarvestBehavior.updateRuntimeState(
	runtimeState: ProductionRuntimeState,
	config: ProductionConfig,
	context: ProductionBehaviorContext
): ProductionRuntimeState
	local typedConfig = getTypedConfig(config)

	if runtimeState.state == "Ready" then
		runtimeState.progress = 1
		runtimeState.timeLeft = 0
		runtimeState.statusText = "Harvest"
		runtimeState.isReadyToHarvest = true
		runtimeState.storedAmount = math.min(typedConfig.storageCap, typedConfig.outputAmount)
		return runtimeState
	end

	local elapsedTime = context.currentTime - runtimeState.cycleStartedAt
	local progress = clampProgress(elapsedTime / typedConfig.cycleDurationSeconds)
	local timeLeft = math.max(0, math.ceil(runtimeState.cycleFinishesAt - context.currentTime))

	runtimeState.progress = progress
	runtimeState.timeLeft = timeLeft
	runtimeState.statusText = string.format("%ds", timeLeft)

	if context.currentTime >= runtimeState.cycleFinishesAt then
		runtimeState.state = "Ready"
		runtimeState.progress = 1
		runtimeState.timeLeft = 0
		runtimeState.statusText = "Harvest"
		runtimeState.storedAmount = math.min(typedConfig.storageCap, typedConfig.outputAmount)
		runtimeState.isReadyToHarvest = true
	end

	return runtimeState
end

function GrowAndHarvestBehavior.harvest(
	runtimeState: ProductionRuntimeState,
	config: ProductionConfig,
	currentTime: number
): (ProductionRuntimeState, HarvestOutput?)
	local typedConfig = getTypedConfig(config)
	if not runtimeState.isReadyToHarvest then
		return runtimeState, nil
	end

	return GrowAndHarvestBehavior.createRuntimeState(typedConfig, currentTime), {
		resourceId = typedConfig.outputResourceId,
		amount = typedConfig.outputAmount,
	}
end

return table.freeze(GrowAndHarvestBehavior)

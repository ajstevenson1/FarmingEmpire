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

local GrowAndHarvestBehavior = {}

local function getTypedConfig(config: ProductionConfig): GrowAndHarvestProductionConfig
	assert(config.behaviorId == "GrowAndHarvest", "GrowAndHarvestBehavior requires GrowAndHarvest config")
	return config
end

local function clampProgress(progress: number): number
	return math.clamp(progress, 0, 1)
end

function GrowAndHarvestBehavior.createRuntimeState(config: ProductionConfig, currentTime: number): ProductionRuntimeState
	local typedConfig = getTypedConfig(config)

	return {
		state = "Growing",
		cycleStartedAt = currentTime,
		cycleFinishesAt = currentTime + typedConfig.cycleDurationSeconds,
		progress = 0,
		timeLeft = typedConfig.cycleDurationSeconds,
		statusText = string.format("%ds", typedConfig.cycleDurationSeconds),
		storedAmount = 0,
		isReadyToHarvest = false,
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

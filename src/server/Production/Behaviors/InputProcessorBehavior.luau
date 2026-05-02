--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)

type InputProcessorProductionConfig = BuildingTypes.InputProcessorProductionConfig
type ProductionConfig = BuildingTypes.ProductionConfig
type ProductionState = BuildingTypes.ProductionState
type ProductionRuntimeState = BuildingTypes.ProductionRuntimeState
type ProductionBehaviorContext = BuildingTypes.ProductionBehaviorContext

local InputProcessorBehavior = {}

local function getTypedConfig(config: ProductionConfig): InputProcessorProductionConfig
	assert(config.behaviorId == "InputProcessor", "InputProcessorBehavior requires InputProcessor config")
	return config
end

local function createIdleState(currentTime: number, statusText: string, state: ProductionState): ProductionRuntimeState
	return {
		state = state,
		cycleStartedAt = currentTime,
		cycleFinishesAt = currentTime,
		progress = 0,
		timeLeft = 0,
		statusText = statusText,
		storedAmount = 0,
		isReadyToHarvest = false,
	}
end

local function createProcessingState(config: InputProcessorProductionConfig, currentTime: number): ProductionRuntimeState
	return {
		state = "Processing",
		cycleStartedAt = currentTime,
		cycleFinishesAt = currentTime + config.cycleDurationSeconds,
		progress = 0,
		timeLeft = config.cycleDurationSeconds,
		statusText = string.format("%ds", config.cycleDurationSeconds),
		storedAmount = 0,
		isReadyToHarvest = false,
	}
end

local function tryBeginProcessing(config: InputProcessorProductionConfig, context: ProductionBehaviorContext): ProductionRuntimeState
	local ownerPlayer = context.ownerPlayer
	if ownerPlayer ~= nil and context.tryConsumeResource(ownerPlayer, config.inputResourceId, config.inputAmount) then
		return createProcessingState(config, context.currentTime)
	end

	return createIdleState(context.currentTime, config.blockedStatusText, "Blocked")
end

function InputProcessorBehavior.createRuntimeState(config: ProductionConfig, currentTime: number): ProductionRuntimeState
	local typedConfig = getTypedConfig(config)
	return createIdleState(currentTime, typedConfig.idleStatusText, "Idle")
end

function InputProcessorBehavior.updateRuntimeState(
	runtimeState: ProductionRuntimeState,
	config: ProductionConfig,
	context: ProductionBehaviorContext
): ProductionRuntimeState
	local typedConfig = getTypedConfig(config)

	if runtimeState.state == "Processing" then
		if context.currentTime >= runtimeState.cycleFinishesAt then
			local ownerPlayer = context.ownerPlayer
			if ownerPlayer ~= nil then
				context.addResource(ownerPlayer, typedConfig.outputResourceId, typedConfig.outputAmount)
			end

			return tryBeginProcessing(typedConfig, {
				currentTime = context.currentTime,
				ownerPlayer = context.ownerPlayer,
				getResourceAmount = context.getResourceAmount,
				tryConsumeResource = context.tryConsumeResource,
				addResource = context.addResource,
			})
		end

		local elapsedTime = context.currentTime - runtimeState.cycleStartedAt
		local progress = math.clamp(elapsedTime / typedConfig.cycleDurationSeconds, 0, 1)
		local timeLeft = math.max(0, math.ceil(runtimeState.cycleFinishesAt - context.currentTime))
		runtimeState.progress = progress
		runtimeState.timeLeft = timeLeft
		runtimeState.statusText = string.format("%ds", timeLeft)
		runtimeState.state = "Processing"
		return runtimeState
	end

	return tryBeginProcessing(typedConfig, context)
end

return table.freeze(InputProcessorBehavior)

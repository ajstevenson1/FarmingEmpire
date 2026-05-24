--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)

type InputProcessorProductionConfig = BuildingTypes.InputProcessorProductionConfig
type HarvestOutput = BuildingTypes.HarvestOutput
type ProductionConfig = BuildingTypes.ProductionConfig
type ProductionState = BuildingTypes.ProductionState
type ProductionRuntimeState = BuildingTypes.ProductionRuntimeState
type ProductionBehaviorContext = BuildingTypes.ProductionBehaviorContext
type SavedProductionState = BuildingTypes.SavedProductionState

local InputProcessorBehavior = {}

local function getTypedConfig(config: ProductionConfig): InputProcessorProductionConfig
	assert(config.behaviorId == "InputProcessor", "InputProcessorBehavior requires InputProcessor config")
	assert(config.outputStorageMode == "Unlimited", "InputProcessorBehavior currently supports unlimited output storage")
	return config
end

local function getSafeOutputAmount(config: InputProcessorProductionConfig): number
	return math.max(0, math.floor(config.outputAmount))
end

local function getSafeInputAmount(config: InputProcessorProductionConfig): number
	return math.max(0, math.floor(config.inputAmount))
end

local function getSafeCycleDuration(config: InputProcessorProductionConfig): number
	return math.max(0.001, config.cycleDurationSeconds)
end

local function getOutputAmountForInputAmount(config: InputProcessorProductionConfig, inputAmount: number): number
	local safeInputAmount = getSafeInputAmount(config)
	if safeInputAmount <= 0 then
		return 0
	end

	return math.max(0, math.floor((getSafeOutputAmount(config) * math.max(0, math.floor(inputAmount))) / safeInputAmount))
end

local function getStoredStatusText(config: InputProcessorProductionConfig, storedAmount: number): string
	return string.format("%d %s", storedAmount, config.outputResourceId)
end

local function createWaitingState(
	config: InputProcessorProductionConfig,
	currentTime: number,
	storedAmount: number,
	fallbackStatusText: string,
	fallbackState: ProductionState
): ProductionRuntimeState
	local safeStoredAmount = math.max(0, math.floor(storedAmount))
	local hasStoredOutput = safeStoredAmount > 0

	return {
		state = if hasStoredOutput then "Ready" else fallbackState,
		cycleStartedAt = currentTime,
		cycleFinishesAt = currentTime,
		progress = if hasStoredOutput then 1 else 0,
		timeLeft = 0,
		statusText = if hasStoredOutput then getStoredStatusText(config, safeStoredAmount) else fallbackStatusText,
		storedAmount = safeStoredAmount,
		pendingOutputAmount = nil,
		isReadyToHarvest = hasStoredOutput,
	}
end

local function createProcessingState(
	config: InputProcessorProductionConfig,
	currentTime: number,
	storedAmount: number,
	pendingOutputAmount: number
): ProductionRuntimeState
	local safeStoredAmount = math.max(0, math.floor(storedAmount))
	local safePendingOutputAmount = math.max(0, math.floor(pendingOutputAmount))

	return {
		state = "Processing",
		cycleStartedAt = currentTime,
		cycleFinishesAt = currentTime + config.cycleDurationSeconds,
		progress = 0,
		timeLeft = config.cycleDurationSeconds,
		statusText = if safeStoredAmount > 0
			then string.format("%s | %ds", getStoredStatusText(config, safeStoredAmount), config.cycleDurationSeconds)
			else string.format("%ds", config.cycleDurationSeconds),
		storedAmount = safeStoredAmount,
		pendingOutputAmount = safePendingOutputAmount,
		isReadyToHarvest = safeStoredAmount > 0,
	}
end

local function updateProcessingDisplay(runtimeState: ProductionRuntimeState, config: InputProcessorProductionConfig, currentTime: number)
	local elapsedTime = currentTime - runtimeState.cycleStartedAt
	local progress = math.clamp(elapsedTime / config.cycleDurationSeconds, 0, 1)
	local timeLeft = math.max(0, math.ceil(runtimeState.cycleFinishesAt - currentTime))
	local storedAmount = math.max(0, math.floor(runtimeState.storedAmount))

	runtimeState.progress = progress
	runtimeState.timeLeft = timeLeft
	runtimeState.statusText = if storedAmount > 0
		then string.format("%s | %ds", getStoredStatusText(config, storedAmount), timeLeft)
		else string.format("%ds", timeLeft)
	runtimeState.state = "Processing"
	runtimeState.storedAmount = storedAmount
	runtimeState.pendingOutputAmount = math.max(0, math.floor(runtimeState.pendingOutputAmount or getSafeOutputAmount(config)))
	runtimeState.isReadyToHarvest = storedAmount > 0
end

local function tryBeginProcessing(
	config: InputProcessorProductionConfig,
	context: ProductionBehaviorContext,
	storedAmount: number
): ProductionRuntimeState
	local ownerPlayer = context.ownerPlayer
	if ownerPlayer ~= nil then
		local inputAmount = math.min(context.getResourceAmount(ownerPlayer, config.inputResourceId), getSafeInputAmount(config))
		local outputAmount = getOutputAmountForInputAmount(config, inputAmount)
		if inputAmount > 0 and outputAmount > 0 and context.tryConsumeResource(ownerPlayer, config.inputResourceId, inputAmount) then
			return createProcessingState(config, context.currentTime, storedAmount, outputAmount)
		end
	end

	return createWaitingState(config, context.currentTime, storedAmount, config.blockedStatusText, "Blocked")
end

function InputProcessorBehavior.createRuntimeState(config: ProductionConfig, currentTime: number): ProductionRuntimeState
	local typedConfig = getTypedConfig(config)
	return createWaitingState(typedConfig, currentTime, 0, typedConfig.idleStatusText, "Idle")
end

function InputProcessorBehavior.createRuntimeStateFromSavedState(
	config: ProductionConfig,
	savedState: SavedProductionState,
	currentTime: number
): ProductionRuntimeState?
	local typedConfig = getTypedConfig(config)
	if savedState.behaviorId ~= "InputProcessor" then
		return nil
	end

	local storedAmount = math.max(0, math.floor(savedState.storedAmount))
	if savedState.state == "Processing" then
		local cycleDurationSeconds = getSafeCycleDuration(typedConfig)
		local secondsUntilCycleFinishes = if savedState.secondsUntilCycleFinishes == nil
			then cycleDurationSeconds
			else math.clamp(savedState.secondsUntilCycleFinishes, 0, cycleDurationSeconds)

		local runtimeState: ProductionRuntimeState = {
			state = "Processing",
			cycleStartedAt = currentTime + secondsUntilCycleFinishes - cycleDurationSeconds,
			cycleFinishesAt = currentTime + secondsUntilCycleFinishes,
			progress = 0,
			timeLeft = math.ceil(secondsUntilCycleFinishes),
			statusText = "",
			storedAmount = storedAmount,
			pendingOutputAmount = if savedState.pendingOutputAmount == nil
				then getSafeOutputAmount(typedConfig)
				else math.max(0, math.floor(savedState.pendingOutputAmount)),
			isReadyToHarvest = storedAmount > 0,
		}

		updateProcessingDisplay(runtimeState, typedConfig, currentTime)
		return runtimeState
	end

	if savedState.state == "Blocked" then
		return createWaitingState(typedConfig, currentTime, storedAmount, typedConfig.blockedStatusText, "Blocked")
	end

	return createWaitingState(typedConfig, currentTime, storedAmount, typedConfig.idleStatusText, "Idle")
end

function InputProcessorBehavior.createSavedState(
	runtimeState: ProductionRuntimeState,
	config: ProductionConfig,
	currentTime: number
): SavedProductionState?
	local typedConfig = getTypedConfig(config)

	return {
		behaviorId = "InputProcessor",
		state = runtimeState.state,
		storedAmount = math.max(0, math.floor(runtimeState.storedAmount)),
		secondsUntilCycleFinishes = if runtimeState.state == "Processing"
			then math.max(0, runtimeState.cycleFinishesAt - currentTime)
			else nil,
		pendingOutputAmount = if runtimeState.state == "Processing"
			then math.max(0, math.floor(runtimeState.pendingOutputAmount or getSafeOutputAmount(typedConfig)))
			else nil,
	}
end

function InputProcessorBehavior.updateRuntimeState(
	runtimeState: ProductionRuntimeState,
	config: ProductionConfig,
	context: ProductionBehaviorContext
): ProductionRuntimeState
	local typedConfig = getTypedConfig(config)

	if runtimeState.state == "Processing" then
		if context.currentTime >= runtimeState.cycleFinishesAt then
			local outputAmount = math.max(0, math.floor(runtimeState.pendingOutputAmount or getSafeOutputAmount(typedConfig)))
			local nextStoredAmount = math.max(0, math.floor(runtimeState.storedAmount)) + outputAmount

			return tryBeginProcessing(typedConfig, {
				currentTime = context.currentTime,
				ownerPlayer = context.ownerPlayer,
				getResourceAmount = context.getResourceAmount,
				tryConsumeResource = context.tryConsumeResource,
				addResource = context.addResource,
			}, nextStoredAmount)
		end

		updateProcessingDisplay(runtimeState, typedConfig, context.currentTime)
		return runtimeState
	end

	return tryBeginProcessing(typedConfig, context, runtimeState.storedAmount)
end

function InputProcessorBehavior.harvest(
	runtimeState: ProductionRuntimeState,
	config: ProductionConfig,
	currentTime: number
): (ProductionRuntimeState, HarvestOutput?)
	local typedConfig = getTypedConfig(config)
	local storedAmount = math.max(0, math.floor(runtimeState.storedAmount))
	if storedAmount <= 0 then
		return runtimeState, nil
	end

	runtimeState.storedAmount = 0
	runtimeState.isReadyToHarvest = false

	if runtimeState.state == "Processing" then
		updateProcessingDisplay(runtimeState, typedConfig, currentTime)
	else
		runtimeState = createWaitingState(typedConfig, currentTime, 0, typedConfig.idleStatusText, "Idle")
	end

	return runtimeState, {
		resourceId = typedConfig.outputResourceId,
		amount = storedAmount,
	}
end

return table.freeze(InputProcessorBehavior)

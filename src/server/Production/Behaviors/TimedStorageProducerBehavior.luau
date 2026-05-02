--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)

type HarvestOutput = BuildingTypes.HarvestOutput
type ProductionConfig = BuildingTypes.ProductionConfig
type ProductionRuntimeState = BuildingTypes.ProductionRuntimeState
type ProductionBehaviorContext = BuildingTypes.ProductionBehaviorContext
type TimedStorageProducerProductionConfig = BuildingTypes.TimedStorageProducerProductionConfig

local TimedStorageProducerBehavior = {}

local function getTypedConfig(config: ProductionConfig): TimedStorageProducerProductionConfig
	assert(config.behaviorId == "TimedStorageProducer", "TimedStorageProducerBehavior requires TimedStorageProducer config")
	return config
end

local function getSafeStorageCap(config: TimedStorageProducerProductionConfig): number
	return math.max(0, math.floor(config.storageCap))
end

local function getSafeOutputAmountPerInterval(config: TimedStorageProducerProductionConfig): number
	return math.max(0, math.floor(config.outputAmountPerInterval))
end

local function getSafeProduceInterval(config: TimedStorageProducerProductionConfig): number
	return math.max(0.001, config.produceIntervalSeconds)
end

local function syncDerivedFields(runtimeState: ProductionRuntimeState, config: TimedStorageProducerProductionConfig, currentTime: number)
	local storageCap = getSafeStorageCap(config)
	local storedAmount = math.clamp(math.floor(runtimeState.storedAmount), 0, storageCap)
	local isFull = storageCap > 0 and storedAmount >= storageCap

	runtimeState.storedAmount = storedAmount
	runtimeState.progress = if storageCap > 0 then storedAmount / storageCap else 0
	runtimeState.isReadyToHarvest = storedAmount > 0

	if isFull then
		runtimeState.state = "Ready"
		runtimeState.timeLeft = 0
		runtimeState.statusText = "Harvest"
	else
		runtimeState.state = "Growing"
		runtimeState.timeLeft = math.max(0, math.ceil(runtimeState.cycleFinishesAt - currentTime))
		runtimeState.statusText = string.format("%d/%d", storedAmount, storageCap)
	end
end

function TimedStorageProducerBehavior.createRuntimeState(config: ProductionConfig, currentTime: number): ProductionRuntimeState
	local typedConfig = getTypedConfig(config)
	local produceIntervalSeconds = getSafeProduceInterval(typedConfig)

	local runtimeState: ProductionRuntimeState = {
		state = "Growing",
		cycleStartedAt = currentTime,
		cycleFinishesAt = currentTime + produceIntervalSeconds,
		progress = 0,
		timeLeft = math.ceil(produceIntervalSeconds),
		statusText = string.format("%ds", math.ceil(produceIntervalSeconds)),
		storedAmount = 0,
		isReadyToHarvest = false,
	}

	syncDerivedFields(runtimeState, typedConfig, currentTime)
	return runtimeState
end

function TimedStorageProducerBehavior.updateRuntimeState(
	runtimeState: ProductionRuntimeState,
	config: ProductionConfig,
	context: ProductionBehaviorContext
): ProductionRuntimeState
	local typedConfig = getTypedConfig(config)
	local storageCap = getSafeStorageCap(typedConfig)
	local outputAmountPerInterval = getSafeOutputAmountPerInterval(typedConfig)
	local produceIntervalSeconds = getSafeProduceInterval(typedConfig)

	if storageCap <= 0 or outputAmountPerInterval <= 0 then
		runtimeState.storedAmount = 0
		runtimeState.cycleStartedAt = context.currentTime
		runtimeState.cycleFinishesAt = context.currentTime + produceIntervalSeconds
		syncDerivedFields(runtimeState, typedConfig, context.currentTime)
		return runtimeState
	end

	runtimeState.storedAmount = math.clamp(math.floor(runtimeState.storedAmount), 0, storageCap)

	if runtimeState.storedAmount >= storageCap then
		syncDerivedFields(runtimeState, typedConfig, context.currentTime)
		return runtimeState
	end

	if context.currentTime < runtimeState.cycleFinishesAt then
		syncDerivedFields(runtimeState, typedConfig, context.currentTime)
		return runtimeState
	end

	while context.currentTime >= runtimeState.cycleFinishesAt and runtimeState.storedAmount < storageCap do
		runtimeState.storedAmount = math.min(storageCap, runtimeState.storedAmount + outputAmountPerInterval)
		runtimeState.cycleStartedAt = runtimeState.cycleFinishesAt
		runtimeState.cycleFinishesAt += produceIntervalSeconds
	end

	syncDerivedFields(runtimeState, typedConfig, context.currentTime)
	return runtimeState
end

function TimedStorageProducerBehavior.harvest(
	runtimeState: ProductionRuntimeState,
	config: ProductionConfig,
	currentTime: number
): (ProductionRuntimeState, HarvestOutput?)
	local typedConfig = getTypedConfig(config)
	local storedAmount = math.clamp(math.floor(runtimeState.storedAmount), 0, getSafeStorageCap(typedConfig))
	if storedAmount <= 0 then
		return runtimeState, nil
	end

	local nextRuntimeState = TimedStorageProducerBehavior.createRuntimeState(typedConfig, currentTime)
	return nextRuntimeState, {
		resourceId = typedConfig.outputResourceId,
		amount = storedAmount,
	}
end

return table.freeze(TimedStorageProducerBehavior)

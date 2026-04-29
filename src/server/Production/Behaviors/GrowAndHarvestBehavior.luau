--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)

type GrowAndHarvestProductionConfig = BuildingTypes.GrowAndHarvestProductionConfig
type ProductionState = BuildingTypes.ProductionState

export type RuntimeState = {
	state: ProductionState,
	cycleStartedAt: number,
	cycleFinishesAt: number,
	progress: number,
	timeLeft: number,
	statusText: string,
	storedAmount: number,
	isReadyToHarvest: boolean,
}

local GrowAndHarvestBehavior = {}

local function clampProgress(progress: number): number
	return math.clamp(progress, 0, 1)
end

function GrowAndHarvestBehavior.createRuntimeState(config: GrowAndHarvestProductionConfig, currentTime: number): RuntimeState
	return {
		state = "Growing",
		cycleStartedAt = currentTime,
		cycleFinishesAt = currentTime + config.cycleDurationSeconds,
		progress = 0,
		timeLeft = config.cycleDurationSeconds,
		statusText = string.format("%ds", config.cycleDurationSeconds),
		storedAmount = 0,
		isReadyToHarvest = false,
	}
end

function GrowAndHarvestBehavior.updateRuntimeState(
	runtimeState: RuntimeState,
	config: GrowAndHarvestProductionConfig,
	currentTime: number
): RuntimeState
	if runtimeState.state == "Ready" then
		runtimeState.progress = 1
		runtimeState.timeLeft = 0
		runtimeState.statusText = "Ready"
		runtimeState.isReadyToHarvest = true
		runtimeState.storedAmount = math.min(config.storageCap, config.outputAmount)
		return runtimeState
	end

	local elapsedTime = currentTime - runtimeState.cycleStartedAt
	local progress = clampProgress(elapsedTime / config.cycleDurationSeconds)
	local timeLeft = math.max(0, math.ceil(runtimeState.cycleFinishesAt - currentTime))

	runtimeState.progress = progress
	runtimeState.timeLeft = timeLeft
	runtimeState.statusText = string.format("%ds", timeLeft)

	if currentTime >= runtimeState.cycleFinishesAt then
		runtimeState.state = "Ready"
		runtimeState.progress = 1
		runtimeState.timeLeft = 0
		runtimeState.statusText = "Ready"
		runtimeState.storedAmount = math.min(config.storageCap, config.outputAmount)
		runtimeState.isReadyToHarvest = true
	end

	return runtimeState
end

return table.freeze(GrowAndHarvestBehavior)

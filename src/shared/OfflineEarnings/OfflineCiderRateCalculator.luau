--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)

type BuildingDefinition = BuildingTypes.BuildingDefinition
type BuildingId = BuildingTypes.BuildingId
type InputProcessorProductionConfig = BuildingTypes.InputProcessorProductionConfig
type TimedStorageProducerProductionConfig = BuildingTypes.TimedStorageProducerProductionConfig

export type OfflineRateBuilding = {
	buildingId: BuildingId,
}

type OfflineMillRate = {
	appleConsumptionPerSecond: number,
	ciderPerApple: number,
}

local APPLE_RESOURCE_ID = "Apple"
local CIDER_RESOURCE_ID = "Cider"
local SECONDS_PER_HOUR = 60 * 60

local function getSafeTimedProducerRate(buildingDefinition: BuildingDefinition): number
	local productionConfig = buildingDefinition.productionConfig
	if productionConfig.behaviorId ~= "TimedStorageProducer" or productionConfig.outputResourceId ~= APPLE_RESOURCE_ID then
		return 0
	end

	local typedConfig = productionConfig :: TimedStorageProducerProductionConfig
	local outputAmountPerInterval = math.max(0, typedConfig.outputAmountPerInterval)
	local produceIntervalSeconds = math.max(0.001, typedConfig.produceIntervalSeconds)
	if outputAmountPerInterval <= 0 then
		return 0
	end

	return outputAmountPerInterval / produceIntervalSeconds
end

local function createOfflineMillRate(buildingDefinition: BuildingDefinition): OfflineMillRate?
	local productionConfig = buildingDefinition.productionConfig
	if productionConfig.behaviorId ~= "InputProcessor"
		or productionConfig.inputResourceId ~= APPLE_RESOURCE_ID
		or productionConfig.outputResourceId ~= CIDER_RESOURCE_ID
	then
		return nil
	end

	local typedConfig = productionConfig :: InputProcessorProductionConfig
	local inputAmount = math.max(0, typedConfig.inputAmount)
	local outputAmount = math.max(0, typedConfig.outputAmount)
	local cycleDurationSeconds = math.max(0.001, typedConfig.cycleDurationSeconds)
	if inputAmount <= 0 or outputAmount <= 0 then
		return nil
	end

	return {
		appleConsumptionPerSecond = inputAmount / cycleDurationSeconds,
		ciderPerApple = outputAmount / inputAmount,
	}
end

local OfflineCiderRateCalculator = {}

function OfflineCiderRateCalculator.calculateCiderPerHour(buildings: { OfflineRateBuilding }): number
	local totalAppleRatePerSecond = 0
	local offlineMills: { OfflineMillRate } = {}

	for _, building in ipairs(buildings) do
		local buildingDefinition = BuildingCatalog.getBuildingDefinition(building.buildingId)
		totalAppleRatePerSecond += getSafeTimedProducerRate(buildingDefinition)

		local offlineMillRate = createOfflineMillRate(buildingDefinition)
		if offlineMillRate ~= nil then
			table.insert(offlineMills, offlineMillRate)
		end
	end

	if totalAppleRatePerSecond <= 0 or #offlineMills == 0 then
		return 0
	end

	table.sort(offlineMills, function(leftMill: OfflineMillRate, rightMill: OfflineMillRate): boolean
		if leftMill.ciderPerApple == rightMill.ciderPerApple then
			return leftMill.appleConsumptionPerSecond < rightMill.appleConsumptionPerSecond
		end

		return leftMill.ciderPerApple > rightMill.ciderPerApple
	end)

	local remainingAppleRatePerSecond = totalAppleRatePerSecond
	local ciderRatePerSecond = 0

	for _, offlineMill in ipairs(offlineMills) do
		if remainingAppleRatePerSecond <= 0 then
			break
		end

		local consumedAppleRatePerSecond = math.min(remainingAppleRatePerSecond, offlineMill.appleConsumptionPerSecond)
		ciderRatePerSecond += consumedAppleRatePerSecond * offlineMill.ciderPerApple
		remainingAppleRatePerSecond -= consumedAppleRatePerSecond
	end

	return math.max(0, ciderRatePerSecond * SECONDS_PER_HOUR)
end

return table.freeze(OfflineCiderRateCalculator)

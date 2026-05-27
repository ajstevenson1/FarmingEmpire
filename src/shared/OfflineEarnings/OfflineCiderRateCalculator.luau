--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local progressionFolder = sharedFolder:WaitForChild("Progression") :: Folder

local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local OfflineEarningsConfig = require(script.Parent:WaitForChild("OfflineEarningsConfig") :: ModuleScript)
local ProgressionConfig = require(progressionFolder:WaitForChild("ProgressionConfig") :: ModuleScript)

type BuildingDefinition = BuildingTypes.BuildingDefinition
type BuildingId = BuildingTypes.BuildingId

export type OfflineRateBuilding = {
	buildingId: BuildingId,
	rateMultiplier: number?,
}

local SECONDS_PER_HOUR = 60 * 60

local function isInvalidNumber(value: number): boolean
	return value ~= value or value == math.huge or value == -math.huge
end

local function getSafeMillCiderPerSecond(buildingDefinition: BuildingDefinition): number
	if not ProgressionConfig.isMillBuildingId(buildingDefinition.id) then
		return 0
	end

	local productionConfig = buildingDefinition.productionConfig
	if productionConfig.behaviorId ~= "InputProcessor" or productionConfig.outputResourceId ~= "Cider" then
		return 0
	end

	local cycleDurationSeconds = productionConfig.cycleDurationSeconds
	local outputAmount = productionConfig.outputAmount
	if isInvalidNumber(cycleDurationSeconds) or isInvalidNumber(outputAmount) or cycleDurationSeconds <= 0 or outputAmount < 0 then
		return 0
	end

	return outputAmount / cycleDurationSeconds
end

local function getSafeTreeApplePerSecond(buildingDefinition: BuildingDefinition): number
	if not ProgressionConfig.isTreeBuildingId(buildingDefinition.id) then
		return 0
	end

	local productionConfig = buildingDefinition.productionConfig
	if productionConfig.behaviorId ~= "TimedStorageProducer" or productionConfig.outputResourceId ~= "Apple" then
		return 0
	end

	local produceIntervalSeconds = productionConfig.produceIntervalSeconds
	local outputAmountPerInterval = productionConfig.outputAmountPerInterval
	if isInvalidNumber(produceIntervalSeconds)
		or isInvalidNumber(outputAmountPerInterval)
		or produceIntervalSeconds <= 0
		or outputAmountPerInterval < 0
	then
		return 0
	end

	return outputAmountPerInterval / produceIntervalSeconds
end

local function getSafeRateMultiplier(rateMultiplier: number?): number
	if rateMultiplier == nil then
		return 1
	end

	if isInvalidNumber(rateMultiplier) or rateMultiplier < 0 then
		return 1
	end

	return rateMultiplier
end

local function getSafeOfflineBoostMultiplier(): number
	local multiplier = OfflineEarningsConfig.offlineMultiplierPerOnlineMultiplier
	if isInvalidNumber(multiplier) or multiplier < 0 then
		return 1
	end

	return multiplier
end

local function getSafeTreeToOfflineCiderConversion(): number
	local conversion = OfflineEarningsConfig.treeToOfflineCiderConversion
	if isInvalidNumber(conversion) or conversion < 0 then
		return 0
	end

	return conversion
end

local function getEffectiveOfflineSeconds(seconds: number): number
	if isInvalidNumber(seconds) or seconds < 0 then
		return 0
	end

	local maxOfflineSeconds = OfflineEarningsConfig.maxOfflineSeconds
	local curveStrength = OfflineEarningsConfig.exponentialCurveStrength
	if isInvalidNumber(maxOfflineSeconds)
		or isInvalidNumber(curveStrength)
		or maxOfflineSeconds <= 0
		or curveStrength <= 0
	then
		return seconds
	end

	local clampedSeconds = math.clamp(seconds, 0, maxOfflineSeconds)
	local progress = clampedSeconds / maxOfflineSeconds
	local denominator = 1 - math.exp(-curveStrength)
	if denominator <= 0 then
		return clampedSeconds
	end

	return math.clamp(maxOfflineSeconds * ((1 - math.exp(-curveStrength * progress)) / denominator), 0, maxOfflineSeconds)
end

local OfflineCiderRateCalculator = {}

function OfflineCiderRateCalculator.calculateCiderPerSecond(buildings: { OfflineRateBuilding }): number
	local ciderPerSecond = 0

	for _, building in ipairs(buildings) do
		local buildingDefinition = BuildingCatalog.getBuildingDefinition(building.buildingId)
		local rateMultiplier = getSafeRateMultiplier(building.rateMultiplier)
		local boostedMillCiderPerSecond = getSafeMillCiderPerSecond(buildingDefinition)
			* rateMultiplier
			* getSafeOfflineBoostMultiplier()
		local orchardBonusCiderPerSecond = getSafeTreeApplePerSecond(buildingDefinition)
			* getSafeTreeToOfflineCiderConversion()
			* rateMultiplier

		ciderPerSecond += boostedMillCiderPerSecond + orchardBonusCiderPerSecond
	end

	return math.max(0, ciderPerSecond)
end

function OfflineCiderRateCalculator.calculateCiderPerHour(buildings: { OfflineRateBuilding }): number
	return OfflineCiderRateCalculator.calculateCiderPerSecond(buildings) * SECONDS_PER_HOUR
end

function OfflineCiderRateCalculator.calculateCiderForSeconds(ciderPerSecond: number, seconds: number): number
	if isInvalidNumber(ciderPerSecond) or ciderPerSecond < 0 then
		return 0
	end

	return math.max(0, math.floor(ciderPerSecond * getEffectiveOfflineSeconds(seconds)))
end

return table.freeze(OfflineCiderRateCalculator)

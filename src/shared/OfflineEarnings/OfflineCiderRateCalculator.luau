--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)

type BuildingDefinition = BuildingTypes.BuildingDefinition
type BuildingId = BuildingTypes.BuildingId

export type OfflineRateBuilding = {
	buildingId: BuildingId,
}

local SECONDS_PER_HOUR = 60 * 60

local function getSafeCiderPerSecond(buildingDefinition: BuildingDefinition): number
	local offlineEarningsConfig = buildingDefinition.offlineEarningsConfig
	if offlineEarningsConfig == nil then
		return 0
	end

	local ciderPerSecond = offlineEarningsConfig.ciderPerSecond
	if ciderPerSecond ~= ciderPerSecond or ciderPerSecond == math.huge or ciderPerSecond == -math.huge or ciderPerSecond < 0 then
		return 0
	end

	return ciderPerSecond
end

local OfflineCiderRateCalculator = {}

function OfflineCiderRateCalculator.calculateCiderPerSecond(buildings: { OfflineRateBuilding }): number
	local ciderPerSecond = 0

	for _, building in ipairs(buildings) do
		local buildingDefinition = BuildingCatalog.getBuildingDefinition(building.buildingId)
		ciderPerSecond += getSafeCiderPerSecond(buildingDefinition)
	end

	return math.max(0, ciderPerSecond)
end

function OfflineCiderRateCalculator.calculateCiderPerHour(buildings: { OfflineRateBuilding }): number
	return OfflineCiderRateCalculator.calculateCiderPerSecond(buildings) * SECONDS_PER_HOUR
end

function OfflineCiderRateCalculator.calculateCiderForSeconds(ciderPerSecond: number, seconds: number): number
	if ciderPerSecond ~= ciderPerSecond or ciderPerSecond == math.huge or ciderPerSecond == -math.huge or ciderPerSecond < 0 then
		return 0
	end

	if seconds ~= seconds or seconds == math.huge or seconds == -math.huge or seconds < 0 then
		return 0
	end

	return math.max(0, math.floor(ciderPerSecond * seconds))
end

return table.freeze(OfflineCiderRateCalculator)

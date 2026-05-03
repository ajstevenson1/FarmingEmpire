--!strict

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local ResourceCatalog = require(resourcesFolder:WaitForChild("ResourceCatalog") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)

type BuildingId = BuildingTypes.BuildingId
type ResourceId = ResourceTypes.ResourceId

export type PlayerEconomyData = {
	cash: number,
}

export type PlacedBuildingData = {
	buildingId: BuildingId,
	gridX: number,
	gridZ: number,
}

export type PlayerData = {
	schemaVersion: number,
	economy: PlayerEconomyData,
	resources: { [ResourceId]: number },
	placedBuildings: { PlacedBuildingData },
}

export type LoadResult = {
	didLoad: boolean,
	data: PlayerData,
}

local DATA_STORE_NAME = "FarmingEmpire_PlayerData_DEV"
local CURRENT_SCHEMA_VERSION = 2
local MAX_ATTEMPTS = 3
local RETRY_DELAY_SECONDS = 2

local dataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)

local function getPlayerKey(userId: number): string
	return `Player_{userId}`
end

local function sanitizeAmount(value: unknown): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge or value < 0 then
		return 0
	end

	return math.floor(value)
end

local function sanitizeGridCoordinate(value: unknown): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end

	if value ~= math.floor(value) then
		return nil
	end

	return value
end

local function createDefaultData(): PlayerData
	local resources: { [ResourceId]: number } = {}
	for resourceId in pairs(ResourceCatalog.getAllResourceDefinitions()) do
		resources[resourceId] = 0
	end

	return {
		schemaVersion = CURRENT_SCHEMA_VERSION,
		economy = {
			cash = 0,
		},
		resources = resources,
		placedBuildings = {},
	}
end

local function sanitizeResources(rawResources: unknown): { [ResourceId]: number }
	local sanitized: { [ResourceId]: number } = {}
	local rawResourceValues: { [string]: unknown } = {}

	if type(rawResources) == "table" then
		rawResourceValues = rawResources :: { [string]: unknown }
	end

	for resourceId in pairs(ResourceCatalog.getAllResourceDefinitions()) do
		sanitized[resourceId] = sanitizeAmount(rawResourceValues[resourceId])
	end

	return sanitized
end

local function sanitizePlacedBuildings(rawPlacedBuildings: unknown): { PlacedBuildingData }
	local placedBuildings: { PlacedBuildingData } = {}
	if type(rawPlacedBuildings) ~= "table" then
		return placedBuildings
	end

	for _, rawPlacedBuilding in ipairs(rawPlacedBuildings :: { unknown }) do
		if type(rawPlacedBuilding) == "table" then
			local rawPlacedBuildingValues = rawPlacedBuilding :: { [string]: unknown }
			local rawBuildingId = rawPlacedBuildingValues.buildingId
			local gridX = sanitizeGridCoordinate(rawPlacedBuildingValues.gridX)
			local gridZ = sanitizeGridCoordinate(rawPlacedBuildingValues.gridZ)

			if type(rawBuildingId) == "string"
				and BuildingCatalog.hasBuildingDefinition(rawBuildingId)
				and gridX ~= nil
				and gridZ ~= nil then
				table.insert(placedBuildings, {
					buildingId = rawBuildingId :: BuildingId,
					gridX = gridX,
					gridZ = gridZ,
				})
			end
		end
	end

	return placedBuildings
end

local function sanitizeData(rawData: unknown): PlayerData
	if type(rawData) ~= "table" then
		return createDefaultData()
	end

	local rawDataTable = rawData :: { [string]: unknown }
	local rawEconomy = rawDataTable.economy
	local rawEconomyValues: { [string]: unknown } = {}
	if type(rawEconomy) == "table" then
		rawEconomyValues = rawEconomy :: { [string]: unknown }
	end

	return {
		schemaVersion = CURRENT_SCHEMA_VERSION,
		economy = {
			cash = sanitizeAmount(rawEconomyValues.cash),
		},
		resources = sanitizeResources(rawDataTable.resources),
		placedBuildings = sanitizePlacedBuildings(rawDataTable.placedBuildings),
	}
end

local function cloneData(data: PlayerData): PlayerData
	local resources: { [ResourceId]: number } = {}
	for resourceId in pairs(ResourceCatalog.getAllResourceDefinitions()) do
		resources[resourceId] = sanitizeAmount(data.resources[resourceId])
	end

	local placedBuildings: { PlacedBuildingData } = {}
	for _, placedBuilding in ipairs(data.placedBuildings) do
		table.insert(placedBuildings, {
			buildingId = placedBuilding.buildingId,
			gridX = placedBuilding.gridX,
			gridZ = placedBuilding.gridZ,
		})
	end

	return {
		schemaVersion = CURRENT_SCHEMA_VERSION,
		economy = {
			cash = sanitizeAmount(data.economy.cash),
		},
		resources = resources,
		placedBuildings = placedBuildings,
	}
end

local function waitBeforeRetry(attempt: number)
	if attempt < MAX_ATTEMPTS then
		task.wait(RETRY_DELAY_SECONDS * attempt)
	end
end

local PlayerDataStore = {}

function PlayerDataStore.createDefaultData(): PlayerData
	return createDefaultData()
end

function PlayerDataStore.cloneData(data: PlayerData): PlayerData
	return cloneData(data)
end

function PlayerDataStore.loadAsync(userId: number): LoadResult
	local key = getPlayerKey(userId)

	for attempt = 1, MAX_ATTEMPTS do
		local success, result = pcall(function(): unknown
			return dataStore:GetAsync(key)
		end)

		if success then
			return {
				didLoad = true,
				data = sanitizeData(result),
			}
		end

		warn(string.format("Failed to load data for userId %d on attempt %d: %s", userId, attempt, tostring(result)))
		waitBeforeRetry(attempt)
	end

	return {
		didLoad = false,
		data = createDefaultData(),
	}
end

function PlayerDataStore.saveAsync(userId: number, data: PlayerData): boolean
	local key = getPlayerKey(userId)
	local dataToSave = cloneData(data)

	for attempt = 1, MAX_ATTEMPTS do
		local success, result = pcall(function()
			dataStore:SetAsync(key, dataToSave)
		end)

		if success then
			return true
		end

		warn(string.format("Failed to save data for userId %d on attempt %d: %s", userId, attempt, tostring(result)))
		waitBeforeRetry(attempt)
	end

	return false
end

return table.freeze(PlayerDataStore)

--!strict

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local HotbarConfig = require(inventoryFolder:WaitForChild("HotbarConfig") :: ModuleScript)
local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local ResourceCatalog = require(resourcesFolder:WaitForChild("ResourceCatalog") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)

type BuildingId = BuildingTypes.BuildingId
type InventoryEntry = InventoryTypes.InventoryEntry
type ItemId = InventoryTypes.ItemId
type ProductionState = BuildingTypes.ProductionState
type ResourceId = ResourceTypes.ResourceId
type SavedProductionState = BuildingTypes.SavedProductionState

export type PlayerEconomyData = {
	cash: number,
}

export type PlacedBuildingData = {
	buildingId: BuildingId,
	gridX: number,
	gridZ: number,
	production: SavedProductionState?,
}

export type HotbarSlotData = {
	slotIndex: number,
	itemId: ItemId,
}

export type PlayerInventoryData = {
	entries: { InventoryEntry },
	hotbarSlots: { HotbarSlotData },
	selectedSlotIndex: number?,
}

export type PlayerData = {
	schemaVersion: number,
	economy: PlayerEconomyData,
	resources: { [ResourceId]: number },
	placedBuildings: { PlacedBuildingData },
	inventory: PlayerInventoryData?,
}

export type LoadResult = {
	didLoad: boolean,
	data: PlayerData,
}

local DATA_STORE_NAME = "FarmingEmpire_PlayerData_DEV"
local CURRENT_SCHEMA_VERSION = 4
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

local function sanitizeDuration(value: unknown): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge or value < 0 then
		return 0
	end

	return value
end

local function sanitizeProductionState(value: unknown): ProductionState?
	if value == "Growing"
		or value == "Ready"
		or value == "Idle"
		or value == "Processing"
		or value == "Blocked"
	then
		return value :: ProductionState
	end

	return nil
end

local function sanitizeSavedProductionState(rawProduction: unknown): SavedProductionState?
	if type(rawProduction) ~= "table" then
		return nil
	end

	local rawProductionValues = rawProduction :: { [string]: unknown }
	local behaviorId = rawProductionValues.behaviorId
	local productionState = sanitizeProductionState(rawProductionValues.state)
	if type(behaviorId) ~= "string" or productionState == nil then
		return nil
	end

	local storedAmount = sanitizeAmount(rawProductionValues.storedAmount)
	if behaviorId == "GrowAndHarvest" then
		return {
			behaviorId = "GrowAndHarvest",
			state = productionState,
			storedAmount = storedAmount,
			secondsUntilReady = sanitizeDuration(rawProductionValues.secondsUntilReady),
		}
	elseif behaviorId == "TimedStorageProducer" then
		return {
			behaviorId = "TimedStorageProducer",
			state = productionState,
			storedAmount = storedAmount,
			secondsUntilNextProduce = sanitizeDuration(rawProductionValues.secondsUntilNextProduce),
		}
	elseif behaviorId == "InputProcessor" then
		local secondsUntilCycleFinishes: number? = nil
		if rawProductionValues.secondsUntilCycleFinishes ~= nil then
			secondsUntilCycleFinishes = sanitizeDuration(rawProductionValues.secondsUntilCycleFinishes)
		end

		return {
			behaviorId = "InputProcessor",
			state = productionState,
			storedAmount = storedAmount,
			secondsUntilCycleFinishes = secondsUntilCycleFinishes,
		}
	end

	return nil
end

local function cloneSavedProductionState(production: SavedProductionState?): SavedProductionState?
	if production == nil then
		return nil
	end

	if production.behaviorId == "GrowAndHarvest" then
		return {
			behaviorId = "GrowAndHarvest",
			state = production.state,
			storedAmount = sanitizeAmount(production.storedAmount),
			secondsUntilReady = sanitizeDuration(production.secondsUntilReady),
		}
	elseif production.behaviorId == "TimedStorageProducer" then
		return {
			behaviorId = "TimedStorageProducer",
			state = production.state,
			storedAmount = sanitizeAmount(production.storedAmount),
			secondsUntilNextProduce = sanitizeDuration(production.secondsUntilNextProduce),
		}
	elseif production.behaviorId == "InputProcessor" then
		local secondsUntilCycleFinishes: number? = nil
		if production.secondsUntilCycleFinishes ~= nil then
			secondsUntilCycleFinishes = sanitizeDuration(production.secondsUntilCycleFinishes)
		end

		return {
			behaviorId = "InputProcessor",
			state = production.state,
			storedAmount = sanitizeAmount(production.storedAmount),
			secondsUntilCycleFinishes = secondsUntilCycleFinishes,
		}
	end

	return nil
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
		inventory = nil,
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
					production = sanitizeSavedProductionState(rawPlacedBuildingValues.production),
				})
			end
		end
	end

	return placedBuildings
end

local function sanitizeInventoryEntries(rawEntries: unknown): { InventoryEntry }
	local entries: { InventoryEntry } = {}
	if type(rawEntries) ~= "table" then
		return entries
	end

	local quantitiesByItemId: { [ItemId]: number } = {}
	for _, rawEntry in ipairs(rawEntries :: { unknown }) do
		if type(rawEntry) == "table" then
			local rawEntryValues = rawEntry :: { [string]: unknown }
			local rawItemId = rawEntryValues.itemId
			local quantity = sanitizeAmount(rawEntryValues.quantity)

			if type(rawItemId) == "string" and ItemCatalog.hasItemDefinition(rawItemId) and quantity > 0 then
				local itemId = rawItemId :: ItemId
				quantitiesByItemId[itemId] = sanitizeAmount((quantitiesByItemId[itemId] or 0) + quantity)
			end
		end
	end

	for itemId, quantity in pairs(quantitiesByItemId) do
		table.insert(entries, {
			itemId = itemId,
			quantity = quantity,
		})
	end

	table.sort(entries, function(leftEntry, rightEntry)
		local leftDefinition = ItemCatalog.getItemDefinition(leftEntry.itemId)
		local rightDefinition = ItemCatalog.getItemDefinition(rightEntry.itemId)

		if leftDefinition.inventoryOrder == rightDefinition.inventoryOrder then
			return leftDefinition.displayName < rightDefinition.displayName
		end

		return leftDefinition.inventoryOrder < rightDefinition.inventoryOrder
	end)

	return entries
end

local function sanitizeHotbarSlots(rawHotbarSlots: unknown): { HotbarSlotData }
	local hotbarSlots: { HotbarSlotData } = {}
	if type(rawHotbarSlots) ~= "table" then
		return hotbarSlots
	end

	local seenSlots: { [number]: boolean } = {}
	local seenItems: { [ItemId]: boolean } = {}

	for _, rawHotbarSlot in ipairs(rawHotbarSlots :: { unknown }) do
		if type(rawHotbarSlot) == "table" then
			local rawHotbarSlotValues = rawHotbarSlot :: { [string]: unknown }
			local rawSlotIndex = rawHotbarSlotValues.slotIndex
			local rawItemId = rawHotbarSlotValues.itemId

			if type(rawSlotIndex) == "number"
				and rawSlotIndex == math.floor(rawSlotIndex)
				and HotbarConfig.isAssignableSlotIndex(rawSlotIndex)
				and type(rawItemId) == "string"
				and rawItemId ~= "Scythe"
				and ItemCatalog.hasItemDefinition(rawItemId)
			then
				local itemId = rawItemId :: ItemId
				if seenSlots[rawSlotIndex] ~= true and seenItems[itemId] ~= true then
					seenSlots[rawSlotIndex] = true
					seenItems[itemId] = true
					table.insert(hotbarSlots, {
						slotIndex = rawSlotIndex,
						itemId = itemId,
					})
				end
			end
		end
	end

	table.sort(hotbarSlots, function(leftSlot, rightSlot)
		return leftSlot.slotIndex < rightSlot.slotIndex
	end)

	return hotbarSlots
end

local function sanitizeSelectedSlotIndex(rawSelectedSlotIndex: unknown): number?
	if type(rawSelectedSlotIndex) ~= "number" or rawSelectedSlotIndex ~= math.floor(rawSelectedSlotIndex) then
		return nil
	end

	if not HotbarConfig.isSlotIndexInRange(rawSelectedSlotIndex) then
		return nil
	end

	return rawSelectedSlotIndex
end

local function sanitizeInventory(rawInventory: unknown): PlayerInventoryData?
	if type(rawInventory) ~= "table" then
		return nil
	end

	local rawInventoryValues = rawInventory :: { [string]: unknown }
	return {
		entries = sanitizeInventoryEntries(rawInventoryValues.entries),
		hotbarSlots = sanitizeHotbarSlots(rawInventoryValues.hotbarSlots),
		selectedSlotIndex = sanitizeSelectedSlotIndex(rawInventoryValues.selectedSlotIndex),
	}
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
		inventory = sanitizeInventory(rawDataTable.inventory),
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
			production = cloneSavedProductionState(placedBuilding.production),
		})
	end

	local inventory: PlayerInventoryData? = nil
	if data.inventory ~= nil then
		local entries: { InventoryEntry } = {}
		for _, entry in ipairs(data.inventory.entries) do
			local quantity = sanitizeAmount(entry.quantity)
			if ItemCatalog.hasItemDefinition(entry.itemId) and quantity > 0 then
				table.insert(entries, {
					itemId = entry.itemId,
					quantity = quantity,
				})
			end
		end

		local hotbarSlots: { HotbarSlotData } = {}
		for _, hotbarSlot in ipairs(data.inventory.hotbarSlots) do
			if HotbarConfig.isAssignableSlotIndex(hotbarSlot.slotIndex)
				and hotbarSlot.itemId ~= "Scythe"
				and ItemCatalog.hasItemDefinition(hotbarSlot.itemId)
			then
				table.insert(hotbarSlots, {
					slotIndex = hotbarSlot.slotIndex,
					itemId = hotbarSlot.itemId,
				})
			end
		end

		inventory = {
			entries = entries,
			hotbarSlots = hotbarSlots,
			selectedSlotIndex = sanitizeSelectedSlotIndex(data.inventory.selectedSlotIndex),
		}
	end

	return {
		schemaVersion = CURRENT_SCHEMA_VERSION,
		economy = {
			cash = sanitizeAmount(data.economy.cash),
		},
		resources = resources,
		placedBuildings = placedBuildings,
		inventory = inventory,
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

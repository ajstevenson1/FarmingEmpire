--!strict

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local plotsFolder = sharedFolder:WaitForChild("Plots") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder
local settingsFolder = sharedFolder:WaitForChild("Settings") :: Folder
local playtimeRewardsFolder = sharedFolder:WaitForChild("PlaytimeRewards") :: Folder

local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local PlaytimeRewardsConfig = require(playtimeRewardsFolder:WaitForChild("PlaytimeRewardsConfig") :: ModuleScript)
local DailyRewardsConfig = require(playtimeRewardsFolder:WaitForChild("DailyRewardsConfig") :: ModuleScript)
local PlaytimeRewardsTypes = require(playtimeRewardsFolder:WaitForChild("PlaytimeRewardsTypes") :: ModuleScript)
local HotbarConfig = require(inventoryFolder:WaitForChild("HotbarConfig") :: ModuleScript)
local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local PlotExpansionConfig = require(plotsFolder:WaitForChild("PlotExpansionConfig") :: ModuleScript)
local PlotExpansionTypes = require(plotsFolder:WaitForChild("PlotExpansionTypes") :: ModuleScript)
local PlotExpansionUtils = require(plotsFolder:WaitForChild("PlotExpansionUtils") :: ModuleScript)
local ResourceCatalog = require(resourcesFolder:WaitForChild("ResourceCatalog") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)
local SettingsConfig = require(settingsFolder:WaitForChild("SettingsConfig") :: ModuleScript)

type BuildingId = BuildingTypes.BuildingId
type PlacementRotationQuarterTurns = BuildingTypes.PlacementRotationQuarterTurns
type InventoryEntry = InventoryTypes.InventoryEntry
type ItemId = InventoryTypes.ItemId
type ProductionState = BuildingTypes.ProductionState
type PlotTileCoordinate = PlotExpansionTypes.PlotTileCoordinate
type ResourceId = ResourceTypes.ResourceId
type SavedProductionState = BuildingTypes.SavedProductionState
type SettingsValues = SettingsConfig.SettingsValues
type PlayerPlaytimeRewardsData = PlaytimeRewardsTypes.PlayerPlaytimeRewardsData
type PlayerDailyRewardsData = PlaytimeRewardsTypes.PlayerDailyRewardsData

export type PlayerEconomyData = {
	cash: number,
	lifetimeCashEarned: number,
}

export type PlayerOfflineData = {
	lastSeenAt: number,
	pendingCider: number,
	ciderPerSecondSnapshot: number,
}

export type PlacedBuildingData = {
	buildingId: BuildingId,
	gridX: number,
	gridZ: number,
	rotationQuarterTurns: PlacementRotationQuarterTurns,
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

export type PlayerTutorialData = {
	stepIndex: number,
	completed: boolean,
}

export type PlayerData = {
	schemaVersion: number,
	economy: PlayerEconomyData,
	resources: { [ResourceId]: number },
	placedBuildings: { PlacedBuildingData },
	unlockedPlotTiles: { PlotTileCoordinate },
	inventory: PlayerInventoryData?,
	offline: PlayerOfflineData,
	settings: SettingsValues,
	playtimeRewards: PlayerPlaytimeRewardsData,
	dailyRewards: PlayerDailyRewardsData,
	tutorial: PlayerTutorialData,
}

export type LoadResult = {
	didLoad: boolean,
	data: PlayerData,
}

local DATA_STORE_NAME = "CiderEmpire_PlayerData_DEV_LEBRON33"
local CURRENT_SCHEMA_VERSION = 2
local MAX_ATTEMPTS = 3
local RETRY_DELAY_SECONDS = 2

local dataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)
local PLAYTIME_REWARDS_CYCLE_LENGTH = PlaytimeRewardsConfig.getCycleLength()
local DAILY_REWARDS_CYCLE_LENGTH = DailyRewardsConfig.getCycleLength()

local function getPlayerKey(userId: number): string
	return `Player_{userId}`
end

local function sanitizeAmount(value: unknown): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge or value < 0 then
		return 0
	end

	return math.floor(value)
end

local function sanitizeRate(value: unknown): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge or value < 0 then
		return 0
	end

	return value
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

local function sanitizePlacementRotationQuarterTurns(value: unknown): PlacementRotationQuarterTurns?
	local gridCoordinate = sanitizeGridCoordinate(value)
	if gridCoordinate == nil then
		return nil
	end

	local normalizedRotation = ((gridCoordinate % 4) + 4) % 4
	if normalizedRotation == 0 then
		return 0
	elseif normalizedRotation == 1 then
		return 1
	elseif normalizedRotation == 2 then
		return 2
	end

	return 3
end

local function sanitizeDuration(value: unknown): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge or value < 0 then
		return 0
	end

	return value
end

local function sanitizeTutorialData(rawTutorial: unknown): PlayerTutorialData
	local rawTutorialValues: { [string]: unknown } = {}
	if type(rawTutorial) == "table" then
		rawTutorialValues = rawTutorial :: { [string]: unknown }
	end

	local rawStepIndex = rawTutorialValues.stepIndex
	local stepIndex = if type(rawStepIndex) == "number" and rawStepIndex == math.floor(rawStepIndex) and rawStepIndex > 0
		then rawStepIndex
		else 1

	return {
		stepIndex = stepIndex,
		completed = rawTutorialValues.completed == true,
	}
end

local function sanitizeTimestamp(value: unknown): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge or value < 0 then
		return 0
	end

	return math.floor(value)
end

local function sanitizeRewardIndex(value: unknown, cycleLength: number): number?
	local numericValue: number? = nil
	if type(value) == "number" then
		numericValue = value
	elseif type(value) == "string" then
		numericValue = tonumber(value)
	end

	if numericValue == nil
		or numericValue ~= math.floor(numericValue)
		or numericValue < 1
		or numericValue > cycleLength
	then
		return nil
	end

	return numericValue
end

local function sanitizeItemId(value: unknown): ItemId?
	if type(value) ~= "string" then
		return nil
	end

	if not ItemCatalog.hasItemDefinition(value) then
		return nil
	end

	return value :: ItemId
end

local function sanitizeBuildingId(value: unknown): BuildingId?
	if type(value) ~= "string" then
		return nil
	end

	if not BuildingCatalog.hasBuildingDefinition(value) then
		return nil
	end

	return value :: BuildingId
end

local function cloneTileCoordinate(tileCoordinate: PlotTileCoordinate): PlotTileCoordinate
	return {
		row = tileCoordinate.row,
		column = tileCoordinate.column,
	}
end

local function buildStarterUnlockedTiles(): { PlotTileCoordinate }
	return {
		cloneTileCoordinate(PlotExpansionConfig.getStarterTile()),
	}
end

local function insertUniqueTileCoordinate(
	into: { PlotTileCoordinate },
	seenTileKeys: { [string]: boolean },
	row: number,
	column: number
)
	if not PlotExpansionConfig.isValidTileCoordinate(row, column) then
		return
	end

	local tileKey = PlotExpansionUtils.getTileKey(row, column)
	if seenTileKeys[tileKey] == true then
		return
	end

	seenTileKeys[tileKey] = true
	table.insert(into, {
		row = row,
		column = column,
	})
end

local function sanitizeClaimedRewardIndexes(rawClaimedRewardIndexes: unknown, cycleLength: number): { [number]: boolean }
	local claimedRewardIndexes: { [number]: boolean } = {}
	if type(rawClaimedRewardIndexes) ~= "table" then
		return claimedRewardIndexes
	end

	for rawRewardIndex, rawIsClaimed in pairs(rawClaimedRewardIndexes :: { [string]: unknown }) do
		if rawIsClaimed == true then
			local rewardIndex = sanitizeRewardIndex(rawRewardIndex, cycleLength)
			if rewardIndex ~= nil then
				claimedRewardIndexes[rewardIndex] = true
			end
		end
	end

	return claimedRewardIndexes
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
		local pendingOutputAmount: number? = nil
		if rawProductionValues.pendingOutputAmount ~= nil then
			pendingOutputAmount = sanitizeAmount(rawProductionValues.pendingOutputAmount)
		end

		return {
			behaviorId = "InputProcessor",
			state = productionState,
			storedAmount = storedAmount,
			secondsUntilCycleFinishes = secondsUntilCycleFinishes,
			pendingOutputAmount = pendingOutputAmount,
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
		local pendingOutputAmount: number? = nil
		if production.pendingOutputAmount ~= nil then
			pendingOutputAmount = sanitizeAmount(production.pendingOutputAmount)
		end

		return {
			behaviorId = "InputProcessor",
			state = production.state,
			storedAmount = sanitizeAmount(production.storedAmount),
			secondsUntilCycleFinishes = secondsUntilCycleFinishes,
			pendingOutputAmount = pendingOutputAmount,
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
			cash = 250,
			lifetimeCashEarned = 0,
		},
		resources = resources,
		placedBuildings = {},
		unlockedPlotTiles = buildStarterUnlockedTiles(),
		inventory = nil,
		offline = {
			lastSeenAt = 0,
			pendingCider = 0,
			ciderPerSecondSnapshot = 0,
		},
		settings = SettingsConfig.getDefaultValues(),
		playtimeRewards = {
			accumulatedPlaytimeSeconds = 0,
			claimedRewardIndexes = {},
			totalClaims = 0,
		},
		dailyRewards = {
			claimedRewardIndexes = {},
			lastClaimUnixTime = 0,
			nextRewardIndex = 1,
			totalClaims = 0,
		},
		tutorial = {
			stepIndex = 1,
			completed = false,
		},
	}
end

local function sanitizePlaytimeRewardsData(rawPlaytimeRewards: unknown): PlayerPlaytimeRewardsData
	local rawPlaytimeRewardsValues: { [string]: unknown } = {}
	if type(rawPlaytimeRewards) == "table" then
		rawPlaytimeRewardsValues = rawPlaytimeRewards :: { [string]: unknown }
	end

	local claimedRewardIndexes = sanitizeClaimedRewardIndexes(rawPlaytimeRewardsValues.claimedRewardIndexes, PLAYTIME_REWARDS_CYCLE_LENGTH)
	local totalClaims = if rawPlaytimeRewardsValues.claimedRewardIndexes == nil then 0 else sanitizeAmount(rawPlaytimeRewardsValues.totalClaims)

	return {
		accumulatedPlaytimeSeconds = sanitizeDuration(rawPlaytimeRewardsValues.accumulatedPlaytimeSeconds),
		claimedRewardIndexes = claimedRewardIndexes,
		totalClaims = totalClaims,
	}
end

local function sanitizeDailyRewardsData(rawDailyRewards: unknown): PlayerDailyRewardsData
	local rawDailyRewardsValues: { [string]: unknown } = {}
	if type(rawDailyRewards) == "table" then
		rawDailyRewardsValues = rawDailyRewards :: { [string]: unknown }
	end

	local claimedRewardIndexes = sanitizeClaimedRewardIndexes(rawDailyRewardsValues.claimedRewardIndexes, DAILY_REWARDS_CYCLE_LENGTH)
	local totalClaims = if rawDailyRewardsValues.claimedRewardIndexes == nil then 0 else sanitizeAmount(rawDailyRewardsValues.totalClaims)
	local nextRewardIndex = sanitizeRewardIndex(rawDailyRewardsValues.nextRewardIndex, DAILY_REWARDS_CYCLE_LENGTH) or 1

	return {
		claimedRewardIndexes = claimedRewardIndexes,
		lastClaimUnixTime = sanitizeTimestamp(rawDailyRewardsValues.lastClaimUnixTime),
		nextRewardIndex = nextRewardIndex,
		totalClaims = totalClaims,
	}
end

local function sanitizeOfflineData(rawOffline: unknown): PlayerOfflineData
	local rawOfflineValues: { [string]: unknown } = {}
	if type(rawOffline) == "table" then
		rawOfflineValues = rawOffline :: { [string]: unknown }
	end

	return {
		lastSeenAt = sanitizeTimestamp(rawOfflineValues.lastSeenAt),
		pendingCider = sanitizeAmount(rawOfflineValues.pendingCider),
		ciderPerSecondSnapshot = sanitizeRate(rawOfflineValues.ciderPerSecondSnapshot),
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

local function sanitizeUnlockedPlotTiles(rawUnlockedPlotTiles: unknown): { PlotTileCoordinate }
	local unlockedPlotTiles: { PlotTileCoordinate } = {}
	local seenTileKeys: { [string]: boolean } = {}

	if type(rawUnlockedPlotTiles) == "table" then
		for _, rawTileCoordinate in ipairs(rawUnlockedPlotTiles :: { unknown }) do
			if type(rawTileCoordinate) == "table" then
				local rawTileCoordinateValues = rawTileCoordinate :: { [string]: unknown }
				local row = sanitizeGridCoordinate(rawTileCoordinateValues.row)
				local column = sanitizeGridCoordinate(rawTileCoordinateValues.column)
				if row ~= nil and column ~= nil then
					insertUniqueTileCoordinate(unlockedPlotTiles, seenTileKeys, row, column)
				end
			end
		end
	end

	local starterTile = PlotExpansionConfig.getStarterTile()
	insertUniqueTileCoordinate(unlockedPlotTiles, seenTileKeys, starterTile.row, starterTile.column)

	table.sort(unlockedPlotTiles, function(leftTile, rightTile)
		if leftTile.row == rightTile.row then
			return leftTile.column < rightTile.column
		end

		return leftTile.row < rightTile.row
	end)

	return unlockedPlotTiles
end

local function sanitizePlacedBuildings(rawPlacedBuildings: unknown): { PlacedBuildingData }
	local placedBuildings: { PlacedBuildingData } = {}
	if type(rawPlacedBuildings) ~= "table" then
		return placedBuildings
	end

	for _, rawPlacedBuilding in ipairs(rawPlacedBuildings :: { unknown }) do
		if type(rawPlacedBuilding) == "table" then
			local rawPlacedBuildingValues = rawPlacedBuilding :: { [string]: unknown }
			local buildingId = sanitizeBuildingId(rawPlacedBuildingValues.buildingId)
			local gridX = sanitizeGridCoordinate(rawPlacedBuildingValues.gridX)
			local gridZ = sanitizeGridCoordinate(rawPlacedBuildingValues.gridZ)
			local rotationQuarterTurns = sanitizePlacementRotationQuarterTurns(rawPlacedBuildingValues.rotationQuarterTurns) or 0

			if buildingId ~= nil and gridX ~= nil and gridZ ~= nil then
				table.insert(placedBuildings, {
					buildingId = buildingId,
					gridX = gridX,
					gridZ = gridZ,
					rotationQuarterTurns = rotationQuarterTurns,
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
			local itemId = sanitizeItemId(rawEntryValues.itemId)
			local quantity = sanitizeAmount(rawEntryValues.quantity)

			if itemId ~= nil and quantity > 0 then
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
			local itemId = sanitizeItemId(rawHotbarSlotValues.itemId)

			if type(rawSlotIndex) == "number"
				and rawSlotIndex == math.floor(rawSlotIndex)
				and HotbarConfig.isAssignableSlotIndex(rawSlotIndex)
				and itemId ~= nil
				and itemId ~= "Scythe"
			then
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
	local rawPlaytimeRewards = rawDataTable.playtimeRewards
	if rawPlaytimeRewards == nil then
		rawPlaytimeRewards = rawDataTable["daily" .. "Rewards"]
	end
	local rawDailyRewards = rawDataTable.dailyRewards
	local rawEconomy = rawDataTable.economy
	local rawEconomyValues: { [string]: unknown } = {}
	if type(rawEconomy) == "table" then
		rawEconomyValues = rawEconomy :: { [string]: unknown }
	end

	return {
		schemaVersion = CURRENT_SCHEMA_VERSION,
		economy = {
			cash = sanitizeAmount(rawEconomyValues.cash),
			lifetimeCashEarned = sanitizeAmount(rawEconomyValues.lifetimeCashEarned),
		},
		resources = sanitizeResources(rawDataTable.resources),
		placedBuildings = sanitizePlacedBuildings(rawDataTable.placedBuildings),
		unlockedPlotTiles = sanitizeUnlockedPlotTiles(rawDataTable.unlockedPlotTiles),
		inventory = sanitizeInventory(rawDataTable.inventory),
		offline = sanitizeOfflineData(rawDataTable.offline),
		settings = SettingsConfig.sanitizeValues(rawDataTable.settings),
		playtimeRewards = sanitizePlaytimeRewardsData(rawPlaytimeRewards),
		dailyRewards = sanitizeDailyRewardsData(rawDailyRewards),
		tutorial = sanitizeTutorialData(rawDataTable.tutorial),
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
			rotationQuarterTurns = sanitizePlacementRotationQuarterTurns(placedBuilding.rotationQuarterTurns) or 0,
			production = cloneSavedProductionState(placedBuilding.production),
		})
	end

	local unlockedPlotTiles: { PlotTileCoordinate } = {}
	for _, unlockedPlotTile in ipairs(data.unlockedPlotTiles) do
		table.insert(unlockedPlotTiles, cloneTileCoordinate(unlockedPlotTile))
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
			lifetimeCashEarned = sanitizeAmount(data.economy.lifetimeCashEarned),
		},
		resources = resources,
		placedBuildings = placedBuildings,
		unlockedPlotTiles = sanitizeUnlockedPlotTiles(unlockedPlotTiles),
		inventory = inventory,
		offline = {
			lastSeenAt = sanitizeTimestamp(data.offline.lastSeenAt),
			pendingCider = sanitizeAmount(data.offline.pendingCider),
			ciderPerSecondSnapshot = sanitizeRate(data.offline.ciderPerSecondSnapshot),
		},
		settings = SettingsConfig.sanitizeValues(data.settings),
		playtimeRewards = {
			accumulatedPlaytimeSeconds = sanitizeDuration(data.playtimeRewards.accumulatedPlaytimeSeconds),
			claimedRewardIndexes = sanitizeClaimedRewardIndexes(data.playtimeRewards.claimedRewardIndexes, PLAYTIME_REWARDS_CYCLE_LENGTH),
			totalClaims = sanitizeAmount(data.playtimeRewards.totalClaims),
		},
		dailyRewards = {
			claimedRewardIndexes = sanitizeClaimedRewardIndexes(data.dailyRewards.claimedRewardIndexes, DAILY_REWARDS_CYCLE_LENGTH),
			lastClaimUnixTime = sanitizeTimestamp(data.dailyRewards.lastClaimUnixTime),
			nextRewardIndex = sanitizeRewardIndex(data.dailyRewards.nextRewardIndex, DAILY_REWARDS_CYCLE_LENGTH) or 1,
			totalClaims = sanitizeAmount(data.dailyRewards.totalClaims),
		},
		tutorial = sanitizeTutorialData(data.tutorial),
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

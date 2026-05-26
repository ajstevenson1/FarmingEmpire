--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local plotsFolder = sharedFolder:WaitForChild("Plots") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder
local settingsFolder = sharedFolder:WaitForChild("Settings") :: Folder
local playtimeRewardsFolder = sharedFolder:WaitForChild("PlaytimeRewards") :: Folder

local PlayerDataStore = require(script.Parent.PlayerDataStore)
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
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)
local SettingsConfig = require(settingsFolder:WaitForChild("SettingsConfig") :: ModuleScript)

type PlayerData = PlayerDataStore.PlayerData
type PlayerInventoryData = PlayerDataStore.PlayerInventoryData
type HotbarSlotData = PlayerDataStore.HotbarSlotData
export type PlacedBuildingData = PlayerDataStore.PlacedBuildingData
export type PlayerOfflineData = PlayerDataStore.PlayerOfflineData
export type PlayerTutorialData = PlayerDataStore.PlayerTutorialData
export type UnlockedPlotTileData = PlotExpansionTypes.PlotTileCoordinate
type BuildingId = BuildingTypes.BuildingId
type PlacementRotationQuarterTurns = BuildingTypes.PlacementRotationQuarterTurns
type InventoryEntry = InventoryTypes.InventoryEntry
type ResourceId = ResourceTypes.ResourceId
type SavedProductionState = BuildingTypes.SavedProductionState
type SettingId = SettingsConfig.SettingId
type SettingsValues = SettingsConfig.SettingsValues
export type PlayerPlaytimeRewardsData = PlaytimeRewardsTypes.PlayerPlaytimeRewardsData
export type PlayerDailyRewardsData = PlaytimeRewardsTypes.PlayerDailyRewardsData

type PlayerDataRecord = {
	data: PlayerData,
	canSave: boolean,
	isDirty: boolean,
	isSaving: boolean,
	revision: number,
}

type BeforeSaveListener = (Player) -> ()
type AfterRemoveListener = (Player) -> ()

local AUTOSAVE_INTERVAL_SECONDS = 120

local playerDataRecords: { [Player]: PlayerDataRecord } = {}
local loadingPlayers: { [Player]: boolean } = {}
local beforeSaveListeners: { BeforeSaveListener } = {}
local afterRemoveListeners: { AfterRemoveListener } = {}
local hasStarted = false
local PLAYTIME_REWARDS_CYCLE_LENGTH = PlaytimeRewardsConfig.getCycleLength()
local DAILY_REWARDS_CYCLE_LENGTH = DailyRewardsConfig.getCycleLength()

local function sanitizeAmount(amount: number): number
	if amount ~= amount or amount == math.huge or amount == -math.huge or amount < 0 then
		return 0
	end

	return math.floor(amount)
end

local function sanitizeRate(rate: number): number
	if rate ~= rate or rate == math.huge or rate == -math.huge or rate < 0 then
		return 0
	end

	return rate
end

local function sanitizeGridCoordinate(coordinate: number): number
	if coordinate ~= coordinate or coordinate == math.huge or coordinate == -math.huge then
		return 0
	end

	return math.floor(coordinate)
end

local function sanitizePlacementRotationQuarterTurns(rotationQuarterTurns: number): PlacementRotationQuarterTurns
	local sanitizedRotation = sanitizeGridCoordinate(rotationQuarterTurns)
	local normalizedRotation = ((sanitizedRotation % 4) + 4) % 4
	if normalizedRotation == 0 then
		return 0
	elseif normalizedRotation == 1 then
		return 1
	elseif normalizedRotation == 2 then
		return 2
	end

	return 3
end

local function sanitizeDuration(duration: number): number
	if duration ~= duration or duration == math.huge or duration == -math.huge or duration < 0 then
		return 0
	end

	return duration
end

local function sanitizeTimestamp(timestamp: number): number
	if timestamp ~= timestamp or timestamp == math.huge or timestamp == -math.huge or timestamp < 0 then
		return 0
	end

	return math.floor(timestamp)
end

local function sanitizeSelectedSlotIndex(slotIndex: number?): number?
	if slotIndex == nil then
		return nil
	end

	local sanitizedSlotIndex = sanitizeGridCoordinate(slotIndex)
	if not HotbarConfig.isSlotIndexInRange(sanitizedSlotIndex) then
		return nil
	end

	return sanitizedSlotIndex
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

local function areSavedProductionStatesEqual(left: SavedProductionState?, right: SavedProductionState?): boolean
	if left == nil or right == nil then
		return left == right
	end

	if left.behaviorId ~= right.behaviorId or left.state ~= right.state or sanitizeAmount(left.storedAmount) ~= sanitizeAmount(right.storedAmount) then
		return false
	end

	if left.behaviorId == "GrowAndHarvest" and right.behaviorId == "GrowAndHarvest" then
		return sanitizeDuration(left.secondsUntilReady) == sanitizeDuration(right.secondsUntilReady)
	elseif left.behaviorId == "TimedStorageProducer" and right.behaviorId == "TimedStorageProducer" then
		return sanitizeDuration(left.secondsUntilNextProduce) == sanitizeDuration(right.secondsUntilNextProduce)
	elseif left.behaviorId == "InputProcessor" and right.behaviorId == "InputProcessor" then
		local leftSeconds = if left.secondsUntilCycleFinishes == nil then nil else sanitizeDuration(left.secondsUntilCycleFinishes)
		local rightSeconds = if right.secondsUntilCycleFinishes == nil then nil else sanitizeDuration(right.secondsUntilCycleFinishes)
		local leftPendingOutput = if left.pendingOutputAmount == nil then nil else sanitizeAmount(left.pendingOutputAmount)
		local rightPendingOutput = if right.pendingOutputAmount == nil then nil else sanitizeAmount(right.pendingOutputAmount)
		return leftSeconds == rightSeconds and leftPendingOutput == rightPendingOutput
	end

	return false
end

local function clonePlacedBuildings(placedBuildings: { PlacedBuildingData }): { PlacedBuildingData }
	local clone: { PlacedBuildingData } = {}
	for _, placedBuilding in ipairs(placedBuildings) do
		table.insert(clone, {
			buildingId = placedBuilding.buildingId,
			gridX = sanitizeGridCoordinate(placedBuilding.gridX),
			gridZ = sanitizeGridCoordinate(placedBuilding.gridZ),
			rotationQuarterTurns = sanitizePlacementRotationQuarterTurns(placedBuilding.rotationQuarterTurns),
			production = cloneSavedProductionState(placedBuilding.production),
		})
	end

	table.sort(clone, function(leftBuilding, rightBuilding)
		if leftBuilding.gridX == rightBuilding.gridX then
			if leftBuilding.gridZ == rightBuilding.gridZ then
				if leftBuilding.buildingId == rightBuilding.buildingId then
					return leftBuilding.rotationQuarterTurns < rightBuilding.rotationQuarterTurns
				end

				return leftBuilding.buildingId < rightBuilding.buildingId
			end

			return leftBuilding.gridZ < rightBuilding.gridZ
		end

		return leftBuilding.gridX < rightBuilding.gridX
	end)

	return clone
end

local function cloneUnlockedPlotTiles(unlockedPlotTiles: { UnlockedPlotTileData }): { UnlockedPlotTileData }
	local clone: { UnlockedPlotTileData } = {}
	local seenTileKeys: { [string]: boolean } = {}

	for _, unlockedPlotTile in ipairs(unlockedPlotTiles) do
		local row = sanitizeGridCoordinate(unlockedPlotTile.row)
		local column = sanitizeGridCoordinate(unlockedPlotTile.column)
		if PlotExpansionConfig.isValidTileCoordinate(row, column) then
			local tileKey = PlotExpansionUtils.getTileKey(row, column)
			if seenTileKeys[tileKey] ~= true then
				seenTileKeys[tileKey] = true
				table.insert(clone, {
					row = row,
					column = column,
				})
			end
		end
	end

	local starterTile = PlotExpansionConfig.getStarterTile()
	local starterTileKey = PlotExpansionUtils.getTileKey(starterTile.row, starterTile.column)
	if seenTileKeys[starterTileKey] ~= true then
		table.insert(clone, {
			row = starterTile.row,
			column = starterTile.column,
		})
	end

	table.sort(clone, function(leftTile, rightTile)
		if leftTile.row == rightTile.row then
			return leftTile.column < rightTile.column
		end

		return leftTile.row < rightTile.row
	end)

	return clone
end

local function arePlacedBuildingsEqual(leftBuildings: { PlacedBuildingData }, rightBuildings: { PlacedBuildingData }): boolean
	if #leftBuildings ~= #rightBuildings then
		return false
	end

	for index, leftBuilding in ipairs(leftBuildings) do
		local rightBuilding = rightBuildings[index]
		if rightBuilding == nil
			or leftBuilding.buildingId ~= rightBuilding.buildingId
			or sanitizeGridCoordinate(leftBuilding.gridX) ~= sanitizeGridCoordinate(rightBuilding.gridX)
			or sanitizeGridCoordinate(leftBuilding.gridZ) ~= sanitizeGridCoordinate(rightBuilding.gridZ)
			or sanitizePlacementRotationQuarterTurns(leftBuilding.rotationQuarterTurns) ~= sanitizePlacementRotationQuarterTurns(rightBuilding.rotationQuarterTurns)
			or not areSavedProductionStatesEqual(leftBuilding.production, rightBuilding.production)
		then
			return false
		end
	end

	return true
end

local function areUnlockedPlotTilesEqual(leftTiles: { UnlockedPlotTileData }, rightTiles: { UnlockedPlotTileData }): boolean
	if #leftTiles ~= #rightTiles then
		return false
	end

	for index, leftTile in ipairs(leftTiles) do
		local rightTile = rightTiles[index]
		if rightTile == nil
			or sanitizeGridCoordinate(leftTile.row) ~= sanitizeGridCoordinate(rightTile.row)
			or sanitizeGridCoordinate(leftTile.column) ~= sanitizeGridCoordinate(rightTile.column)
		then
			return false
		end
	end

	return true
end

local function cloneInventoryData(inventory: PlayerInventoryData): PlayerInventoryData
	local entries: { InventoryEntry } = table.create(#inventory.entries)
	for _, entry in ipairs(inventory.entries) do
		local quantity = sanitizeAmount(entry.quantity)
		if ItemCatalog.hasItemDefinition(entry.itemId) and quantity > 0 then
			table.insert(entries, {
				itemId = entry.itemId,
				quantity = quantity,
			})
		end
	end

	local hotbarSlots: { HotbarSlotData } = {}
	for _, hotbarSlot in ipairs(inventory.hotbarSlots) do
		if HotbarConfig.isAssignableSlotIndex(hotbarSlot.slotIndex)
			and hotbarSlot.itemId ~= "Scythe"
			and ItemCatalog.hasItemDefinition(hotbarSlot.itemId)
		then
			table.insert(hotbarSlots, {
				slotIndex = sanitizeGridCoordinate(hotbarSlot.slotIndex),
				itemId = hotbarSlot.itemId,
			})
		end
	end

	return {
		entries = entries,
		hotbarSlots = hotbarSlots,
		selectedSlotIndex = sanitizeSelectedSlotIndex(inventory.selectedSlotIndex),
	}
end

local function cloneOfflineData(offline: PlayerOfflineData): PlayerOfflineData
	return {
		lastSeenAt = sanitizeTimestamp(offline.lastSeenAt),
		pendingCider = sanitizeAmount(offline.pendingCider),
		ciderPerSecondSnapshot = sanitizeRate(offline.ciderPerSecondSnapshot),
	}
end

local function clonePlaytimeRewardsData(playtimeRewards: PlayerPlaytimeRewardsData): PlayerPlaytimeRewardsData
	local claimedRewardIndexes: { [number]: boolean } = {}
	for rewardIndex, isClaimed in pairs(playtimeRewards.claimedRewardIndexes) do
		local sanitizedRewardIndex = sanitizeAmount(rewardIndex)
		if isClaimed and sanitizedRewardIndex >= 1 and sanitizedRewardIndex <= PLAYTIME_REWARDS_CYCLE_LENGTH then
			claimedRewardIndexes[sanitizedRewardIndex] = true
		end
	end

	return {
		accumulatedPlaytimeSeconds = sanitizeDuration(playtimeRewards.accumulatedPlaytimeSeconds),
		claimedRewardIndexes = claimedRewardIndexes,
		totalClaims = sanitizeAmount(playtimeRewards.totalClaims),
	}
end

local function cloneDailyRewardsData(dailyRewards: PlayerDailyRewardsData): PlayerDailyRewardsData
	local claimedRewardIndexes: { [number]: boolean } = {}
	for rewardIndex, isClaimed in pairs(dailyRewards.claimedRewardIndexes) do
		local sanitizedRewardIndex = sanitizeAmount(rewardIndex)
		if isClaimed and sanitizedRewardIndex >= 1 and sanitizedRewardIndex <= DAILY_REWARDS_CYCLE_LENGTH then
			claimedRewardIndexes[sanitizedRewardIndex] = true
		end
	end

	local nextRewardIndex = sanitizeAmount(dailyRewards.nextRewardIndex)
	if nextRewardIndex < 1 or nextRewardIndex > DAILY_REWARDS_CYCLE_LENGTH then
		nextRewardIndex = 1
	end

	return {
		claimedRewardIndexes = claimedRewardIndexes,
		lastClaimUnixTime = sanitizeDuration(dailyRewards.lastClaimUnixTime),
		nextRewardIndex = nextRewardIndex,
		totalClaims = sanitizeAmount(dailyRewards.totalClaims),
	}
end

local function arePlaytimeRewardsDataEqual(leftPlaytimeRewards: PlayerPlaytimeRewardsData, rightPlaytimeRewards: PlayerPlaytimeRewardsData): boolean
	if sanitizeDuration(leftPlaytimeRewards.accumulatedPlaytimeSeconds) ~= sanitizeDuration(rightPlaytimeRewards.accumulatedPlaytimeSeconds)
		or sanitizeAmount(leftPlaytimeRewards.totalClaims) ~= sanitizeAmount(rightPlaytimeRewards.totalClaims)
	then
		return false
	end

	for rewardIndex = 1, PLAYTIME_REWARDS_CYCLE_LENGTH do
		local leftIsClaimed = leftPlaytimeRewards.claimedRewardIndexes[rewardIndex] == true
		local rightIsClaimed = rightPlaytimeRewards.claimedRewardIndexes[rewardIndex] == true
		if leftIsClaimed ~= rightIsClaimed then
			return false
		end
	end

	return true
end

local function areDailyRewardsDataEqual(leftDailyRewards: PlayerDailyRewardsData, rightDailyRewards: PlayerDailyRewardsData): boolean
	if sanitizeDuration(leftDailyRewards.lastClaimUnixTime) ~= sanitizeDuration(rightDailyRewards.lastClaimUnixTime)
		or sanitizeAmount(leftDailyRewards.nextRewardIndex) ~= sanitizeAmount(rightDailyRewards.nextRewardIndex)
		or sanitizeAmount(leftDailyRewards.totalClaims) ~= sanitizeAmount(rightDailyRewards.totalClaims)
	then
		return false
	end

	for rewardIndex = 1, DAILY_REWARDS_CYCLE_LENGTH do
		local leftIsClaimed = leftDailyRewards.claimedRewardIndexes[rewardIndex] == true
		local rightIsClaimed = rightDailyRewards.claimedRewardIndexes[rewardIndex] == true
		if leftIsClaimed ~= rightIsClaimed then
			return false
		end
	end

	return true
end

local function areInventoryDataEqual(leftInventory: PlayerInventoryData?, rightInventory: PlayerInventoryData): boolean
	if leftInventory == nil then
		return false
	end

	if #leftInventory.entries ~= #rightInventory.entries or #leftInventory.hotbarSlots ~= #rightInventory.hotbarSlots then
		return false
	end

	for index, leftEntry in ipairs(leftInventory.entries) do
		local rightEntry = rightInventory.entries[index]
		if rightEntry == nil
			or leftEntry.itemId ~= rightEntry.itemId
			or sanitizeAmount(leftEntry.quantity) ~= sanitizeAmount(rightEntry.quantity)
		then
			return false
		end
	end

	for index, leftHotbarSlot in ipairs(leftInventory.hotbarSlots) do
		local rightHotbarSlot = rightInventory.hotbarSlots[index]
		if rightHotbarSlot == nil
			or sanitizeGridCoordinate(leftHotbarSlot.slotIndex) ~= sanitizeGridCoordinate(rightHotbarSlot.slotIndex)
			or leftHotbarSlot.itemId ~= rightHotbarSlot.itemId
		then
			return false
		end
	end

	return sanitizeSelectedSlotIndex(leftInventory.selectedSlotIndex) == sanitizeSelectedSlotIndex(rightInventory.selectedSlotIndex)
end

local function runBeforeSaveListeners(player: Player)
	for _, listener in ipairs(beforeSaveListeners) do
		local success, result = pcall(function()
			listener(player)
		end)

		if not success then
			warn(string.format("Before-save listener failed for %s: %s", player.Name, tostring(result)))
		end
	end
end

local function runAfterRemoveListeners(player: Player)
	for _, listener in ipairs(afterRemoveListeners) do
		local success, result = pcall(function()
			listener(player)
		end)

		if not success then
			warn(string.format("After-remove listener failed for %s: %s", player.Name, tostring(result)))
		end
	end
end

local function markDirty(record: PlayerDataRecord)
	record.isDirty = true
	record.revision += 1
end

local function loadPlayerData(player: Player): PlayerDataRecord
	local existingRecord = playerDataRecords[player]
	if existingRecord ~= nil then
		return existingRecord
	end

	while loadingPlayers[player] == true do
		task.wait()

		local loadedRecord = playerDataRecords[player]
		if loadedRecord ~= nil then
			return loadedRecord
		end
	end

	loadingPlayers[player] = true
	local result = PlayerDataStore.loadAsync(player.UserId)
	local record: PlayerDataRecord = {
		data = result.data,
		canSave = result.didLoad,
		isDirty = false,
		isSaving = false,
		revision = 0,
	}

	playerDataRecords[player] = record
	loadingPlayers[player] = nil

	if not result.didLoad then
		warn(string.format("Using temporary unsaved data for %s because their profile failed to load.", player.Name))
	end

	return record
end

local function savePlayerData(player: Player, forceSave: boolean): boolean
	local record = playerDataRecords[player]
	if record == nil or not record.canSave then
		return false
	end

	while record.isSaving do
		task.wait()
	end

	runBeforeSaveListeners(player)

	if not forceSave and not record.isDirty then
		return true
	end

	local savedRevision = record.revision
	record.isSaving = true
	local didSave = PlayerDataStore.saveAsync(player.UserId, record.data)
	record.isSaving = false

	if didSave and record.revision == savedRevision then
		record.isDirty = false
	end

	return didSave
end

local function removePlayerData(player: Player)
	while loadingPlayers[player] == true do
		task.wait()
	end

	savePlayerData(player, true)
	runAfterRemoveListeners(player)
	playerDataRecords[player] = nil
	loadingPlayers[player] = nil
end

local function startAutosaveLoop()
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL_SECONDS)

			for player in pairs(playerDataRecords) do
				savePlayerData(player, false)
			end
		end
	end)
end

local PlayerDataService = {}

function PlayerDataService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	Players.PlayerAdded:Connect(function(player: Player)
		loadPlayerData(player)
	end)

	Players.PlayerRemoving:Connect(removePlayerData)

	game:BindToClose(function()
		for player in pairs(playerDataRecords) do
			savePlayerData(player, true)
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		loadPlayerData(player)
	end

	startAutosaveLoop()
end

function PlayerDataService.waitForData(player: Player): PlayerData
	return loadPlayerData(player).data
end

function PlayerDataService.getCash(player: Player): number
	local record = loadPlayerData(player)
	return record.data.economy.cash
end

function PlayerDataService.getLifetimeCashEarned(player: Player): number
	local record = loadPlayerData(player)
	return sanitizeAmount(record.data.economy.lifetimeCashEarned)
end

function PlayerDataService.setCash(player: Player, cash: number)
	local record = loadPlayerData(player)
	record.data.economy.cash = sanitizeAmount(cash)
	markDirty(record)
end

function PlayerDataService.addLifetimeCashEarned(player: Player, amount: number)
	local sanitizedAmount = sanitizeAmount(amount)
	if sanitizedAmount <= 0 then
		return
	end

	local record = loadPlayerData(player)
	record.data.economy.lifetimeCashEarned = sanitizeAmount(record.data.economy.lifetimeCashEarned + sanitizedAmount)
	markDirty(record)
end

function PlayerDataService.getResourceAmount(player: Player, resourceId: ResourceId): number
	local record = loadPlayerData(player)
	return record.data.resources[resourceId] or 0
end

function PlayerDataService.setResourceAmount(player: Player, resourceId: ResourceId, amount: number)
	local record = loadPlayerData(player)
	record.data.resources[resourceId] = sanitizeAmount(amount)
	markDirty(record)
end

function PlayerDataService.getResourceAmounts(player: Player): { [ResourceId]: number }
	local record = loadPlayerData(player)
	local amountsByResourceId: { [ResourceId]: number } = {}

	for resourceId, amount in pairs(record.data.resources) do
		amountsByResourceId[resourceId] = amount
	end

	return amountsByResourceId
end

function PlayerDataService.getSettings(player: Player): SettingsValues
	local record = loadPlayerData(player)
	return SettingsConfig.sanitizeValues(record.data.settings)
end

function PlayerDataService.setSettingValue(player: Player, settingId: SettingId, value: number)
	local record = loadPlayerData(player)
	local sanitizedValue = SettingsConfig.sanitizeSettingValue(settingId, value)
	if record.data.settings[settingId] == sanitizedValue then
		return
	end

	record.data.settings[settingId] = sanitizedValue
	markDirty(record)
end

function PlayerDataService.getOfflineData(player: Player): PlayerOfflineData
	local record = loadPlayerData(player)
	return cloneOfflineData(record.data.offline)
end

function PlayerDataService.setOfflineLastSeenAt(player: Player, lastSeenAt: number)
	local record = loadPlayerData(player)
	local sanitizedLastSeenAt = sanitizeTimestamp(lastSeenAt)
	if record.data.offline.lastSeenAt == sanitizedLastSeenAt then
		return
	end

	record.data.offline.lastSeenAt = sanitizedLastSeenAt
	markDirty(record)
end

function PlayerDataService.setOfflineCiderPerSecondSnapshot(player: Player, ciderPerSecondSnapshot: number)
	local record = loadPlayerData(player)
	local sanitizedSnapshot = sanitizeRate(ciderPerSecondSnapshot)
	if record.data.offline.ciderPerSecondSnapshot == sanitizedSnapshot then
		return
	end

	record.data.offline.ciderPerSecondSnapshot = sanitizedSnapshot
	markDirty(record)
end

function PlayerDataService.getPendingOfflineCider(player: Player): number
	local record = loadPlayerData(player)
	return sanitizeAmount(record.data.offline.pendingCider)
end

function PlayerDataService.setPendingOfflineCider(player: Player, pendingCider: number)
	local record = loadPlayerData(player)
	local sanitizedPendingCider = sanitizeAmount(pendingCider)
	if record.data.offline.pendingCider == sanitizedPendingCider then
		return
	end

	record.data.offline.pendingCider = sanitizedPendingCider
	markDirty(record)
end

function PlayerDataService.addPendingOfflineCider(player: Player, amount: number)
	local sanitizedAmount = sanitizeAmount(amount)
	if sanitizedAmount <= 0 then
		return
	end

	local record = loadPlayerData(player)
	record.data.offline.pendingCider = sanitizeAmount(record.data.offline.pendingCider + sanitizedAmount)
	markDirty(record)
end

function PlayerDataService.claimPendingOfflineCider(player: Player): number
	local record = loadPlayerData(player)
	local pendingCider = sanitizeAmount(record.data.offline.pendingCider)
	if pendingCider <= 0 then
		return 0
	end

	record.data.offline.pendingCider = 0
	markDirty(record)
	return pendingCider
end

function PlayerDataService.getPlacedBuildings(player: Player): { PlacedBuildingData }
	local record = loadPlayerData(player)
	return clonePlacedBuildings(record.data.placedBuildings)
end

function PlayerDataService.addPlacedBuilding(player: Player, buildingId: BuildingId, gridX: number, gridZ: number, rotationQuarterTurns: number)
	local record = loadPlayerData(player)
	table.insert(record.data.placedBuildings, {
		buildingId = buildingId,
		gridX = sanitizeGridCoordinate(gridX),
		gridZ = sanitizeGridCoordinate(gridZ),
		rotationQuarterTurns = sanitizePlacementRotationQuarterTurns(rotationQuarterTurns),
		production = nil,
	})
	markDirty(record)
end

function PlayerDataService.setPlacedBuildings(player: Player, placedBuildings: { PlacedBuildingData })
	local record = loadPlayerData(player)
	local sanitizedPlacedBuildings = clonePlacedBuildings(placedBuildings)
	if arePlacedBuildingsEqual(record.data.placedBuildings, sanitizedPlacedBuildings) then
		return
	end

	record.data.placedBuildings = sanitizedPlacedBuildings
	markDirty(record)
end

function PlayerDataService.getUnlockedPlotTiles(player: Player): { UnlockedPlotTileData }
	local record = loadPlayerData(player)
	return cloneUnlockedPlotTiles(record.data.unlockedPlotTiles)
end

function PlayerDataService.setUnlockedPlotTiles(player: Player, unlockedPlotTiles: { UnlockedPlotTileData })
	local record = loadPlayerData(player)
	local sanitizedUnlockedPlotTiles = cloneUnlockedPlotTiles(unlockedPlotTiles)
	if areUnlockedPlotTilesEqual(record.data.unlockedPlotTiles, sanitizedUnlockedPlotTiles) then
		return
	end

	record.data.unlockedPlotTiles = sanitizedUnlockedPlotTiles
	markDirty(record)
end

function PlayerDataService.unlockPlotTile(player: Player, row: number, column: number)
	if not PlotExpansionConfig.isValidTileCoordinate(row, column) then
		return
	end

	local record = loadPlayerData(player)
	for _, unlockedPlotTile in ipairs(record.data.unlockedPlotTiles) do
		if unlockedPlotTile.row == row and unlockedPlotTile.column == column then
			return
		end
	end

	table.insert(record.data.unlockedPlotTiles, {
		row = row,
		column = column,
	})
	record.data.unlockedPlotTiles = cloneUnlockedPlotTiles(record.data.unlockedPlotTiles)
	markDirty(record)
end

function PlayerDataService.getInventory(player: Player): PlayerInventoryData?
	local record = loadPlayerData(player)
	if record.data.inventory == nil then
		return nil
	end

	return cloneInventoryData(record.data.inventory)
end

function PlayerDataService.setInventory(player: Player, inventory: PlayerInventoryData)
	local record = loadPlayerData(player)
	local clonedInventory = cloneInventoryData(inventory)
	if areInventoryDataEqual(record.data.inventory, clonedInventory) then
		return
	end

	record.data.inventory = clonedInventory
	markDirty(record)
end

function PlayerDataService.getPlaytimeRewardsData(player: Player): PlayerPlaytimeRewardsData
	local record = loadPlayerData(player)
	return clonePlaytimeRewardsData(record.data.playtimeRewards)
end

function PlayerDataService.setPlaytimeRewardsData(player: Player, playtimeRewardsData: PlayerPlaytimeRewardsData)
	local record = loadPlayerData(player)
	local clonedPlaytimeRewardsData = clonePlaytimeRewardsData(playtimeRewardsData)
	if arePlaytimeRewardsDataEqual(record.data.playtimeRewards, clonedPlaytimeRewardsData) then
		return
	end

	record.data.playtimeRewards = clonedPlaytimeRewardsData
	markDirty(record)
end

function PlayerDataService.getDailyRewardsData(player: Player): PlayerDailyRewardsData
	local record = loadPlayerData(player)
	return cloneDailyRewardsData(record.data.dailyRewards)
end

function PlayerDataService.setDailyRewardsData(player: Player, dailyRewardsData: PlayerDailyRewardsData)
	local record = loadPlayerData(player)
	local clonedDailyRewardsData = cloneDailyRewardsData(dailyRewardsData)
	if areDailyRewardsDataEqual(record.data.dailyRewards, clonedDailyRewardsData) then
		return
	end

	record.data.dailyRewards = clonedDailyRewardsData
	markDirty(record)
end

function PlayerDataService.getTutorialData(player: Player): PlayerTutorialData
	local record = loadPlayerData(player)
	return {
		stepIndex = record.data.tutorial.stepIndex,
		completed = record.data.tutorial.completed,
	}
end

function PlayerDataService.setTutorialStep(player: Player, stepIndex: number)
	local record = loadPlayerData(player)
	local sanitizedStepIndex = if stepIndex > 0 and stepIndex == math.floor(stepIndex) then stepIndex else 1
	if record.data.tutorial.stepIndex == sanitizedStepIndex and not record.data.tutorial.completed then
		return
	end

	record.data.tutorial = {
		stepIndex = sanitizedStepIndex,
		completed = false,
	}
	markDirty(record)
end

function PlayerDataService.completeTutorial(player: Player)
	local record = loadPlayerData(player)
	if record.data.tutorial.completed then
		return
	end

	record.data.tutorial = {
		stepIndex = record.data.tutorial.stepIndex,
		completed = true,
	}
	markDirty(record)
end

function PlayerDataService.observeBeforeSave(listener: BeforeSaveListener)
	table.insert(beforeSaveListeners, listener)
end

function PlayerDataService.observeAfterRemove(listener: AfterRemoveListener)
	table.insert(afterRemoveListeners, listener)
end

function PlayerDataService.saveNow(player: Player): boolean
	return savePlayerData(player, true)
end

return table.freeze(PlayerDataService)

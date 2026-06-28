--!strict

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local limitedItemsFolder = sharedFolder:WaitForChild("LimitedItems") :: Folder

local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local LimitedItemCatalog = require(limitedItemsFolder:WaitForChild("LimitedItemCatalog") :: ModuleScript)
local LimitedItemTypes = require(limitedItemsFolder:WaitForChild("LimitedItemTypes") :: ModuleScript)

type ItemId = InventoryTypes.ItemId
type LimitedItemDefinition = LimitedItemTypes.LimitedItemDefinition
type LimitedItemsSnapshot = LimitedItemTypes.LimitedItemsSnapshot

type ReservationRecord = {
	userId: number,
	expiresAtUnix: number,
}

type PurchaseRecord = {
	userId: number,
	purchasedAtUnix: number,
}

type StockRecord = {
	schemaVersion: number,
	maxStock: number,
	soldCount: number,
	reservationsByUserId: { [string]: ReservationRecord },
	purchasesByPurchaseId: { [string]: PurchaseRecord },
}

export type ReserveStockStatus = "Reserved" | "InvalidItem" | "Unavailable" | "SoldOut" | "DataStoreError"
export type ClaimPurchaseStatus = "Claimed" | "AlreadyClaimed" | "InvalidItem" | "SoldOut" | "PurchaseIdConflict" | "DataStoreError"

export type ReserveStockResult = {
	success: boolean,
	status: ReserveStockStatus,
	stockRemaining: number,
}

export type ClaimPurchaseResult = {
	success: boolean,
	status: ClaimPurchaseStatus,
	stockRemaining: number,
}

local DATA_STORE_NAME = "FarmingEmpire_LimitedItemStock_PROD"
local CURRENT_SCHEMA_VERSION = 1
local MAX_ATTEMPTS = 3
local RETRY_DELAY_SECONDS = 1
local SNAPSHOT_CACHE_SECONDS = 10

local dataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)
local cachedSnapshot: LimitedItemsSnapshot? = nil
local cachedSnapshotExpiresAtUnix = 0

local function sanitizeAmount(value: unknown): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge or value < 0 then
		return 0
	end

	return math.floor(value)
end

local function sanitizeReservationRecord(rawReservation: unknown): ReservationRecord?
	if type(rawReservation) ~= "table" then
		return nil
	end

	local values = rawReservation :: { [string]: unknown }
	local rawUserId = values.userId
	local rawExpiresAtUnix = values.expiresAtUnix
	if type(rawUserId) ~= "number" or rawUserId ~= math.floor(rawUserId) or rawUserId <= 0 then
		return nil
	end

	return {
		userId = rawUserId,
		expiresAtUnix = sanitizeAmount(rawExpiresAtUnix),
	}
end

local function sanitizePurchaseRecord(rawPurchase: unknown): PurchaseRecord?
	if type(rawPurchase) ~= "table" then
		return nil
	end

	local values = rawPurchase :: { [string]: unknown }
	local rawUserId = values.userId
	if type(rawUserId) ~= "number" or rawUserId ~= math.floor(rawUserId) or rawUserId <= 0 then
		return nil
	end

	return {
		userId = rawUserId,
		purchasedAtUnix = sanitizeAmount(values.purchasedAtUnix),
	}
end

local function sanitizeStockRecord(rawRecord: unknown, definition: LimitedItemDefinition): StockRecord
	local rawValues: { [string]: unknown } = {}
	if type(rawRecord) == "table" then
		rawValues = rawRecord :: { [string]: unknown }
	end

	local reservationsByUserId: { [string]: ReservationRecord } = {}
	local rawReservations = rawValues.reservationsByUserId
	if type(rawReservations) == "table" then
		for rawUserIdKey, rawReservation in pairs(rawReservations :: { [string]: unknown }) do
			if type(rawUserIdKey) == "string" then
				local reservation = sanitizeReservationRecord(rawReservation)
				if reservation ~= nil then
					reservationsByUserId[rawUserIdKey] = reservation
				end
			end
		end
	end

	local purchasesByPurchaseId: { [string]: PurchaseRecord } = {}
	local rawPurchases = rawValues.purchasesByPurchaseId
	if type(rawPurchases) == "table" then
		for rawPurchaseId, rawPurchase in pairs(rawPurchases :: { [string]: unknown }) do
			if type(rawPurchaseId) == "string" and rawPurchaseId ~= "" then
				local purchase = sanitizePurchaseRecord(rawPurchase)
				if purchase ~= nil then
					purchasesByPurchaseId[rawPurchaseId] = purchase
				end
			end
		end
	end

	return {
		schemaVersion = CURRENT_SCHEMA_VERSION,
		maxStock = math.max(0, math.floor(definition.maxStock)),
		soldCount = math.min(sanitizeAmount(rawValues.soldCount), math.max(0, math.floor(definition.maxStock))),
		reservationsByUserId = reservationsByUserId,
		purchasesByPurchaseId = purchasesByPurchaseId,
	}
end

local function removeExpiredReservations(record: StockRecord, currentUnixTime: number)
	for userIdKey, reservation in pairs(record.reservationsByUserId) do
		if reservation.expiresAtUnix <= currentUnixTime then
			record.reservationsByUserId[userIdKey] = nil
		end
	end
end

local function countReservations(record: StockRecord): number
	local count = 0
	for _ in pairs(record.reservationsByUserId) do
		count += 1
	end

	return count
end

local function getStockRemaining(record: StockRecord): number
	return math.max(0, record.maxStock - record.soldCount - countReservations(record))
end

local function waitBeforeRetry(attempt: number)
	if attempt < MAX_ATTEMPTS then
		task.wait(RETRY_DELAY_SECONDS * attempt)
	end
end

local function cloneSnapshot(snapshot: LimitedItemsSnapshot): LimitedItemsSnapshot
	local stockRemainingByItemId: { [ItemId]: number } = {}
	for itemId, stockRemaining in pairs(snapshot.stockRemainingByItemId) do
		stockRemainingByItemId[itemId] = stockRemaining
	end

	local maxStockByItemId: { [ItemId]: number } = {}
	for itemId, maxStock in pairs(snapshot.maxStockByItemId) do
		maxStockByItemId[itemId] = maxStock
	end

	return {
		stockRemainingByItemId = stockRemainingByItemId,
		maxStockByItemId = maxStockByItemId,
	}
end

local function invalidateSnapshotCache()
	cachedSnapshot = nil
	cachedSnapshotExpiresAtUnix = 0
end

local function updateStockRecord(
	definition: LimitedItemDefinition,
	transform: (StockRecord) -> StockRecord
): (boolean, StockRecord?)
	for attempt = 1, MAX_ATTEMPTS do
		local updatedRecord: StockRecord? = nil
		local success, result = pcall(function()
			return dataStore:UpdateAsync(definition.stockKey, function(rawRecord: unknown): StockRecord
				local record = sanitizeStockRecord(rawRecord, definition)
				updatedRecord = transform(record)
				return updatedRecord :: StockRecord
			end)
		end)

		if success then
			if type(result) == "table" then
				return true, sanitizeStockRecord(result, definition)
			end

			return true, updatedRecord
		end

		warn(string.format(
			"[LimitedItemStockService] Failed to update %s stock on attempt %d: %s",
			definition.itemId,
			attempt,
			tostring(result)
		))
		waitBeforeRetry(attempt)
	end

	return false, nil
end

local function getDefinition(itemId: ItemId): LimitedItemDefinition?
	if not LimitedItemCatalog.isLimitedSaleItemId(itemId) then
		return nil
	end

	return LimitedItemCatalog.getDefinition(itemId)
end

local LimitedItemStockService = {}

function LimitedItemStockService.getSnapshot(forceRefresh: boolean?): LimitedItemsSnapshot
	local now = os.time()
	if forceRefresh ~= true and cachedSnapshot ~= nil and now < cachedSnapshotExpiresAtUnix then
		return cloneSnapshot(cachedSnapshot)
	end

	local stockRemainingByItemId: { [ItemId]: number } = {}
	local maxStockByItemId: { [ItemId]: number } = {}
	local currentUnixTime = now

	for _, definition in ipairs(LimitedItemCatalog.getDefinitions()) do
		maxStockByItemId[definition.itemId] = definition.maxStock
		local success, record = updateStockRecord(definition, function(stockRecord: StockRecord): StockRecord
			removeExpiredReservations(stockRecord, currentUnixTime)
			return stockRecord
		end)

		stockRemainingByItemId[definition.itemId] = if success and record ~= nil then getStockRemaining(record) else 0
	end

	local snapshot: LimitedItemsSnapshot = {
		stockRemainingByItemId = stockRemainingByItemId,
		maxStockByItemId = maxStockByItemId,
	}
	cachedSnapshot = cloneSnapshot(snapshot)
	cachedSnapshotExpiresAtUnix = now + SNAPSHOT_CACHE_SECONDS
	return snapshot
end

function LimitedItemStockService.reserveStock(player: Player, itemId: ItemId): ReserveStockResult
	local definition = getDefinition(itemId)
	if definition == nil then
		return {
			success = false,
			status = "InvalidItem",
			stockRemaining = 0,
		}
	end

	if not LimitedItemCatalog.isConfigured(definition) then
		return {
			success = false,
			status = "Unavailable",
			stockRemaining = 0,
		}
	end

	local currentUnixTime = os.time()
	local userIdKey = tostring(player.UserId)
	local nextExpiresAtUnix = currentUnixTime + math.max(1, math.floor(definition.reservationSeconds))
	local status: ReserveStockStatus = "DataStoreError"

	local success, record = updateStockRecord(definition, function(stockRecord: StockRecord): StockRecord
		removeExpiredReservations(stockRecord, currentUnixTime)

		local existingReservation = stockRecord.reservationsByUserId[userIdKey]
		if existingReservation ~= nil then
			existingReservation.expiresAtUnix = nextExpiresAtUnix
			existingReservation.userId = player.UserId
			status = "Reserved"
			return stockRecord
		end

		if getStockRemaining(stockRecord) <= 0 then
			status = "SoldOut"
			return stockRecord
		end

		stockRecord.reservationsByUserId[userIdKey] = {
			userId = player.UserId,
			expiresAtUnix = nextExpiresAtUnix,
		}
		status = "Reserved"
		return stockRecord
	end)

	if not success or record == nil then
		return {
			success = false,
			status = "DataStoreError",
			stockRemaining = 0,
		}
	end

	if status == "Reserved" then
		invalidateSnapshotCache()
	end

	return {
		success = status == "Reserved",
		status = status,
		stockRemaining = getStockRemaining(record),
	}
end

function LimitedItemStockService.releaseReservation(player: Player, itemId: ItemId): boolean
	local definition = getDefinition(itemId)
	if definition == nil then
		return false
	end

	local currentUnixTime = os.time()
	local userIdKey = tostring(player.UserId)
	local didRelease = false

	local success = updateStockRecord(definition, function(stockRecord: StockRecord): StockRecord
		removeExpiredReservations(stockRecord, currentUnixTime)
		if stockRecord.reservationsByUserId[userIdKey] ~= nil then
			stockRecord.reservationsByUserId[userIdKey] = nil
			didRelease = true
		end

		return stockRecord
	end)

	if success and didRelease then
		invalidateSnapshotCache()
	end

	return success and didRelease
end

function LimitedItemStockService.claimPurchase(player: Player, itemId: ItemId, purchaseId: string): ClaimPurchaseResult
	local definition = getDefinition(itemId)
	if definition == nil or purchaseId == "" then
		return {
			success = false,
			status = "InvalidItem",
			stockRemaining = 0,
		}
	end

	local currentUnixTime = os.time()
	local userIdKey = tostring(player.UserId)
	local status: ClaimPurchaseStatus = "DataStoreError"

	local success, record = updateStockRecord(definition, function(stockRecord: StockRecord): StockRecord
		local existingPurchase = stockRecord.purchasesByPurchaseId[purchaseId]
		if existingPurchase ~= nil then
			status = if existingPurchase.userId == player.UserId then "AlreadyClaimed" else "PurchaseIdConflict"
			return stockRecord
		end

		if stockRecord.reservationsByUserId[userIdKey] ~= nil then
			stockRecord.reservationsByUserId[userIdKey] = nil
			stockRecord.soldCount += 1
			stockRecord.purchasesByPurchaseId[purchaseId] = {
				userId = player.UserId,
				purchasedAtUnix = currentUnixTime,
			}
			status = "Claimed"
			return stockRecord
		end

		removeExpiredReservations(stockRecord, currentUnixTime)
		if getStockRemaining(stockRecord) <= 0 then
			status = "SoldOut"
			return stockRecord
		end

		stockRecord.soldCount += 1
		stockRecord.purchasesByPurchaseId[purchaseId] = {
			userId = player.UserId,
			purchasedAtUnix = currentUnixTime,
		}
		status = "Claimed"
		return stockRecord
	end)

	if not success or record == nil then
		return {
			success = false,
			status = "DataStoreError",
			stockRemaining = 0,
		}
	end

	if status == "Claimed" or status == "AlreadyClaimed" then
		invalidateSnapshotCache()
	end

	return {
		success = status == "Claimed" or status == "AlreadyClaimed",
		status = status,
		stockRemaining = getStockRemaining(record),
	}
end

return table.freeze(LimitedItemStockService)

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local limitedItemsFolder = sharedFolder:WaitForChild("LimitedItems") :: Folder

local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local LimitedItemCatalog = require(limitedItemsFolder:WaitForChild("LimitedItemCatalog") :: ModuleScript)
local LimitedItemTypes = require(limitedItemsFolder:WaitForChild("LimitedItemTypes") :: ModuleScript)
local Remotes = require(script.Parent.Parent.Networking.Remotes)
local LimitedItemStockService = require(script.Parent.LimitedItemStockService)

type ItemId = InventoryTypes.ItemId
type LimitedItemsSnapshot = LimitedItemTypes.LimitedItemsSnapshot
type LimitedItemReserveStatus = LimitedItemTypes.LimitedItemReserveStatus
type LimitedItemReserveResult = LimitedItemTypes.LimitedItemReserveResult

local hasStarted = false

local function buildReserveResult(
	success: boolean,
	status: LimitedItemReserveStatus,
	itemId: ItemId?,
	developerProductId: number?
): LimitedItemReserveResult
	return {
		success = success,
		status = status,
		itemId = itemId,
		developerProductId = developerProductId,
		snapshot = LimitedItemStockService.getSnapshot(),
	}
end

local function pushSnapshotToAll(snapshot: LimitedItemsSnapshot?)
	local remotes = Remotes.getLimitedItemRemotes()
	remotes.limitedItemsSnapshotUpdated:FireAllClients(snapshot or LimitedItemStockService.getSnapshot())
end

local function handleReserveRequest(player: Player, request: unknown): LimitedItemReserveResult
	if type(request) ~= "table" then
		return buildReserveResult(false, "InvalidItem", nil, nil)
	end

	local requestValues = request :: { [string]: unknown }
	local rawItemId = requestValues.itemId
	if type(rawItemId) ~= "string" or not LimitedItemCatalog.isLimitedSaleItemId(rawItemId) then
		return buildReserveResult(false, "InvalidItem", nil, nil)
	end

	local itemId = rawItemId :: ItemId
	local definition = LimitedItemCatalog.getDefinition(itemId)
	if not LimitedItemCatalog.isConfigured(definition) then
		return buildReserveResult(false, "Unavailable", itemId, nil)
	end

	local stockResult = LimitedItemStockService.reserveStock(player, itemId)
	local snapshot = LimitedItemStockService.getSnapshot(true)
	if stockResult.success then
		pushSnapshotToAll(snapshot)
	end

	return {
		success = stockResult.success,
		status = stockResult.status,
		itemId = itemId,
		developerProductId = if stockResult.success then definition.developerProductId else nil,
		snapshot = snapshot,
	}
end

local function handleReleaseReservation(player: Player, rawItemId: unknown)
	if type(rawItemId) ~= "string" or not LimitedItemCatalog.isLimitedSaleItemId(rawItemId) then
		return
	end

	if LimitedItemStockService.releaseReservation(player, rawItemId :: ItemId) then
		pushSnapshotToAll(LimitedItemStockService.getSnapshot(true))
	end
end

local LimitedItemService = {}

function LimitedItemService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local remotes = Remotes.getLimitedItemRemotes()
	remotes.getLimitedItemsSnapshot.OnServerInvoke = function(_player: Player): LimitedItemsSnapshot
		return LimitedItemStockService.getSnapshot()
	end
	remotes.reserveLimitedItemPurchase.OnServerInvoke = handleReserveRequest
	remotes.releaseLimitedItemReservation.OnServerEvent:Connect(handleReleaseReservation)
end

function LimitedItemService.pushSnapshotToAll()
	pushSnapshotToAll(nil)
end

return table.freeze(LimitedItemService)

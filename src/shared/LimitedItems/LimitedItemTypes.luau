--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder

local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)

type ItemId = InventoryTypes.ItemId

export type LimitedItemDefinition = {
	itemId: ItemId,
	developerProductId: number,
	maxStock: number,
	stockKey: string,
	reservationSeconds: number,
}

export type LimitedItemsSnapshot = {
	stockRemainingByItemId: { [ItemId]: number },
	maxStockByItemId: { [ItemId]: number },
}

export type LimitedItemReserveStatus =
	"Reserved"
	| "InvalidItem"
	| "Unavailable"
	| "SoldOut"
	| "DataStoreError"

export type LimitedItemReserveRequest = {
	itemId: ItemId,
}

export type LimitedItemReserveResult = {
	success: boolean,
	status: LimitedItemReserveStatus,
	itemId: ItemId?,
	developerProductId: number?,
	snapshot: LimitedItemsSnapshot,
}

return {}

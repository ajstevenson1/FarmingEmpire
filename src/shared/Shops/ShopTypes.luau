--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder

local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)

type ItemId = InventoryTypes.ItemId

export type ShopId = "TreesShop" | "MillsShop"
export type ShopProductId = ItemId

export type ShopDefinition = {
	id: ShopId,
	displayName: string,
	worldModelName: string,
	touchPartName: string,
	restockGuiName: string,
	nameLabelName: string,
	timerLabelName: string,
	restockIntervalSeconds: number,
}

export type ShopProductDefinition = {
	id: ShopProductId,
	shopId: ShopId,
	itemId: ItemId,
	imageAssetId: string,
	developerProductId: string,
	price: number,
	quantityPerPurchase: number,
	stockPerRestock: number,
	sortOrder: number,
	description: string,
}

export type ShopRestockState = {
	nextRestockAt: number,
	stockRemainingByProductId: { [ShopProductId]: number },
}

export type ShopSnapshot = {
	shopsById: { [ShopId]: ShopRestockState },
}

export type ShopOpenedPayload = {
	shopId: ShopId,
	snapshot: ShopSnapshot,
	freeTutorialProductId: ShopProductId?,
}

export type ShopPurchaseStatus =
	"Purchased"
	| "InvalidShop"
	| "InvalidProduct"
	| "OutOfStock"
	| "InsufficientCash"
	| "TooFar"
	| "InvalidQuantity"

export type ShopPurchaseRequest = {
	shopId: ShopId,
	productId: ShopProductId,
}

export type ShopPurchaseResult = {
	success: boolean,
	status: ShopPurchaseStatus,
	shopId: ShopId?,
	productId: ShopProductId?,
	snapshot: ShopSnapshot,
}

return {}

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)

type ItemId = InventoryTypes.ItemId
type ResourceId = ResourceTypes.ResourceId

export type ShopId = "TreesShop" | "MillsShop" | "WindmillShop"
export type ShopProductId = ItemId
export type ShopPriceCurrency = "Cash" | ResourceId

export type ShopDefinition = {
	id: ShopId,
	displayName: string,
	worldModelName: string,
	touchPartName: string,
	restockGuiName: string,
	nameLabelName: string,
	timerLabelName: string,
	restockIntervalSeconds: number,
	usesStock: boolean,
}

export type ShopProductDefinition = {
	id: ShopProductId,
	shopId: ShopId,
	itemId: ItemId,
	imageAssetId: string,
	developerProductId: string,
	price: number,
	priceCurrency: ShopPriceCurrency,
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
	ownedProductIdsByShopId: { [ShopId]: { [ShopProductId]: boolean } },
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
	| "InsufficientResources"
	| "TooFar"
	| "InvalidQuantity"
	| "AlreadyOwned"

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

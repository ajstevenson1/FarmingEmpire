--!strict

local ShopTypes = require(script.Parent.ShopTypes)

type ShopDefinition = ShopTypes.ShopDefinition
type ShopId = ShopTypes.ShopId

local RESTOCK_INTERVAL_SECONDS = 5 * 60

local shopIds: { ShopId } = {
	"TreesShop",
	"MillsShop",
}

local definitionsById: { [ShopId]: ShopDefinition } = {
	TreesShop = table.freeze({
		id = "TreesShop",
		displayName = "Trees Shop",
		worldModelName = "TreesShop",
		touchPartName = "Touch",
		restockGuiName = "RestockGUI",
		nameLabelName = "NameLabel",
		timerLabelName = "TimerLabel",
		restockIntervalSeconds = RESTOCK_INTERVAL_SECONDS,
	}),
	MillsShop = table.freeze({
		id = "MillsShop",
		displayName = "Mills Shop",
		worldModelName = "MillsShop",
		touchPartName = "Touch",
		restockGuiName = "RestockGUI",
		nameLabelName = "NameLabel",
		timerLabelName = "TimerLabel",
		restockIntervalSeconds = RESTOCK_INTERVAL_SECONDS,
	}),
}

local ShopCatalog = {}

function ShopCatalog.getShopIds(): { ShopId }
	return table.clone(shopIds)
end

function ShopCatalog.getShopDefinition(shopId: ShopId): ShopDefinition
	return definitionsById[shopId]
end

function ShopCatalog.getAllShopDefinitions(): { [ShopId]: ShopDefinition }
	return definitionsById
end

function ShopCatalog.isShopId(value: string): boolean
	return definitionsById[value :: ShopId] ~= nil
end

return table.freeze(ShopCatalog)

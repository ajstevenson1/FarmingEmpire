--!strict

local ShopTypes = require(script.Parent.ShopTypes)
local progressionFolder = script.Parent.Parent:WaitForChild("Progression") :: Folder
local ProgressionConfig = require(progressionFolder:WaitForChild("ProgressionConfig") :: ModuleScript)

type ShopDefinition = ShopTypes.ShopDefinition
type ShopId = ShopTypes.ShopId
type ShopProductDefinition = ShopTypes.ShopProductDefinition
type ShopProductId = ShopTypes.ShopProductId
type MillTierDefinition = ProgressionConfig.MillTierDefinition
type TreeTierDefinition = ProgressionConfig.TreeTierDefinition

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

local productsByShopId: { [ShopId]: { ShopProductDefinition } } = {}

local treeProducts: { ShopProductDefinition } = {}
for index, treeDefinition: TreeTierDefinition in ipairs(ProgressionConfig.getTreeDefinitions()) do
	table.insert(treeProducts, table.freeze({
		id = treeDefinition.id,
		shopId = "TreesShop",
		itemId = treeDefinition.id,
		price = treeDefinition.price,
		unlockLifetimeCash = treeDefinition.unlockLifetimeCash,
		quantityPerPurchase = 1,
		stockPerRestock = treeDefinition.stockPerRestock,
		sortOrder = 10 + index - 1,
		description = treeDefinition.description,
	}))
end
productsByShopId.TreesShop = table.freeze(treeProducts)

local millProducts: { ShopProductDefinition } = {}
for index, millDefinition: MillTierDefinition in ipairs(ProgressionConfig.getMillDefinitions()) do
	table.insert(millProducts, table.freeze({
		id = millDefinition.id,
		shopId = "MillsShop",
		itemId = millDefinition.id,
		price = millDefinition.price,
		unlockLifetimeCash = millDefinition.unlockLifetimeCash,
		quantityPerPurchase = 1,
		stockPerRestock = millDefinition.stockPerRestock,
		sortOrder = 10 + index - 1,
		description = millDefinition.description,
	}))
end
productsByShopId.MillsShop = table.freeze(millProducts)

local productsByShopIdAndProductId: { [ShopId]: { [ShopProductId]: ShopProductDefinition } } = {}

for shopId, shopProducts in pairs(productsByShopId) do
	local productsById: { [ShopProductId]: ShopProductDefinition } = {}
	for _, productDefinition in ipairs(shopProducts) do
		productsById[productDefinition.id] = productDefinition
	end

	productsByShopIdAndProductId[shopId] = table.freeze(productsById)
end

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

function ShopCatalog.getShopProducts(shopId: ShopId): { ShopProductDefinition }
	local products = productsByShopId[shopId]
	if products == nil then
		return {}
	end

	return products
end

function ShopCatalog.getShopProductDefinition(shopId: ShopId, productId: ShopProductId): ShopProductDefinition?
	local productsById = productsByShopIdAndProductId[shopId]
	if productsById == nil then
		return nil
	end

	return productsById[productId]
end

function ShopCatalog.isShopId(value: string): boolean
	return definitionsById[value :: ShopId] ~= nil
end

return table.freeze(ShopCatalog)

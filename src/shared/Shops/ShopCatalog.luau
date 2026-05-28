--!strict

local ShopTypes = require(script.Parent.ShopTypes)
local progressionFolder = script.Parent.Parent:WaitForChild("Progression") :: Folder
local windmillsFolder = script.Parent.Parent:WaitForChild("Windmills") :: Folder
local ProgressionConfig = require(progressionFolder:WaitForChild("ProgressionConfig") :: ModuleScript)
local WindmillConfig = require(windmillsFolder:WaitForChild("WindmillConfig") :: ModuleScript)

type ShopDefinition = ShopTypes.ShopDefinition
type ShopId = ShopTypes.ShopId
type ShopProductDefinition = ShopTypes.ShopProductDefinition
type ShopProductId = ShopTypes.ShopProductId
type MillTierDefinition = ProgressionConfig.MillTierDefinition
type TreeTierDefinition = ProgressionConfig.TreeTierDefinition
type WindmillDefinition = WindmillConfig.WindmillDefinition

local RESTOCK_INTERVAL_SECONDS = 5 * 60
local TREE_IMAGE_ASSET_ID = "80078631350858"
local MILL_IMAGE_ASSET_ID = "120573464445068"
local WINDMILL_IMAGE_ASSET_ID = "120573464445068"
local EMPTY_DEVELOPER_PRODUCT_ID = ""

local shopIds: { ShopId } = {
	"TreesShop",
	"MillsShop",
	"WindmillShop",
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
	WindmillShop = table.freeze({
		id = "WindmillShop",
		displayName = "Windmill Shop",
		worldModelName = "WindmillShop",
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
		imageAssetId = TREE_IMAGE_ASSET_ID,
		developerProductId = EMPTY_DEVELOPER_PRODUCT_ID,
		price = treeDefinition.price,
		priceCurrency = "Cash",
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
		imageAssetId = MILL_IMAGE_ASSET_ID,
		developerProductId = EMPTY_DEVELOPER_PRODUCT_ID,
		price = millDefinition.price,
		priceCurrency = "Cash",
		quantityPerPurchase = 1,
		stockPerRestock = millDefinition.stockPerRestock,
		sortOrder = 10 + index - 1,
		description = millDefinition.description,
	}))
end
productsByShopId.MillsShop = table.freeze(millProducts)

local windmillProducts: { ShopProductDefinition } = {}
for index, windmillDefinition: WindmillDefinition in ipairs(WindmillConfig.getDefinitions()) do
	table.insert(windmillProducts, table.freeze({
		id = windmillDefinition.id,
		shopId = "WindmillShop",
		itemId = windmillDefinition.id,
		imageAssetId = WINDMILL_IMAGE_ASSET_ID,
		developerProductId = EMPTY_DEVELOPER_PRODUCT_ID,
		price = windmillDefinition.price,
		priceCurrency = "Apple",
		quantityPerPurchase = 1,
		stockPerRestock = windmillDefinition.stockPerRestock,
		sortOrder = 10 + index - 1,
		description = windmillDefinition.description,
	}))
end
productsByShopId.WindmillShop = table.freeze(windmillProducts)

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

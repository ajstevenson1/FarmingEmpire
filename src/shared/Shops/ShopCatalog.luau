--!strict

local ShopTypes = require(script.Parent.ShopTypes)

type ShopDefinition = ShopTypes.ShopDefinition
type ShopId = ShopTypes.ShopId
type ShopProductDefinition = ShopTypes.ShopProductDefinition
type ShopProductId = ShopTypes.ShopProductId

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

local productsByShopId: { [ShopId]: { ShopProductDefinition } } = {
	TreesShop = table.freeze({
		table.freeze({
			id = "BasicTree",
			shopId = "TreesShop",
			itemId = "BasicTree",
			price = 25,
			quantityPerPurchase = 1,
			stockPerRestock = 10,
			sortOrder = 10,
			description = "Steady starter tree. Produces 1 apple every 5 seconds.",
		}),
		table.freeze({
			id = "RubyAppleTree",
			shopId = "TreesShop",
			itemId = "RubyAppleTree",
			price = 150,
			quantityPerPurchase = 1,
			stockPerRestock = 5,
			sortOrder = 20,
			description = "Red-leaf variant. Produces 2 apples every 5 seconds.",
		}),
		table.freeze({
			id = "GoldenAppleTree",
			shopId = "TreesShop",
			itemId = "GoldenAppleTree",
			price = 650,
			quantityPerPurchase = 1,
			stockPerRestock = 3,
			sortOrder = 30,
			description = "High-yield orchard tree. Produces 4 apples every 5 seconds.",
		}),
		table.freeze({
			id = "CrystalAppleTree",
			shopId = "TreesShop",
			itemId = "CrystalAppleTree",
			price = 2500,
			quantityPerPurchase = 1,
			stockPerRestock = 1,
			sortOrder = 40,
			description = "Rare blue variant. Produces 7 apples every 5 seconds.",
		}),
	}),
	MillsShop = table.freeze({
		table.freeze({
			id = "CiderMill",
			shopId = "MillsShop",
			itemId = "CiderMill",
			price = 75,
			quantityPerPurchase = 1,
			stockPerRestock = 5,
			sortOrder = 10,
			description = "Basic mill. Turns 1 apple into 1 cider each second.",
		}),
		table.freeze({
			id = "CopperCiderMill",
			shopId = "MillsShop",
			itemId = "CopperCiderMill",
			price = 350,
			quantityPerPurchase = 1,
			stockPerRestock = 4,
			sortOrder = 20,
			description = "Copper fittings. Turns 1 apple into 2 cider each second.",
		}),
		table.freeze({
			id = "SteelCiderMill",
			shopId = "MillsShop",
			itemId = "SteelCiderMill",
			price = 1200,
			quantityPerPurchase = 1,
			stockPerRestock = 2,
			sortOrder = 30,
			description = "Reinforced press. Turns 2 apples into 5 cider each second.",
		}),
		table.freeze({
			id = "RoyalCiderMill",
			shopId = "MillsShop",
			itemId = "RoyalCiderMill",
			price = 4500,
			quantityPerPurchase = 1,
			stockPerRestock = 1,
			sortOrder = 40,
			description = "Top-tier press. Turns 3 apples into 10 cider each second.",
		}),
	}),
}

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

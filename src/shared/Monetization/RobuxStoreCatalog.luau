--!strict

local RobuxStoreTypes = require(script.Parent:WaitForChild("RobuxStoreTypes") :: ModuleScript)

type RobuxStoreCategoryId = RobuxStoreTypes.RobuxStoreCategoryId
type RobuxStoreProductDefinition = RobuxStoreTypes.RobuxStoreProductDefinition
type RobuxStoreProductId = RobuxStoreTypes.RobuxStoreProductId

local UNCONFIGURED_DEVELOPER_PRODUCT_ID = 0
local CASH_PACK_CATEGORY_ID: RobuxStoreCategoryId = "CashPacks"

local cashPackProductIds: { RobuxStoreProductId } = {
	"Cash25K",
	"Cash150K",
	"Cash800K",
	"Cash10M",
}

local definitionsById: { [RobuxStoreProductId]: RobuxStoreProductDefinition } = {
	Cash25K = table.freeze({
		id = "Cash25K",
		categoryId = CASH_PACK_CATEGORY_ID,
		displayName = "25K Cash",
		rewardType = "Cash",
		rewardAmount = 25000,
		developerProductId = 3605066300,
		sortOrder = 10,
		isBestValue = false,
	}),
	Cash150K = table.freeze({
		id = "Cash150K",
		categoryId = CASH_PACK_CATEGORY_ID,
		displayName = "150K Cash",
		rewardType = "Cash",
		rewardAmount = 150000,
		developerProductId = 3605066319,
		sortOrder = 20,
		isBestValue = false,
	}),
	Cash800K = table.freeze({
		id = "Cash800K",
		categoryId = CASH_PACK_CATEGORY_ID,
		displayName = "800K Cash",
		rewardType = "Cash",
		rewardAmount = 800000,
		developerProductId = 3605066353,
		sortOrder = 30,
		isBestValue = false,
	}),
	Cash10M = table.freeze({
		id = "Cash10M",
		categoryId = CASH_PACK_CATEGORY_ID,
		displayName = "10M Cash",
		rewardType = "Cash",
		rewardAmount = 10000000,
		developerProductId = 3605066383,
		sortOrder = 40,
		isBestValue = true,
	}),
}

local definitionsByDeveloperProductId: { [number]: RobuxStoreProductDefinition } = {}
for _, productId in ipairs(cashPackProductIds) do
	local definition = definitionsById[productId]
	if definition.developerProductId > 0 then
		definitionsByDeveloperProductId[definition.developerProductId] = definition
	end
end

local RobuxStoreCatalog = {}

function RobuxStoreCatalog.getCashPackProducts(): { RobuxStoreProductDefinition }
	local products: { RobuxStoreProductDefinition } = {}
	for _, productId in ipairs(cashPackProductIds) do
		table.insert(products, definitionsById[productId])
	end

	return products
end

function RobuxStoreCatalog.getProductDefinition(productId: RobuxStoreProductId): RobuxStoreProductDefinition?
	return definitionsById[productId]
end

function RobuxStoreCatalog.getProductDefinitionByDeveloperProductId(developerProductId: number): RobuxStoreProductDefinition?
	return definitionsByDeveloperProductId[developerProductId]
end

function RobuxStoreCatalog.isConfigured(definition: RobuxStoreProductDefinition): boolean
	return definition.developerProductId > 0
end

return table.freeze(RobuxStoreCatalog)

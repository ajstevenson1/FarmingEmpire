--!strict

local inventoryFolder = script.Parent.Parent:WaitForChild("Inventory") :: Folder

local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local LimitedItemTypes = require(script.Parent.LimitedItemTypes)

type ItemId = InventoryTypes.ItemId
type LimitedItemDefinition = LimitedItemTypes.LimitedItemDefinition

type LimitedSaleConfig = {
	itemId: ItemId,
	developerProductId: number,
	maxStock: number,
	stockKey: string,
	reservationSeconds: number,
}

local PATRIOT_TREE_DEVELOPER_PRODUCT_ID = 3606776534
local PATRIOT_TREE_STOCK_KEY = "PatriotTree_v1"
local PATRIOT_TREE_MAX_STOCK = 499
local PATRIOT_TREE_RESERVATION_SECONDS = 10 * 60

local saleConfigs: { LimitedSaleConfig } = table.freeze({
	{
		itemId = "PatriotTree",
		developerProductId = PATRIOT_TREE_DEVELOPER_PRODUCT_ID,
		maxStock = PATRIOT_TREE_MAX_STOCK,
		stockKey = PATRIOT_TREE_STOCK_KEY,
		reservationSeconds = PATRIOT_TREE_RESERVATION_SECONDS,
	},
})

local definitions: { LimitedItemDefinition } = {}
local definitionsByItemId: { [ItemId]: LimitedItemDefinition } = {}
local definitionsByDeveloperProductId: { [number]: LimitedItemDefinition } = {}

for _, saleConfig in ipairs(saleConfigs) do
	assert(
		ItemCatalog.hasItemDefinition(saleConfig.itemId),
		string.format("Limited sale item %s must exist in ItemCatalog", saleConfig.itemId)
	)

	local definition: LimitedItemDefinition = table.freeze({
		itemId = saleConfig.itemId,
		developerProductId = saleConfig.developerProductId,
		maxStock = saleConfig.maxStock,
		stockKey = saleConfig.stockKey,
		reservationSeconds = saleConfig.reservationSeconds,
	})

	table.insert(definitions, definition)
	definitionsByItemId[definition.itemId] = definition
	if definition.developerProductId > 0 then
		definitionsByDeveloperProductId[definition.developerProductId] = definition
	end
end
definitions = table.freeze(definitions)

local LimitedItemCatalog = {}

function LimitedItemCatalog.getDefinitions(): { LimitedItemDefinition }
	return definitions
end

function LimitedItemCatalog.getDefinition(itemId: ItemId): LimitedItemDefinition
	local definition = definitionsByItemId[itemId]
	assert(definition ~= nil, string.format("Unknown limited item id %s", itemId))
	return definition
end

function LimitedItemCatalog.getDefinitionByDeveloperProductId(developerProductId: number): LimitedItemDefinition?
	return definitionsByDeveloperProductId[developerProductId]
end

function LimitedItemCatalog.isLimitedSaleItemId(value: string): boolean
	return definitionsByItemId[value :: ItemId] ~= nil
end

function LimitedItemCatalog.isConfigured(definition: LimitedItemDefinition): boolean
	return definition.developerProductId > 0
end

return table.freeze(LimitedItemCatalog)

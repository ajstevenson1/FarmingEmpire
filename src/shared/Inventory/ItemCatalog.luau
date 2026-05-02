--!strict

local InventoryTypes = require(script.Parent.InventoryTypes)

type ItemDefinition = InventoryTypes.ItemDefinition
type ItemId = InventoryTypes.ItemId

local itemsById: { [ItemId]: ItemDefinition } = {
	Scythe = table.freeze({
		id = "Scythe",
		displayName = "Scythe",
		kind = "Tool",
		maxStack = 1,
		inventoryOrder = 0,
		toolAssetName = "Scythe",
	}),
	BasicTree = table.freeze({
		id = "BasicTree",
		displayName = "Apple Tree",
		kind = "Placeable",
		maxStack = 99,
		inventoryOrder = 10,
		toolAssetName = nil,
	}),
	CiderMill = table.freeze({
		id = "CiderMill",
		displayName = "Cider Mill",
		kind = "Placeable",
		maxStack = 99,
		inventoryOrder = 20,
		toolAssetName = nil,
	}),
}

local ItemCatalog = {}

function ItemCatalog.getItemDefinition(itemId: ItemId): ItemDefinition
	return itemsById[itemId]
end

function ItemCatalog.hasItemDefinition(itemId: string): boolean
	return itemsById[itemId :: ItemId] ~= nil
end

function ItemCatalog.getAllItemDefinitions(): { [ItemId]: ItemDefinition }
	return itemsById
end

return table.freeze(ItemCatalog)

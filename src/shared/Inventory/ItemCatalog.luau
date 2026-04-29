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
	}),
	WheatField = table.freeze({
		id = "WheatField",
		displayName = "Wheat Field",
		kind = "Placeable",
		maxStack = 99,
		inventoryOrder = 10,
	}),
	Wheat = table.freeze({
		id = "Wheat",
		displayName = "Wheat",
		kind = "Resource",
		maxStack = 999,
		inventoryOrder = 20,
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

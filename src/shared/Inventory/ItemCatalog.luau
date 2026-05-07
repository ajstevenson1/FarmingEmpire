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
	RubyAppleTree = table.freeze({
		id = "RubyAppleTree",
		displayName = "Ruby Apple Tree",
		kind = "Placeable",
		maxStack = 99,
		inventoryOrder = 11,
		toolAssetName = nil,
	}),
	GoldenAppleTree = table.freeze({
		id = "GoldenAppleTree",
		displayName = "Golden Apple Tree",
		kind = "Placeable",
		maxStack = 99,
		inventoryOrder = 12,
		toolAssetName = nil,
	}),
	CrystalAppleTree = table.freeze({
		id = "CrystalAppleTree",
		displayName = "Crystal Apple Tree",
		kind = "Placeable",
		maxStack = 99,
		inventoryOrder = 13,
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
	CopperCiderMill = table.freeze({
		id = "CopperCiderMill",
		displayName = "Copper Cider Mill",
		kind = "Placeable",
		maxStack = 99,
		inventoryOrder = 21,
		toolAssetName = nil,
	}),
	SteelCiderMill = table.freeze({
		id = "SteelCiderMill",
		displayName = "Steel Cider Mill",
		kind = "Placeable",
		maxStack = 99,
		inventoryOrder = 22,
		toolAssetName = nil,
	}),
	RoyalCiderMill = table.freeze({
		id = "RoyalCiderMill",
		displayName = "Royal Cider Mill",
		kind = "Placeable",
		maxStack = 99,
		inventoryOrder = 23,
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

--!strict

local InventoryTypes = require(script.Parent.InventoryTypes)

type ItemDefinition = InventoryTypes.ItemDefinition
type ItemId = InventoryTypes.ItemId

local itemsById: { [ItemId]: ItemDefinition } = {
	WheatField = table.freeze({
		id = "WheatField",
		displayName = "Wheat Field",
		kind = "Placeable",
		maxStack = 99,
		hotbarOrder = 1,
		placementFootprint = Vector3.new(4, 1, 4),
		placementPreviewColor = Color3.fromRGB(102, 181, 104),
		placedPartColor = Color3.fromRGB(166, 124, 82),
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

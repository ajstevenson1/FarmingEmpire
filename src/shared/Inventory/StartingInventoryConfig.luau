--!strict

local InventoryTypes = require(script.Parent.InventoryTypes)

type InventoryEntry = InventoryTypes.InventoryEntry

local startingInventory: { InventoryEntry } = {
	{
		itemId = "WheatField",
		quantity = 3,
	},
}

return table.freeze(startingInventory)

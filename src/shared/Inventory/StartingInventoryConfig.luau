--!strict

local InventoryTypes = require(script.Parent.InventoryTypes)

type InventoryEntry = InventoryTypes.InventoryEntry

local startingInventory: { InventoryEntry } = {
	{
		itemId = "Scythe",
		quantity = 1,
	},
	{
		itemId = "WheatField",
		quantity = 15,
	},
}

return table.freeze(startingInventory)

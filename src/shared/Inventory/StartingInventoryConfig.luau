--!strict

local InventoryTypes = require(script.Parent.InventoryTypes)

type InventoryEntry = InventoryTypes.InventoryEntry

local startingInventory: { InventoryEntry } = {
	{
		itemId = "Scythe",
		quantity = 1,
	},
	{
		itemId = "OakTree",
		quantity = 2,
	},
	{
		itemId = "CiderMill",
		quantity = 1,
	},
}

return table.freeze(startingInventory)

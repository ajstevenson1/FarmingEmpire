--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder

local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local InventoryService = require(script.Parent.Parent.Parent.Inventory.InventoryService)

type ItemDefinition = InventoryTypes.ItemDefinition

local function getSortedItemDefinitions(): { ItemDefinition }
	local itemDefinitions: { ItemDefinition } = {}

	for _, itemDefinition in pairs(ItemCatalog.getAllItemDefinitions()) do
		table.insert(itemDefinitions, itemDefinition)
	end

	table.sort(itemDefinitions, function(leftItemDefinition: ItemDefinition, rightItemDefinition: ItemDefinition): boolean
		if leftItemDefinition.inventoryOrder == rightItemDefinition.inventoryOrder then
			return leftItemDefinition.displayName < rightItemDefinition.displayName
		end

		return leftItemDefinition.inventoryOrder < rightItemDefinition.inventoryOrder
	end)

	return itemDefinitions
end

return function(_context, players: { Player }): string
	local itemDefinitions = getSortedItemDefinitions()
	local grantedCount = 0

	for _, player in ipairs(players) do
		for _, itemDefinition in ipairs(itemDefinitions) do
			if itemDefinition.maxStack == 1 and InventoryService.getItemQuantity(player, itemDefinition.id) > 0 then
				continue
			end

			InventoryService.addItem(player, itemDefinition.id, 1)
			grantedCount += 1
		end
	end

	return string.format(
		"Gave one of every inventory item (%d grant(s) across %d player(s)).",
		grantedCount,
		#players
	)
end

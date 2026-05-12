--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder

local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local InventoryService = require(script.Parent.Parent.Parent.Inventory.InventoryService)

type ItemId = InventoryTypes.ItemId

return function(_context, players: { Player }, buildingId: string, quantity: number): string
	for _, player in ipairs(players) do
		InventoryService.addItem(player, buildingId :: ItemId, quantity)
	end

	return string.format("Gave %dx %s to %d player(s).", quantity, buildingId, #players)
end

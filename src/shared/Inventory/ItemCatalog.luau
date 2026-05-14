--!strict

local InventoryTypes = require(script.Parent.InventoryTypes)
local progressionFolder = script.Parent.Parent:WaitForChild("Progression") :: Folder
local ProgressionConfig = require(progressionFolder:WaitForChild("ProgressionConfig") :: ModuleScript)

type ItemDefinition = InventoryTypes.ItemDefinition
type ItemId = InventoryTypes.ItemId
type MillTierDefinition = ProgressionConfig.MillTierDefinition
type TreeTierDefinition = ProgressionConfig.TreeTierDefinition

local itemsById: { [ItemId]: ItemDefinition } = {
	Scythe = table.freeze({
		id = "Scythe",
		displayName = "Scythe",
		kind = "Tool",
		maxStack = 1,
		inventoryOrder = 0,
		toolAssetName = "Scythe",
	}),
}

local function createPlaceableItemDefinition(id: ItemId, displayName: string, inventoryOrder: number): ItemDefinition
	return table.freeze({
		id = id,
		displayName = displayName,
		kind = "Placeable",
		maxStack = 99,
		inventoryOrder = inventoryOrder,
		toolAssetName = nil,
	})
end

for index, treeDefinition: TreeTierDefinition in ipairs(ProgressionConfig.getTreeDefinitions()) do
	itemsById[treeDefinition.id :: ItemId] = createPlaceableItemDefinition(treeDefinition.id :: ItemId, treeDefinition.displayName, 10 + index - 1)
end

for index, millDefinition: MillTierDefinition in ipairs(ProgressionConfig.getMillDefinitions()) do
	itemsById[millDefinition.id :: ItemId] = createPlaceableItemDefinition(millDefinition.id :: ItemId, millDefinition.displayName, 30 + index - 1)
end

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

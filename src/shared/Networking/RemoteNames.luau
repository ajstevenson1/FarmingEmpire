--!strict

local RemoteNames = {
	rootFolderName = "GameRemotes",
	inventoryFolderName = "Inventory",
	placementFolderName = "Placement",
	harvestFolderName = "Harvest",
	inventoryUpdatedEventName = "InventoryUpdated",
	getInventorySnapshotFunctionName = "GetInventorySnapshot",
	setSelectedSlotEventName = "SetSelectedSlot",
	assignHotbarSlotEventName = "AssignHotbarSlot",
	clearHotbarSlotEventName = "ClearHotbarSlot",
	requestPlacementEventName = "RequestPlacement",
	requestScytheSwingEventName = "RequestScytheSwing",
}

return table.freeze(RemoteNames)

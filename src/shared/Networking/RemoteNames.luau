--!strict

local RemoteNames = {
	rootFolderName = "GameRemotes",
	inventoryFolderName = "Inventory",
	placementFolderName = "Placement",
	inventoryUpdatedEventName = "InventoryUpdated",
	getInventorySnapshotFunctionName = "GetInventorySnapshot",
	setSelectedSlotEventName = "SetSelectedSlot",
	assignHotbarSlotEventName = "AssignHotbarSlot",
	clearHotbarSlotEventName = "ClearHotbarSlot",
	requestPlacementEventName = "RequestPlacement",
}

return table.freeze(RemoteNames)

--!strict

local RemoteNames = {
	rootFolderName = "GameRemotes",
	inventoryFolderName = "Inventory",
	placementFolderName = "Placement",
	inventoryUpdatedEventName = "InventoryUpdated",
	getInventorySnapshotFunctionName = "GetInventorySnapshot",
	setEquippedItemEventName = "SetEquippedItem",
	requestPlacementEventName = "RequestPlacement",
}

return table.freeze(RemoteNames)

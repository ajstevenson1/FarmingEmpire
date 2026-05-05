--!strict

local RemoteNames = {
	rootFolderName = "GameRemotes",
	inventoryFolderName = "Inventory",
	placementFolderName = "Placement",
	harvestFolderName = "Harvest",
	resourcesFolderName = "Resources",
	economyFolderName = "Economy",
	marketFolderName = "Market",
	inventoryUpdatedEventName = "InventoryUpdated",
	getInventorySnapshotFunctionName = "GetInventorySnapshot",
	setSelectedSlotEventName = "SetSelectedSlot",
	assignHotbarSlotEventName = "AssignHotbarSlot",
	unassignHotbarItemEventName = "UnassignHotbarItem",
	requestPlacementEventName = "RequestPlacement",
	requestPickupEventName = "RequestPickup",
	requestScytheSwingEventName = "RequestScytheSwing",
	resourceUpdatedEventName = "ResourceUpdated",
	getResourceSnapshotFunctionName = "GetResourceSnapshot",
	economyUpdatedEventName = "EconomyUpdated",
	getEconomySnapshotFunctionName = "GetEconomySnapshot",
	marketUpdatedEventName = "MarketUpdated",
	getMarketSnapshotFunctionName = "GetMarketSnapshot",
	sellAllCiderEventName = "SellAllCider",
}

return table.freeze(RemoteNames)

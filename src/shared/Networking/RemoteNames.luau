--!strict

local RemoteNames = {
	rootFolderName = "GameRemotes",
	inventoryFolderName = "Inventory",
	placementFolderName = "Placement",
	harvestFolderName = "Harvest",
	resourcesFolderName = "Resources",
	economyFolderName = "Economy",
	marketFolderName = "Market",
	teleportFolderName = "Teleport",
	shopFolderName = "Shop",
	inventoryUpdatedEventName = "InventoryUpdated",
	getInventorySnapshotFunctionName = "GetInventorySnapshot",
	setSelectedSlotEventName = "SetSelectedSlot",
	assignHotbarSlotEventName = "AssignHotbarSlot",
	unassignHotbarItemEventName = "UnassignHotbarItem",
	requestPlacementEventName = "RequestPlacement",
	requestPickupEventName = "RequestPickup",
	requestSellEventName = "RequestSell",
	requestScytheSwingEventName = "RequestScytheSwing",
	resourceUpdatedEventName = "ResourceUpdated",
	getResourceSnapshotFunctionName = "GetResourceSnapshot",
	economyUpdatedEventName = "EconomyUpdated",
	getEconomySnapshotFunctionName = "GetEconomySnapshot",
	marketUpdatedEventName = "MarketUpdated",
	getMarketSnapshotFunctionName = "GetMarketSnapshot",
	sellAllCiderEventName = "SellAllCider",
	requestTeleportEventName = "RequestTeleport",
	shopOpenedEventName = "ShopOpened",
	getShopSnapshotFunctionName = "GetShopSnapshot",
}

return table.freeze(RemoteNames)

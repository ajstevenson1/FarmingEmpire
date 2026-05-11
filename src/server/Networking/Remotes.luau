--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)

type InventoryRemotes = {
	inventoryUpdated: RemoteEvent,
	getInventorySnapshot: RemoteFunction,
	setSelectedSlot: RemoteEvent,
	assignHotbarSlot: RemoteEvent,
	unassignHotbarItem: RemoteEvent,
}

type ResourceRemotes = {
	resourceUpdated: RemoteEvent,
	getResourceSnapshot: RemoteFunction,
}

type EconomyRemotes = {
	economyUpdated: RemoteEvent,
	getEconomySnapshot: RemoteFunction,
}

type PlacementRemotes = {
	requestPlacement: RemoteEvent,
	requestPickup: RemoteEvent,
	requestSell: RemoteEvent,
}

type MarketRemotes = {
	marketUpdated: RemoteEvent,
	ciderMarketOpened: RemoteEvent,
	getMarketSnapshot: RemoteFunction,
	sellAllCider: RemoteEvent,
}

type TeleportRemotes = {
	requestTeleport: RemoteEvent,
}

type ShopRemotes = {
	shopOpened: RemoteEvent,
	getShopSnapshot: RemoteFunction,
	requestShopPurchase: RemoteFunction,
}

type SettingsRemotes = {
	getSettingsSnapshot: RemoteFunction,
	settingChanged: RemoteEvent,
}

local cachedInventoryRemotes: InventoryRemotes? = nil
local cachedPlacementRemotes: PlacementRemotes? = nil
local cachedHarvestRemote: RemoteEvent? = nil
local cachedHarvestConfirmedRemote: RemoteEvent? = nil
local cachedResourceRemotes: ResourceRemotes? = nil
local cachedEconomyRemotes: EconomyRemotes? = nil
local cachedMarketRemotes: MarketRemotes? = nil
local cachedTeleportRemotes: TeleportRemotes? = nil
local cachedShopRemotes: ShopRemotes? = nil
local cachedSettingsRemotes: SettingsRemotes? = nil

local function getOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing ~= nil then
		assert(existing:IsA("Folder"), string.format("%s already exists and is not a Folder", name))
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent

	return folder
end

local function getOrCreateRemoteEvent(parent: Instance, name: string): RemoteEvent
	local existing = parent:FindFirstChild(name)
	if existing ~= nil then
		assert(existing:IsA("RemoteEvent"), string.format("%s already exists and is not a RemoteEvent", name))
		return existing
	end

	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = name
	remoteEvent.Parent = parent

	return remoteEvent
end

local function getOrCreateRemoteFunction(parent: Instance, name: string): RemoteFunction
	local existing = parent:FindFirstChild(name)
	if existing ~= nil then
		assert(existing:IsA("RemoteFunction"), string.format("%s already exists and is not a RemoteFunction", name))
		return existing
	end

	local remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = name
	remoteFunction.Parent = parent

	return remoteFunction
end

local function getRootFolder(): Folder
	return getOrCreateFolder(ReplicatedStorage, RemoteNames.rootFolderName)
end

local Remotes = {}

function Remotes.getInventoryRemotes(): InventoryRemotes
	if cachedInventoryRemotes ~= nil then
		return cachedInventoryRemotes
	end

	local inventoryFolder = getOrCreateFolder(getRootFolder(), RemoteNames.inventoryFolderName)

	cachedInventoryRemotes = {
		inventoryUpdated = getOrCreateRemoteEvent(inventoryFolder, RemoteNames.inventoryUpdatedEventName),
		getInventorySnapshot = getOrCreateRemoteFunction(inventoryFolder, RemoteNames.getInventorySnapshotFunctionName),
		setSelectedSlot = getOrCreateRemoteEvent(inventoryFolder, RemoteNames.setSelectedSlotEventName),
		assignHotbarSlot = getOrCreateRemoteEvent(inventoryFolder, RemoteNames.assignHotbarSlotEventName),
		unassignHotbarItem = getOrCreateRemoteEvent(inventoryFolder, RemoteNames.unassignHotbarItemEventName),
	}

	return cachedInventoryRemotes
end

function Remotes.getPlacementRemotes(): PlacementRemotes
	if cachedPlacementRemotes ~= nil then
		return cachedPlacementRemotes
	end

	local placementFolder = getOrCreateFolder(getRootFolder(), RemoteNames.placementFolderName)
	cachedPlacementRemotes = {
		requestPlacement = getOrCreateRemoteEvent(placementFolder, RemoteNames.requestPlacementEventName),
		requestPickup = getOrCreateRemoteEvent(placementFolder, RemoteNames.requestPickupEventName),
		requestSell = getOrCreateRemoteEvent(placementFolder, RemoteNames.requestSellEventName),
	}

	return cachedPlacementRemotes
end

function Remotes.getHarvestRemote(): RemoteEvent
	if cachedHarvestRemote ~= nil then
		return cachedHarvestRemote
	end

	local harvestFolder = getOrCreateFolder(getRootFolder(), RemoteNames.harvestFolderName)
	cachedHarvestRemote = getOrCreateRemoteEvent(harvestFolder, RemoteNames.requestScytheSwingEventName)

	return cachedHarvestRemote
end

function Remotes.getScytheHarvestConfirmedRemote(): RemoteEvent
	if cachedHarvestConfirmedRemote ~= nil then
		return cachedHarvestConfirmedRemote
	end

	local harvestFolder = getOrCreateFolder(getRootFolder(), RemoteNames.harvestFolderName)
	cachedHarvestConfirmedRemote = getOrCreateRemoteEvent(harvestFolder, RemoteNames.scytheHarvestConfirmedEventName)

	return cachedHarvestConfirmedRemote
end

function Remotes.getResourceRemotes(): ResourceRemotes
	if cachedResourceRemotes ~= nil then
		return cachedResourceRemotes
	end

	local resourcesFolder = getOrCreateFolder(getRootFolder(), RemoteNames.resourcesFolderName)
	cachedResourceRemotes = {
		resourceUpdated = getOrCreateRemoteEvent(resourcesFolder, RemoteNames.resourceUpdatedEventName),
		getResourceSnapshot = getOrCreateRemoteFunction(resourcesFolder, RemoteNames.getResourceSnapshotFunctionName),
	}

	return cachedResourceRemotes
end

function Remotes.getEconomyRemotes(): EconomyRemotes
	if cachedEconomyRemotes ~= nil then
		return cachedEconomyRemotes
	end

	local economyFolder = getOrCreateFolder(getRootFolder(), RemoteNames.economyFolderName)
	cachedEconomyRemotes = {
		economyUpdated = getOrCreateRemoteEvent(economyFolder, RemoteNames.economyUpdatedEventName),
		getEconomySnapshot = getOrCreateRemoteFunction(economyFolder, RemoteNames.getEconomySnapshotFunctionName),
	}

	return cachedEconomyRemotes
end

function Remotes.getMarketRemotes(): MarketRemotes
	if cachedMarketRemotes ~= nil then
		return cachedMarketRemotes
	end

	local marketFolder = getOrCreateFolder(getRootFolder(), RemoteNames.marketFolderName)
	cachedMarketRemotes = {
		marketUpdated = getOrCreateRemoteEvent(marketFolder, RemoteNames.marketUpdatedEventName),
		ciderMarketOpened = getOrCreateRemoteEvent(marketFolder, RemoteNames.ciderMarketOpenedEventName),
		getMarketSnapshot = getOrCreateRemoteFunction(marketFolder, RemoteNames.getMarketSnapshotFunctionName),
		sellAllCider = getOrCreateRemoteEvent(marketFolder, RemoteNames.sellAllCiderEventName),
	}

	return cachedMarketRemotes
end

function Remotes.getTeleportRemotes(): TeleportRemotes
	if cachedTeleportRemotes ~= nil then
		return cachedTeleportRemotes
	end

	local teleportFolder = getOrCreateFolder(getRootFolder(), RemoteNames.teleportFolderName)
	cachedTeleportRemotes = {
		requestTeleport = getOrCreateRemoteEvent(teleportFolder, RemoteNames.requestTeleportEventName),
	}

	return cachedTeleportRemotes
end

function Remotes.getShopRemotes(): ShopRemotes
	if cachedShopRemotes ~= nil then
		return cachedShopRemotes
	end

	local shopFolder = getOrCreateFolder(getRootFolder(), RemoteNames.shopFolderName)
	cachedShopRemotes = {
		shopOpened = getOrCreateRemoteEvent(shopFolder, RemoteNames.shopOpenedEventName),
		getShopSnapshot = getOrCreateRemoteFunction(shopFolder, RemoteNames.getShopSnapshotFunctionName),
		requestShopPurchase = getOrCreateRemoteFunction(shopFolder, RemoteNames.requestShopPurchaseFunctionName),
	}

	return cachedShopRemotes
end

function Remotes.getSettingsRemotes(): SettingsRemotes
	if cachedSettingsRemotes ~= nil then
		return cachedSettingsRemotes
	end

	local settingsFolder = getOrCreateFolder(getRootFolder(), RemoteNames.settingsFolderName)
	cachedSettingsRemotes = {
		getSettingsSnapshot = getOrCreateRemoteFunction(settingsFolder, RemoteNames.getSettingsSnapshotFunctionName),
		settingChanged = getOrCreateRemoteEvent(settingsFolder, RemoteNames.settingChangedEventName),
	}

	return cachedSettingsRemotes
end

return table.freeze(Remotes)

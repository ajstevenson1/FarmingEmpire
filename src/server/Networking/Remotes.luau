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
	requestPickupAll: RemoteEvent,
	requestSell: RemoteEvent,
}

type HarvestRemotes = {
	requestScytheSwing: RemoteEvent,
	requestAutoHarvestState: RemoteEvent,
	requestAutoHarvest: RemoteEvent,
	scytheHarvestConfirmed: RemoteEvent,
	harvestEffect: RemoteEvent,
}

type MarketRemotes = {
	marketUpdated: RemoteEvent,
	ciderMarketOpened: RemoteEvent,
	ciderMarketClosed: RemoteEvent,
	getMarketSnapshot: RemoteFunction,
	sellAllCider: RemoteEvent,
}

type PlotExpansionRemotes = {
	plotExpansionUpdated: RemoteEvent,
	getPlotExpansionSnapshot: RemoteFunction,
	requestPlotTilePurchase: RemoteFunction,
}

type TeleportRemotes = {
	requestTeleport: RemoteEvent,
}

type ShopRemotes = {
	shopOpened: RemoteEvent,
	shopClosed: RemoteEvent,
	getShopSnapshot: RemoteFunction,
	requestShopPurchase: RemoteFunction,
}

type MonetizationRemotes = {
	setAutoCiderEnabled: RemoteEvent,
}

type SettingsRemotes = {
	getSettingsSnapshot: RemoteFunction,
	settingChanged: RemoteEvent,
}

type PlaytimeRewardsRemotes = {
	playtimeRewardsUpdated: RemoteEvent,
	getPlaytimeRewardsSnapshot: RemoteFunction,
	claimPlaytimeReward: RemoteFunction,
}

type NotificationRemotes = {
	notificationReceived: RemoteEvent,
}

type TutorialRemotes = {
	tutorialStepUpdated: RemoteEvent,
	tutorialTapContinue: RemoteEvent,
	tutorialSkipRequested: RemoteEvent,
	getTutorialSnapshot: RemoteFunction,
}

type WeatherRemotes = {
	weatherUpdated: RemoteEvent,
	getWeatherSnapshot: RemoteFunction,
}

local cachedInventoryRemotes: InventoryRemotes? = nil
local cachedPlacementRemotes: PlacementRemotes? = nil
local cachedHarvestRemote: RemoteEvent? = nil
local cachedHarvestConfirmedRemote: RemoteEvent? = nil
local cachedHarvestRemotes: HarvestRemotes? = nil
local cachedResourceRemotes: ResourceRemotes? = nil
local cachedEconomyRemotes: EconomyRemotes? = nil
local cachedMarketRemotes: MarketRemotes? = nil
local cachedPlotExpansionRemotes: PlotExpansionRemotes? = nil
local cachedTeleportRemotes: TeleportRemotes? = nil
local cachedShopRemotes: ShopRemotes? = nil
local cachedMonetizationRemotes: MonetizationRemotes? = nil
local cachedSettingsRemotes: SettingsRemotes? = nil
local cachedPlaytimeRewardsRemotes: PlaytimeRewardsRemotes? = nil
local cachedNotificationRemotes: NotificationRemotes? = nil
local cachedTutorialRemotes: TutorialRemotes? = nil
local cachedWeatherRemotes: WeatherRemotes? = nil

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
		requestPickupAll = getOrCreateRemoteEvent(placementFolder, RemoteNames.requestPickupAllEventName),
		requestSell = getOrCreateRemoteEvent(placementFolder, RemoteNames.requestSellEventName),
	}

	return cachedPlacementRemotes
end

function Remotes.getHarvestRemote(): RemoteEvent
	return Remotes.getHarvestRemotes().requestScytheSwing
end

function Remotes.getScytheHarvestConfirmedRemote(): RemoteEvent
	return Remotes.getHarvestRemotes().scytheHarvestConfirmed
end

function Remotes.getHarvestRemotes(): HarvestRemotes
	if cachedHarvestRemotes ~= nil then
		return cachedHarvestRemotes
	end

	local harvestFolder = getOrCreateFolder(getRootFolder(), RemoteNames.harvestFolderName)
	local requestScytheSwing = getOrCreateRemoteEvent(harvestFolder, RemoteNames.requestScytheSwingEventName)
	local scytheHarvestConfirmed = getOrCreateRemoteEvent(harvestFolder, RemoteNames.scytheHarvestConfirmedEventName)
	cachedHarvestRemote = requestScytheSwing
	cachedHarvestConfirmedRemote = scytheHarvestConfirmed
	cachedHarvestRemotes = {
		requestScytheSwing = requestScytheSwing,
		requestAutoHarvestState = getOrCreateRemoteEvent(harvestFolder, RemoteNames.requestAutoHarvestStateEventName),
		requestAutoHarvest = getOrCreateRemoteEvent(harvestFolder, RemoteNames.requestAutoHarvestEventName),
		scytheHarvestConfirmed = scytheHarvestConfirmed,
		harvestEffect = getOrCreateRemoteEvent(harvestFolder, RemoteNames.harvestEffectEventName),
	}

	return cachedHarvestRemotes
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
		ciderMarketClosed = getOrCreateRemoteEvent(marketFolder, RemoteNames.ciderMarketClosedEventName),
		getMarketSnapshot = getOrCreateRemoteFunction(marketFolder, RemoteNames.getMarketSnapshotFunctionName),
		sellAllCider = getOrCreateRemoteEvent(marketFolder, RemoteNames.sellAllCiderEventName),
	}

	return cachedMarketRemotes
end

function Remotes.getPlotExpansionRemotes(): PlotExpansionRemotes
	if cachedPlotExpansionRemotes ~= nil then
		return cachedPlotExpansionRemotes
	end

	local plotExpansionFolder = getOrCreateFolder(getRootFolder(), RemoteNames.plotExpansionFolderName)
	cachedPlotExpansionRemotes = {
		plotExpansionUpdated = getOrCreateRemoteEvent(plotExpansionFolder, RemoteNames.plotExpansionUpdatedEventName),
		getPlotExpansionSnapshot = getOrCreateRemoteFunction(plotExpansionFolder, RemoteNames.getPlotExpansionSnapshotFunctionName),
		requestPlotTilePurchase = getOrCreateRemoteFunction(plotExpansionFolder, RemoteNames.requestPlotTilePurchaseFunctionName),
	}

	return cachedPlotExpansionRemotes
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
		shopClosed = getOrCreateRemoteEvent(shopFolder, RemoteNames.shopClosedEventName),
		getShopSnapshot = getOrCreateRemoteFunction(shopFolder, RemoteNames.getShopSnapshotFunctionName),
		requestShopPurchase = getOrCreateRemoteFunction(shopFolder, RemoteNames.requestShopPurchaseFunctionName),
	}

	return cachedShopRemotes
end

function Remotes.getMonetizationRemotes(): MonetizationRemotes
	if cachedMonetizationRemotes ~= nil then
		return cachedMonetizationRemotes
	end

	local monetizationFolder = getOrCreateFolder(getRootFolder(), RemoteNames.monetizationFolderName)
	cachedMonetizationRemotes = {
		setAutoCiderEnabled = getOrCreateRemoteEvent(monetizationFolder, RemoteNames.setAutoCiderEnabledEventName),
	}

	return cachedMonetizationRemotes
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

function Remotes.getPlaytimeRewardsRemotes(): PlaytimeRewardsRemotes
	if cachedPlaytimeRewardsRemotes ~= nil then
		return cachedPlaytimeRewardsRemotes
	end

	local playtimeRewardsFolder = getOrCreateFolder(getRootFolder(), RemoteNames.playtimeRewardsFolderName)
	cachedPlaytimeRewardsRemotes = {
		playtimeRewardsUpdated = getOrCreateRemoteEvent(playtimeRewardsFolder, RemoteNames.playtimeRewardsUpdatedEventName),
		getPlaytimeRewardsSnapshot = getOrCreateRemoteFunction(playtimeRewardsFolder, RemoteNames.getPlaytimeRewardsSnapshotFunctionName),
		claimPlaytimeReward = getOrCreateRemoteFunction(playtimeRewardsFolder, RemoteNames.claimPlaytimeRewardFunctionName),
	}

	return cachedPlaytimeRewardsRemotes
end

function Remotes.getNotificationRemotes(): NotificationRemotes
	if cachedNotificationRemotes ~= nil then
		return cachedNotificationRemotes
	end

	local notificationsFolder = getOrCreateFolder(getRootFolder(), RemoteNames.notificationsFolderName)
	cachedNotificationRemotes = {
		notificationReceived = getOrCreateRemoteEvent(notificationsFolder, RemoteNames.notificationReceivedEventName),
	}

	return cachedNotificationRemotes
end

function Remotes.getTutorialRemotes(): TutorialRemotes
	if cachedTutorialRemotes ~= nil then
		return cachedTutorialRemotes
	end

	local tutorialFolder = getOrCreateFolder(getRootFolder(), RemoteNames.tutorialFolderName)
	cachedTutorialRemotes = {
		tutorialStepUpdated = getOrCreateRemoteEvent(tutorialFolder, RemoteNames.tutorialStepUpdatedEventName),
		tutorialTapContinue = getOrCreateRemoteEvent(tutorialFolder, RemoteNames.tutorialTapContinueEventName),
		tutorialSkipRequested = getOrCreateRemoteEvent(tutorialFolder, RemoteNames.tutorialSkipRequestedEventName),
		getTutorialSnapshot = getOrCreateRemoteFunction(tutorialFolder, RemoteNames.getTutorialSnapshotFunctionName),
	}

	return cachedTutorialRemotes
end

function Remotes.getWeatherRemotes(): WeatherRemotes
	if cachedWeatherRemotes ~= nil then
		return cachedWeatherRemotes
	end

	local weatherFolder = getOrCreateFolder(getRootFolder(), RemoteNames.weatherFolderName)
	cachedWeatherRemotes = {
		weatherUpdated = getOrCreateRemoteEvent(weatherFolder, RemoteNames.weatherUpdatedEventName),
		getWeatherSnapshot = getOrCreateRemoteFunction(weatherFolder, RemoteNames.getWeatherSnapshotFunctionName),
	}

	return cachedWeatherRemotes
end

return table.freeze(Remotes)

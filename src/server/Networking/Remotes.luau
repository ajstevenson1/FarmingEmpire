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
	clearHotbarSlot: RemoteEvent,
}

local cachedInventoryRemotes: InventoryRemotes? = nil
local cachedPlacementRemote: RemoteEvent? = nil
local cachedHarvestRemote: RemoteEvent? = nil

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

local Remotes = {}

function Remotes.getInventoryRemotes(): InventoryRemotes
	if cachedInventoryRemotes ~= nil then
		return cachedInventoryRemotes
	end

	local rootFolder = getOrCreateFolder(ReplicatedStorage, RemoteNames.rootFolderName)
	local inventoryFolder = getOrCreateFolder(rootFolder, RemoteNames.inventoryFolderName)

	cachedInventoryRemotes = {
		inventoryUpdated = getOrCreateRemoteEvent(inventoryFolder, RemoteNames.inventoryUpdatedEventName),
		getInventorySnapshot = getOrCreateRemoteFunction(inventoryFolder, RemoteNames.getInventorySnapshotFunctionName),
		setSelectedSlot = getOrCreateRemoteEvent(inventoryFolder, RemoteNames.setSelectedSlotEventName),
		assignHotbarSlot = getOrCreateRemoteEvent(inventoryFolder, RemoteNames.assignHotbarSlotEventName),
		clearHotbarSlot = getOrCreateRemoteEvent(inventoryFolder, RemoteNames.clearHotbarSlotEventName),
	}

	return cachedInventoryRemotes
end

function Remotes.getPlacementRemote(): RemoteEvent
	if cachedPlacementRemote ~= nil then
		return cachedPlacementRemote
	end

	local rootFolder = getOrCreateFolder(ReplicatedStorage, RemoteNames.rootFolderName)
	local placementFolder = getOrCreateFolder(rootFolder, RemoteNames.placementFolderName)
	cachedPlacementRemote = getOrCreateRemoteEvent(placementFolder, RemoteNames.requestPlacementEventName)

	return cachedPlacementRemote
end

function Remotes.getHarvestRemote(): RemoteEvent
	if cachedHarvestRemote ~= nil then
		return cachedHarvestRemote
	end

	local rootFolder = getOrCreateFolder(ReplicatedStorage, RemoteNames.rootFolderName)
	local harvestFolder = getOrCreateFolder(rootFolder, RemoteNames.harvestFolderName)
	cachedHarvestRemote = getOrCreateRemoteEvent(harvestFolder, RemoteNames.requestScytheSwingEventName)

	return cachedHarvestRemote
end

return table.freeze(Remotes)

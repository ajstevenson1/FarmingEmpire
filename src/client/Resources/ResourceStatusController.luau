--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local economyFolder = sharedFolder:WaitForChild("Economy") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local EconomyTypes = require(economyFolder:WaitForChild("EconomyTypes") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)
local ResourceStatusView = require(script.Parent.ResourceStatusView)

type EconomySnapshot = EconomyTypes.EconomySnapshot
type MarketSnapshot = EconomyTypes.MarketSnapshot
type ResourceSnapshot = ResourceTypes.ResourceSnapshot
type ResourceStatusViewInstance = ResourceStatusView.ResourceStatusView

local hasStarted = false
local latestEconomySnapshot: EconomySnapshot? = nil
local latestMarketSnapshot: MarketSnapshot? = nil
local latestResourceSnapshot: ResourceSnapshot? = nil

local function getResourceRemotes(): (RemoteEvent, RemoteFunction)
	local remotesFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local resourcesRemoteFolder = remotesFolder:WaitForChild(RemoteNames.resourcesFolderName) :: Folder
	local resourceUpdated = resourcesRemoteFolder:WaitForChild(RemoteNames.resourceUpdatedEventName) :: RemoteEvent
	local getResourceSnapshot = resourcesRemoteFolder:WaitForChild(RemoteNames.getResourceSnapshotFunctionName) :: RemoteFunction
	return resourceUpdated, getResourceSnapshot
end

local function getEconomyRemotes(): (RemoteEvent, RemoteFunction)
	local remotesFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local economyRemoteFolder = remotesFolder:WaitForChild(RemoteNames.economyFolderName) :: Folder
	local economyUpdated = economyRemoteFolder:WaitForChild(RemoteNames.economyUpdatedEventName) :: RemoteEvent
	local getEconomySnapshot = economyRemoteFolder:WaitForChild(RemoteNames.getEconomySnapshotFunctionName) :: RemoteFunction
	return economyUpdated, getEconomySnapshot
end

local function getMarketRemotes(): (RemoteEvent, RemoteFunction, RemoteEvent)
	local remotesFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local marketRemoteFolder = remotesFolder:WaitForChild(RemoteNames.marketFolderName) :: Folder
	local marketUpdated = marketRemoteFolder:WaitForChild(RemoteNames.marketUpdatedEventName) :: RemoteEvent
	local getMarketSnapshot = marketRemoteFolder:WaitForChild(RemoteNames.getMarketSnapshotFunctionName) :: RemoteFunction
	local sellAllCider = marketRemoteFolder:WaitForChild(RemoteNames.sellAllCiderEventName) :: RemoteEvent
	return marketUpdated, getMarketSnapshot, sellAllCider
end

local function getSecondsUntilPriceChange(snapshot: MarketSnapshot): number
	return math.max(0, math.ceil(snapshot.nextPriceChangeAt - Workspace:GetServerTimeNow()))
end

local function renderIfReady(view: ResourceStatusViewInstance)
	if latestResourceSnapshot == nil or latestEconomySnapshot == nil or latestMarketSnapshot == nil then
		return
	end

	view:render(
		latestResourceSnapshot,
		latestEconomySnapshot,
		latestMarketSnapshot,
		getSecondsUntilPriceChange(latestMarketSnapshot)
	)
end

local ResourceStatusController = {}

function ResourceStatusController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local view = ResourceStatusView.new()
	local resourceUpdated, getResourceSnapshot = getResourceRemotes()
	local economyUpdated, getEconomySnapshot = getEconomyRemotes()
	local marketUpdated, getMarketSnapshot, sellAllCider = getMarketRemotes()

	latestResourceSnapshot = getResourceSnapshot:InvokeServer() :: ResourceSnapshot
	latestEconomySnapshot = getEconomySnapshot:InvokeServer() :: EconomySnapshot
	latestMarketSnapshot = getMarketSnapshot:InvokeServer() :: MarketSnapshot
	renderIfReady(view)

	resourceUpdated.OnClientEvent:Connect(function(resourceSnapshot: ResourceSnapshot)
		latestResourceSnapshot = resourceSnapshot
		renderIfReady(view)
	end)

	economyUpdated.OnClientEvent:Connect(function(economySnapshot: EconomySnapshot)
		latestEconomySnapshot = economySnapshot
		renderIfReady(view)
	end)

	marketUpdated.OnClientEvent:Connect(function(marketSnapshot: MarketSnapshot)
		latestMarketSnapshot = marketSnapshot
		renderIfReady(view)
	end)

	view:connectSellRequested(function()
		sellAllCider:FireServer()
	end)

	task.spawn(function()
		while true do
			renderIfReady(view)
			task.wait(1)
		end
	end)
end

return table.freeze(ResourceStatusController)

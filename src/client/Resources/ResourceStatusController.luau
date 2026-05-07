--!strict

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
type ResourceSnapshot = ResourceTypes.ResourceSnapshot
type ResourceStatusViewInstance = ResourceStatusView.ResourceStatusView

local hasStarted = false
local latestEconomySnapshot: EconomySnapshot? = nil
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

local function renderIfReady(view: ResourceStatusViewInstance)
	local resourceSnapshot = latestResourceSnapshot
	local economySnapshot = latestEconomySnapshot
	if resourceSnapshot == nil or economySnapshot == nil then
		return
	end

	local apples = resourceSnapshot.amountsByResourceId.Apple or 0
	local cider = resourceSnapshot.amountsByResourceId.Cider or 0
	view:render(apples, cider, economySnapshot.cash)
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

	latestResourceSnapshot = getResourceSnapshot:InvokeServer() :: ResourceSnapshot
	latestEconomySnapshot = getEconomySnapshot:InvokeServer() :: EconomySnapshot
	renderIfReady(view)

	resourceUpdated.OnClientEvent:Connect(function(resourceSnapshot: ResourceSnapshot)
		latestResourceSnapshot = resourceSnapshot
		renderIfReady(view)
	end)

	economyUpdated.OnClientEvent:Connect(function(economySnapshot: EconomySnapshot)
		latestEconomySnapshot = economySnapshot
		renderIfReady(view)
	end)
end

return table.freeze(ResourceStatusController)

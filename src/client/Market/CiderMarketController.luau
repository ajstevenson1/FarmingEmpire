--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local economyFolder = sharedFolder:WaitForChild("Economy") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local EconomyTypes = require(economyFolder:WaitForChild("EconomyTypes") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)
local FrameManager = require(script.Parent.Parent.UI.FrameManager)
local CiderMarketView = require(script.Parent.CiderMarketView)

type EconomySnapshot = EconomyTypes.EconomySnapshot
type MarketSnapshot = EconomyTypes.MarketSnapshot
type ResourceSnapshot = ResourceTypes.ResourceSnapshot
type CiderMarketViewInstance = CiderMarketView.CiderMarketView

local CIDER_MARKET_FRAME_ID = "CiderMarket"
local MENU_FRAME_GROUP = "Menu"

local hasStarted = false
local latestMarketSnapshot: MarketSnapshot? = nil
local latestResourceSnapshot: ResourceSnapshot? = nil
local latestEconomySnapshot: EconomySnapshot? = nil
local latestStatusText: string? = nil

local function getMarketRemotes(): (RemoteEvent, RemoteEvent, RemoteEvent, RemoteFunction)
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local marketFolder = rootFolder:WaitForChild(RemoteNames.marketFolderName) :: Folder
	local marketUpdated = marketFolder:WaitForChild(RemoteNames.marketUpdatedEventName) :: RemoteEvent
	local ciderMarketOpened = marketFolder:WaitForChild(RemoteNames.ciderMarketOpenedEventName) :: RemoteEvent
	local ciderMarketClosed = marketFolder:WaitForChild(RemoteNames.ciderMarketClosedEventName) :: RemoteEvent
	local getMarketSnapshot = marketFolder:WaitForChild(RemoteNames.getMarketSnapshotFunctionName) :: RemoteFunction
	return marketUpdated, ciderMarketOpened, ciderMarketClosed, getMarketSnapshot
end

local function getSellAllCiderRemote(): RemoteEvent
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local marketFolder = rootFolder:WaitForChild(RemoteNames.marketFolderName) :: Folder
	return marketFolder:WaitForChild(RemoteNames.sellAllCiderEventName) :: RemoteEvent
end

local function getResourceRemotes(): (RemoteEvent, RemoteFunction)
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local resourceFolder = rootFolder:WaitForChild(RemoteNames.resourcesFolderName) :: Folder
	local resourceUpdated = resourceFolder:WaitForChild(RemoteNames.resourceUpdatedEventName) :: RemoteEvent
	local getResourceSnapshot = resourceFolder:WaitForChild(RemoteNames.getResourceSnapshotFunctionName) :: RemoteFunction
	return resourceUpdated, getResourceSnapshot
end

local function getEconomyRemotes(): (RemoteEvent, RemoteFunction)
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local economyRemoteFolder = rootFolder:WaitForChild(RemoteNames.economyFolderName) :: Folder
	local economyUpdated = economyRemoteFolder:WaitForChild(RemoteNames.economyUpdatedEventName) :: RemoteEvent
	local getEconomySnapshot = economyRemoteFolder:WaitForChild(RemoteNames.getEconomySnapshotFunctionName) :: RemoteFunction
	return economyUpdated, getEconomySnapshot
end

local function getClosedPanelPosition(panel: Frame): UDim2
	return UDim2.new(panel.Position.X.Scale, panel.Position.X.Offset, 1, 160)
end

local function getCiderAmount(): number
	local snapshot = latestResourceSnapshot
	if snapshot == nil then
		return 0
	end

	return snapshot.amountsByResourceId.Cider or 0
end

local function getCash(): number
	local snapshot = latestEconomySnapshot
	if snapshot == nil then
		return 0
	end

	return snapshot.cash
end

local function getSecondsUntilPriceChange(snapshot: MarketSnapshot): number
	return math.max(0, math.ceil(snapshot.nextPriceChangeAt - Workspace:GetServerTimeNow()))
end

local function renderIfReady(view: CiderMarketViewInstance)
	local marketSnapshot = latestMarketSnapshot
	if marketSnapshot == nil then
		return
	end

	view:render(
		marketSnapshot.ciderSellPrice,
		getSecondsUntilPriceChange(marketSnapshot),
		getCiderAmount(),
		getCash(),
		latestStatusText
	)
end

local CiderMarketController = {}

function CiderMarketController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local view = CiderMarketView.new()
	local panel = view:getFrame()
	FrameManager.registerFrame({
		id = CIDER_MARKET_FRAME_ID,
		frame = panel,
		group = MENU_FRAME_GROUP,
		defaultOpen = false,
		closedPosition = getClosedPanelPosition(panel),
	})

	local marketUpdated, ciderMarketOpened, ciderMarketClosed, getMarketSnapshot = getMarketRemotes()
	local resourceUpdated, getResourceSnapshot = getResourceRemotes()
	local economyUpdated, getEconomySnapshot = getEconomyRemotes()
	local sellAllCider = getSellAllCiderRemote()

	latestMarketSnapshot = getMarketSnapshot:InvokeServer() :: MarketSnapshot
	latestResourceSnapshot = getResourceSnapshot:InvokeServer() :: ResourceSnapshot
	latestEconomySnapshot = getEconomySnapshot:InvokeServer() :: EconomySnapshot
	renderIfReady(view)

	view:connectCloseRequested(function()
		FrameManager.close(CIDER_MARKET_FRAME_ID)
	end)
	FrameManager.observeFrameClosed(function(frameId: string)
		if frameId == CIDER_MARKET_FRAME_ID then
			ciderMarketClosed:FireServer()
		end
	end)

	view:connectSellRequested(function()
		local marketSnapshot = latestMarketSnapshot
		local ciderAmount = getCiderAmount()
		if marketSnapshot == nil or ciderAmount <= 0 then
			latestStatusText = "No cider to sell."
			renderIfReady(view)
			return
		end

		latestStatusText = string.format(
			"Sell request sent for %d cider at $%d each.",
			ciderAmount,
			marketSnapshot.ciderSellPrice
		)
		sellAllCider:FireServer()
		renderIfReady(view)
	end)

	ciderMarketOpened.OnClientEvent:Connect(function()
		latestMarketSnapshot = getMarketSnapshot:InvokeServer() :: MarketSnapshot
		latestResourceSnapshot = getResourceSnapshot:InvokeServer() :: ResourceSnapshot
		latestEconomySnapshot = getEconomySnapshot:InvokeServer() :: EconomySnapshot
		latestStatusText = nil
		renderIfReady(view)
		FrameManager.open(CIDER_MARKET_FRAME_ID)
	end)

	marketUpdated.OnClientEvent:Connect(function(marketSnapshot: MarketSnapshot)
		latestMarketSnapshot = marketSnapshot
		renderIfReady(view)
	end)

	resourceUpdated.OnClientEvent:Connect(function(resourceSnapshot: ResourceSnapshot)
		latestResourceSnapshot = resourceSnapshot
		renderIfReady(view)
	end)

	economyUpdated.OnClientEvent:Connect(function(economySnapshot: EconomySnapshot)
		latestEconomySnapshot = economySnapshot
		renderIfReady(view)
	end)

	task.spawn(function()
		while true do
			renderIfReady(view)
			task.wait(1)
		end
	end)
end

return table.freeze(CiderMarketController)

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local economyFolder = sharedFolder:WaitForChild("Economy") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder
local shopsFolder = sharedFolder:WaitForChild("Shops") :: Folder

local EconomyTypes = require(economyFolder:WaitForChild("EconomyTypes") :: ModuleScript)
local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local ResourceCatalog = require(resourcesFolder:WaitForChild("ResourceCatalog") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)
local ShopCatalog = require(shopsFolder:WaitForChild("ShopCatalog") :: ModuleScript)
local ShopTypes = require(shopsFolder:WaitForChild("ShopTypes") :: ModuleScript)
local FrameManager = require(script.Parent.Parent.UI.FrameManager)
local HudNotificationController = require(script.Parent.Parent.Notifications.HudNotificationController)
local ShopMenuView = require(script.Parent.ShopMenuView)
local TutorialClientState = require(script.Parent.Parent.Tutorial.TutorialClientState)

type EconomySnapshot = EconomyTypes.EconomySnapshot
type ResourceId = ResourceTypes.ResourceId
type ResourceSnapshot = ResourceTypes.ResourceSnapshot
type ShopId = ShopTypes.ShopId
type ShopOpenedPayload = ShopTypes.ShopOpenedPayload
type ShopProductDefinition = ShopTypes.ShopProductDefinition
type ShopProductId = ShopTypes.ShopProductId
type ShopPurchaseResult = ShopTypes.ShopPurchaseResult
type ShopPurchaseStatus = ShopTypes.ShopPurchaseStatus
type ShopSnapshot = ShopTypes.ShopSnapshot
type RenderProduct = ShopMenuView.RenderProduct
type ShopMenuViewInstance = ShopMenuView.ShopMenuView

local MENU_FRAME_GROUP = "Menu"
local hasStarted = false
local activeShopId: ShopId? = nil
local latestSnapshot: ShopSnapshot? = nil
local latestResourceSnapshot: ResourceSnapshot? = nil
local latestCash = 0
local isPurchasePending = false
local freeTutorialProductIdByShopId: { [ShopId]: ShopProductId } = {}
local hasInitializedRestockNotifications = false

local function getShopRemotes(): (RemoteEvent, RemoteEvent, RemoteFunction, RemoteFunction)
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local shopFolder = rootFolder:WaitForChild(RemoteNames.shopFolderName) :: Folder
	local shopOpened = shopFolder:WaitForChild(RemoteNames.shopOpenedEventName) :: RemoteEvent
	local shopClosed = shopFolder:WaitForChild(RemoteNames.shopClosedEventName) :: RemoteEvent
	local getShopSnapshot = shopFolder:WaitForChild(RemoteNames.getShopSnapshotFunctionName) :: RemoteFunction
	local requestShopPurchase = shopFolder:WaitForChild(RemoteNames.requestShopPurchaseFunctionName) :: RemoteFunction
	return shopOpened, shopClosed, getShopSnapshot, requestShopPurchase
end

local function getEconomyRemotes(): (RemoteEvent, RemoteFunction)
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local economyRemoteFolder = rootFolder:WaitForChild(RemoteNames.economyFolderName) :: Folder
	local economyUpdated = economyRemoteFolder:WaitForChild(RemoteNames.economyUpdatedEventName) :: RemoteEvent
	local getEconomySnapshot = economyRemoteFolder:WaitForChild(RemoteNames.getEconomySnapshotFunctionName) :: RemoteFunction
	return economyUpdated, getEconomySnapshot
end

local function getResourceRemotes(): (RemoteEvent, RemoteFunction)
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local resourcesRemoteFolder = rootFolder:WaitForChild(RemoteNames.resourcesFolderName) :: Folder
	local resourceUpdated = resourcesRemoteFolder:WaitForChild(RemoteNames.resourceUpdatedEventName) :: RemoteEvent
	local getResourceSnapshot = resourcesRemoteFolder:WaitForChild(RemoteNames.getResourceSnapshotFunctionName) :: RemoteFunction
	return resourceUpdated, getResourceSnapshot
end

local function getClosedPanelPosition(panel: Frame): UDim2
	return UDim2.new(panel.Position.X.Scale, panel.Position.X.Offset, 1, 180)
end

local function getSecondsUntilRestock(snapshot: ShopSnapshot, shopId: ShopId): number
	local definition = ShopCatalog.getShopDefinition(shopId)
	if not definition.usesStock then
		return 0
	end

	local state = snapshot.shopsById[shopId]
	if state == nil then
		return 0
	end

	return math.max(0, math.ceil(state.nextRestockAt - Workspace:GetServerTimeNow()))
end

local function syncSnapshotStockForShop(snapshot: ShopSnapshot, shopId: ShopId, shouldReset: boolean)
	local state = snapshot.shopsById[shopId]
	if state == nil then
		return
	end

	local validProductIds: { [ShopProductId]: boolean } = {}
	for _, productDefinition in ipairs(ShopCatalog.getShopProducts(shopId)) do
		validProductIds[productDefinition.id] = true
		if shouldReset or state.stockRemainingByProductId[productDefinition.id] == nil then
			state.stockRemainingByProductId[productDefinition.id] = productDefinition.stockPerRestock
		end
	end

	for productId in pairs(state.stockRemainingByProductId) do
		if validProductIds[productId] ~= true then
			state.stockRemainingByProductId[productId] = nil
		end
	end
end

local function notifyShopRestocked(shopId: ShopId)
	local definition = ShopCatalog.getShopDefinition(shopId)
	HudNotificationController.showToast(string.format("%s Restocked!", definition.displayName), "Success")
end

local function advanceRestockIfNeeded(snapshot: ShopSnapshot)
	local currentTime = Workspace:GetServerTimeNow()
	for _, shopId in ipairs(ShopCatalog.getShopIds()) do
		local definition = ShopCatalog.getShopDefinition(shopId)
		if not definition.usesStock then
			continue
		end

		local state = snapshot.shopsById[shopId]
		if state == nil then
			continue
		end

		local shouldReset = false
		while state.nextRestockAt <= currentTime do
			state.nextRestockAt += definition.restockIntervalSeconds
			shouldReset = true
		end

		syncSnapshotStockForShop(snapshot, shopId, shouldReset)
		if shouldReset and hasInitializedRestockNotifications then
			notifyShopRestocked(shopId)
		end
	end

	hasInitializedRestockNotifications = true
end

local function getAvailableCurrencyAmount(
	productDefinition: ShopProductDefinition,
	cash: number,
	resourceSnapshot: ResourceSnapshot?
): number
	if productDefinition.priceCurrency == "Cash" then
		return cash
	end

	if resourceSnapshot == nil then
		return 0
	end

	return resourceSnapshot.amountsByResourceId[productDefinition.priceCurrency :: ResourceId] or 0
end

local function buildRenderProducts(
	shopId: ShopId,
	snapshot: ShopSnapshot,
	cash: number,
	resourceSnapshot: ResourceSnapshot?
): { RenderProduct }
	local products: { RenderProduct } = {}
	local shopState = snapshot.shopsById[shopId]
	if shopState == nil then
		return products
	end
	local ownedProductIds: { [ShopProductId]: boolean } = snapshot.ownedProductIdsByShopId[shopId] or {}
	local shopDefinition = ShopCatalog.getShopDefinition(shopId)

	for _, productDefinition in ipairs(ShopCatalog.getShopProducts(shopId)) do
		local itemDefinition = ItemCatalog.getItemDefinition(productDefinition.itemId)
		local effectivePrice = if freeTutorialProductIdByShopId[shopId] == productDefinition.id
				or TutorialClientState.shouldUseFreePurchase(shopId, productDefinition.id)
			then 0
			else productDefinition.price
		local isOwned = ownedProductIds[productDefinition.id] == true
		local stockRemaining = if shopDefinition.usesStock then shopState.stockRemainingByProductId[productDefinition.id] or 0 else 1
		table.insert(products, {
			productDefinition = productDefinition,
			displayName = itemDefinition.displayName,
			stockRemaining = stockRemaining,
			canAfford = not isOwned and getAvailableCurrencyAmount(productDefinition, cash, resourceSnapshot) >= effectivePrice,
			effectivePrice = effectivePrice,
			isOwned = isOwned,
		})
	end

	table.sort(products, function(leftProduct, rightProduct)
		return leftProduct.productDefinition.sortOrder < rightProduct.productDefinition.sortOrder
	end)

	return products
end

local function formatPurchasedMessage(productDefinition: ShopProductDefinition): string
	local itemDefinition = ItemCatalog.getItemDefinition(productDefinition.itemId)
	return string.format("Bought %d %s!", productDefinition.quantityPerPurchase, itemDefinition.displayName)
end

local function formatInsufficientResourceMessage(productDefinition: ShopProductDefinition): string
	if productDefinition.priceCurrency == "Cash" then
		return "Not Enough Cash!"
	end

	local resourceDefinition = ResourceCatalog.getResourceDefinition(productDefinition.priceCurrency :: ResourceId)
	return string.format("Not Enough %s!", resourceDefinition.displayName)
end

local function getFailedPurchaseMessage(status: ShopPurchaseStatus, productDefinition: ShopProductDefinition?): string
	if status == "InsufficientCash" then
		return "Not Enough Cash!"
	elseif status == "InsufficientResources" and productDefinition ~= nil then
		return formatInsufficientResourceMessage(productDefinition)
	elseif status == "InsufficientResources" then
		return "Not Enough Resources!"
	elseif status == "OutOfStock" then
		return "Out Of Stock!"
	elseif status == "TooFar" then
		return "Too Far From Shop!"
	elseif status == "InvalidQuantity" then
		return "Invalid Quantity!"
	elseif status == "AlreadyOwned" then
		return "Already Owned!"
	elseif status == "InvalidProduct" then
		return "Invalid Product!"
	elseif status == "InvalidShop" then
		return "Invalid Shop!"
	end

	return "Purchase Failed!"
end

local function showPurchaseNotification(result: ShopPurchaseResult)
	local shopId = result.shopId
	local productId = result.productId
	local productDefinition = if shopId ~= nil and productId ~= nil
		then ShopCatalog.getShopProductDefinition(shopId, productId)
		else nil

	if result.success then
		if productDefinition ~= nil then
			HudNotificationController.showToast(formatPurchasedMessage(productDefinition), "Success")
		else
			HudNotificationController.showToast("Purchase Complete!", "Success")
		end
		return
	end

	HudNotificationController.showToast(getFailedPurchaseMessage(result.status, productDefinition), "Error")
end

local function renderIfReady(view: ShopMenuViewInstance)
	local shopId = activeShopId
	local snapshot = latestSnapshot
	if snapshot == nil then
		return
	end

	advanceRestockIfNeeded(snapshot)

	if shopId == nil then
		return
	end

	if not FrameManager.isOpen(shopId) then
		return
	end

	local definition = ShopCatalog.getShopDefinition(shopId)
	view:render(
		definition.id,
		getSecondsUntilRestock(snapshot, shopId),
		buildRenderProducts(shopId, snapshot, latestCash, latestResourceSnapshot)
	)
end

local ShopController = {}

function ShopController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local view = ShopMenuView.new()
	for _, shopId in ipairs(ShopCatalog.getShopIds()) do
		local panel = view:getFrame(shopId)
		FrameManager.registerFrame({
			id = shopId,
			frame = panel,
			group = MENU_FRAME_GROUP,
			defaultOpen = false,
			closedPosition = getClosedPanelPosition(panel),
		})
	end

	local shopOpened, shopClosed, getShopSnapshot, requestShopPurchase = getShopRemotes()
	local economyUpdated, getEconomySnapshot = getEconomyRemotes()
	local resourceUpdated, getResourceSnapshot = getResourceRemotes()
	latestSnapshot = getShopSnapshot:InvokeServer() :: ShopSnapshot
	local initialEconomySnapshot = getEconomySnapshot:InvokeServer() :: EconomySnapshot
	latestCash = initialEconomySnapshot.cash
	latestResourceSnapshot = getResourceSnapshot:InvokeServer() :: ResourceSnapshot

	view:connectCloseRequested(function(shopId: ShopId)
		freeTutorialProductIdByShopId[shopId] = nil
		if activeShopId == shopId then
			activeShopId = nil
		end
		FrameManager.close(shopId)
	end)
	FrameManager.observeFrameClosed(function(frameId: string)
		if ShopCatalog.isShopId(frameId) then
			if activeShopId == frameId then
				activeShopId = nil
			end
			shopClosed:FireServer(frameId)
		end
	end)

	view:connectPurchaseRequested(function(productId: ShopProductId)
		local shopId = activeShopId
		if shopId == nil or isPurchasePending then
			return
		end

		local shouldCloseAfterTutorialPurchase = freeTutorialProductIdByShopId[shopId] == productId
			or TutorialClientState.shouldUseFreePurchase(shopId, productId)
		isPurchasePending = true
		renderIfReady(view)

		local result = requestShopPurchase:InvokeServer({
			shopId = shopId,
			productId = productId,
		}) :: ShopPurchaseResult
		latestSnapshot = result.snapshot
		local refreshedEconomySnapshot = getEconomySnapshot:InvokeServer() :: EconomySnapshot
		latestCash = refreshedEconomySnapshot.cash
		latestResourceSnapshot = getResourceSnapshot:InvokeServer() :: ResourceSnapshot
		isPurchasePending = false
		renderIfReady(view)
		showPurchaseNotification(result)

		if result.success and shouldCloseAfterTutorialPurchase then
			freeTutorialProductIdByShopId[shopId] = nil
			FrameManager.close(shopId)
		end
	end)

	shopOpened.OnClientEvent:Connect(function(payload: ShopOpenedPayload)
		activeShopId = payload.shopId
		latestSnapshot = payload.snapshot
		if payload.freeTutorialProductId ~= nil then
			freeTutorialProductIdByShopId[payload.shopId] = payload.freeTutorialProductId
		else
			freeTutorialProductIdByShopId[payload.shopId] = nil
		end
		FrameManager.open(payload.shopId)
		renderIfReady(view)
	end)

	economyUpdated.OnClientEvent:Connect(function(economySnapshot: EconomySnapshot)
		latestCash = economySnapshot.cash
		renderIfReady(view)
	end)

	resourceUpdated.OnClientEvent:Connect(function(resourceSnapshot: ResourceSnapshot)
		latestResourceSnapshot = resourceSnapshot
		renderIfReady(view)
	end)

	task.spawn(function()
		while true do
			renderIfReady(view)
			task.wait(1)
		end
	end)
end

function ShopController.getLatestSnapshot(): ShopSnapshot?
	return latestSnapshot
end

return table.freeze(ShopController)

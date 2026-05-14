--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local economyFolder = sharedFolder:WaitForChild("Economy") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local shopsFolder = sharedFolder:WaitForChild("Shops") :: Folder

local EconomyTypes = require(economyFolder:WaitForChild("EconomyTypes") :: ModuleScript)
local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local ShopCatalog = require(shopsFolder:WaitForChild("ShopCatalog") :: ModuleScript)
local ShopTypes = require(shopsFolder:WaitForChild("ShopTypes") :: ModuleScript)
local FrameManager = require(script.Parent.Parent.UI.FrameManager)
local ShopMenuView = require(script.Parent.ShopMenuView)

type EconomySnapshot = EconomyTypes.EconomySnapshot
type ShopId = ShopTypes.ShopId
type ShopOpenedPayload = ShopTypes.ShopOpenedPayload
type ShopProductId = ShopTypes.ShopProductId
type ShopPurchaseResult = ShopTypes.ShopPurchaseResult
type ShopSnapshot = ShopTypes.ShopSnapshot
type RenderProduct = ShopMenuView.RenderProduct
type ShopMenuViewInstance = ShopMenuView.ShopMenuView

local SHOP_FRAME_ID = "ShopMenu"
local MENU_FRAME_GROUP = "Menu"
local hasStarted = false
local activeShopId: ShopId? = nil
local latestSnapshot: ShopSnapshot? = nil
local latestCash = 0
local latestLifetimeCashEarned = 0
local latestStatusText: string? = nil
local isPurchasePending = false

local PURCHASE_STATUS_TEXT: { [string]: string } = {
	Purchased = "Purchased",
	InvalidShop = "That shop is not available.",
	InvalidProduct = "That item is not sold here.",
	OutOfStock = "Sold out until the next restock.",
	InsufficientCash = "Not enough cash.",
	TooFar = "Move closer to the shop.",
	InvalidQuantity = "That item cannot be purchased right now.",
	Locked = "Earn more lifetime cash to unlock that item.",
}

local function getShopRemotes(): (RemoteEvent, RemoteFunction, RemoteFunction)
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local shopFolder = rootFolder:WaitForChild(RemoteNames.shopFolderName) :: Folder
	local shopOpened = shopFolder:WaitForChild(RemoteNames.shopOpenedEventName) :: RemoteEvent
	local getShopSnapshot = shopFolder:WaitForChild(RemoteNames.getShopSnapshotFunctionName) :: RemoteFunction
	local requestShopPurchase = shopFolder:WaitForChild(RemoteNames.requestShopPurchaseFunctionName) :: RemoteFunction
	return shopOpened, getShopSnapshot, requestShopPurchase
end

local function getEconomyRemotes(): (RemoteEvent, RemoteFunction)
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local economyRemoteFolder = rootFolder:WaitForChild(RemoteNames.economyFolderName) :: Folder
	local economyUpdated = economyRemoteFolder:WaitForChild(RemoteNames.economyUpdatedEventName) :: RemoteEvent
	local getEconomySnapshot = economyRemoteFolder:WaitForChild(RemoteNames.getEconomySnapshotFunctionName) :: RemoteFunction
	return economyUpdated, getEconomySnapshot
end

local function getClosedPanelPosition(panel: Frame): UDim2
	return UDim2.new(panel.Position.X.Scale, panel.Position.X.Offset, 1, 180)
end

local function getSecondsUntilRestock(snapshot: ShopSnapshot, shopId: ShopId): number
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

local function advanceRestockIfNeeded(snapshot: ShopSnapshot)
	local currentTime = Workspace:GetServerTimeNow()
	for _, shopId in ipairs(ShopCatalog.getShopIds()) do
		local state = snapshot.shopsById[shopId]
		if state == nil then
			continue
		end

		local definition = ShopCatalog.getShopDefinition(shopId)
		local shouldReset = false
		while state.nextRestockAt <= currentTime do
			state.nextRestockAt += definition.restockIntervalSeconds
			shouldReset = true
		end

		syncSnapshotStockForShop(snapshot, shopId, shouldReset)
	end
end

local function buildRenderProducts(shopId: ShopId, snapshot: ShopSnapshot, cash: number, lifetimeCashEarned: number): { RenderProduct }
	local products: { RenderProduct } = {}
	local shopState = snapshot.shopsById[shopId]
	if shopState == nil then
		return products
	end

	for _, productDefinition in ipairs(ShopCatalog.getShopProducts(shopId)) do
		local itemDefinition = ItemCatalog.getItemDefinition(productDefinition.itemId)
		local isUnlocked = lifetimeCashEarned >= productDefinition.unlockLifetimeCash
		table.insert(products, {
			productDefinition = productDefinition,
			displayName = itemDefinition.displayName,
			stockRemaining = shopState.stockRemainingByProductId[productDefinition.id] or 0,
			isUnlocked = isUnlocked,
			unlockLifetimeCash = productDefinition.unlockLifetimeCash,
			canAfford = cash >= productDefinition.price,
		})
	end

	table.sort(products, function(leftProduct, rightProduct)
		return leftProduct.productDefinition.sortOrder < rightProduct.productDefinition.sortOrder
	end)

	return products
end

local function renderIfReady(view: ShopMenuViewInstance)
	local shopId = activeShopId
	local snapshot = latestSnapshot
	if shopId == nil or snapshot == nil then
		return
	end

	advanceRestockIfNeeded(snapshot)

	local definition = ShopCatalog.getShopDefinition(shopId)
	view:render(
		definition.displayName,
		getSecondsUntilRestock(snapshot, shopId),
		latestCash,
		buildRenderProducts(shopId, snapshot, latestCash, latestLifetimeCashEarned),
		latestStatusText
	)
end

local function getPurchaseStatusText(result: ShopPurchaseResult): string
	return PURCHASE_STATUS_TEXT[result.status] or "Purchase failed."
end

local ShopController = {}

function ShopController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local view = ShopMenuView.new()
	local panel = view:getFrame()
	FrameManager.registerFrame({
		id = SHOP_FRAME_ID,
		frame = panel,
		group = MENU_FRAME_GROUP,
		defaultOpen = false,
		closedPosition = getClosedPanelPosition(panel),
	})

	local shopOpened, getShopSnapshot, requestShopPurchase = getShopRemotes()
	local economyUpdated, getEconomySnapshot = getEconomyRemotes()
	latestSnapshot = getShopSnapshot:InvokeServer() :: ShopSnapshot
	local initialEconomySnapshot = getEconomySnapshot:InvokeServer() :: EconomySnapshot
	latestCash = initialEconomySnapshot.cash
	latestLifetimeCashEarned = initialEconomySnapshot.lifetimeCashEarned

	view:connectCloseRequested(function()
		FrameManager.close(SHOP_FRAME_ID)
	end)

	view:connectPurchaseRequested(function(productId: ShopProductId)
		local shopId = activeShopId
		if shopId == nil or isPurchasePending then
			return
		end

		isPurchasePending = true
		latestStatusText = nil
		renderIfReady(view)

		local result = requestShopPurchase:InvokeServer({
			shopId = shopId,
			productId = productId,
		}) :: ShopPurchaseResult
		latestSnapshot = result.snapshot
		latestStatusText = getPurchaseStatusText(result)
		local refreshedEconomySnapshot = getEconomySnapshot:InvokeServer() :: EconomySnapshot
		latestCash = refreshedEconomySnapshot.cash
		latestLifetimeCashEarned = refreshedEconomySnapshot.lifetimeCashEarned
		isPurchasePending = false
		renderIfReady(view)
	end)

	shopOpened.OnClientEvent:Connect(function(payload: ShopOpenedPayload)
		activeShopId = payload.shopId
		latestSnapshot = payload.snapshot
		latestStatusText = nil
		renderIfReady(view)
		FrameManager.open(SHOP_FRAME_ID)
	end)

	economyUpdated.OnClientEvent:Connect(function(economySnapshot: EconomySnapshot)
		latestCash = economySnapshot.cash
		latestLifetimeCashEarned = economySnapshot.lifetimeCashEarned
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

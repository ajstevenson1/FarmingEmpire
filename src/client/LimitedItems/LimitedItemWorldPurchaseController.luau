--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local formattingFolder = sharedFolder:WaitForChild("Formatting") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local limitedItemsFolder = sharedFolder:WaitForChild("LimitedItems") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder

local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local LimitedItemCatalog = require(limitedItemsFolder:WaitForChild("LimitedItemCatalog") :: ModuleScript)
local LimitedItemTypes = require(limitedItemsFolder:WaitForChild("LimitedItemTypes") :: ModuleScript)
local NumberFormatter = require(formattingFolder:WaitForChild("NumberFormatter") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local HudNotificationController = require(script.Parent.Parent.Notifications.HudNotificationController)

type ItemId = InventoryTypes.ItemId
type LimitedItemsSnapshot = LimitedItemTypes.LimitedItemsSnapshot
type LimitedItemReserveResult = LimitedItemTypes.LimitedItemReserveResult

local ITEM_ID: ItemId = "PatriotTree"
local WORLD_MODEL_NAME = "PatriotTree"
local GUI_PART_NAME = "GUI"
local PROX_PART_NAME = "Prox"
local BILLBOARD_GUI_NAME = "BillboardGui"
local COUNT_LABEL_NAME = "Count"
local COST_LABEL_NAME = "Cost"
local SOLD_OUT_TEXT = "Sold Out!"
local SOLD_OUT_COLOR = Color3.fromRGB(255, 60, 60)
local ROBUX_ICON = string.char(0xEE, 0x80, 0x82)
local PRICE_UNAVAILABLE_TEXT = "Only " .. ROBUX_ICON .. "--!"

local hasStarted = false
local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before starting LimitedItemWorldPurchaseController")
local latestSnapshot: LimitedItemsSnapshot? = nil
local originalCountTextColor: Color3? = nil
local isPurchasePending = false
local pendingProductId: number? = nil
local pendingItemId: ItemId? = nil

local function getDefaultSnapshot(): LimitedItemsSnapshot
	local definition = LimitedItemCatalog.getDefinition(ITEM_ID)
	return {
		stockRemainingByItemId = {
			[ITEM_ID] = definition.maxStock,
		},
		maxStockByItemId = {
			[ITEM_ID] = definition.maxStock,
		},
	}
end

local function getLimitedItemRemotes(): (RemoteEvent, RemoteFunction, RemoteFunction, RemoteEvent)
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local limitedItemsRemoteFolder = rootFolder:WaitForChild(RemoteNames.limitedItemsFolderName) :: Folder
	local snapshotUpdated = limitedItemsRemoteFolder:WaitForChild(RemoteNames.limitedItemsSnapshotUpdatedEventName)
	local getSnapshot = limitedItemsRemoteFolder:WaitForChild(RemoteNames.getLimitedItemsSnapshotFunctionName)
	local reservePurchase = limitedItemsRemoteFolder:WaitForChild(RemoteNames.reserveLimitedItemPurchaseFunctionName)
	local releaseReservation = limitedItemsRemoteFolder:WaitForChild(RemoteNames.releaseLimitedItemReservationEventName)

	assert(snapshotUpdated:IsA("RemoteEvent"), "LimitedItemsSnapshotUpdated must be a RemoteEvent")
	assert(getSnapshot:IsA("RemoteFunction"), "GetLimitedItemsSnapshot must be a RemoteFunction")
	assert(reservePurchase:IsA("RemoteFunction"), "ReserveLimitedItemPurchase must be a RemoteFunction")
	assert(releaseReservation:IsA("RemoteEvent"), "ReleaseLimitedItemReservation must be a RemoteEvent")

	return snapshotUpdated, getSnapshot, reservePurchase, releaseReservation
end

local function getWorldWidgets(): (TextLabel?, TextLabel?, ProximityPrompt?)
	local worldModel = Workspace:WaitForChild(WORLD_MODEL_NAME, 10)
	if worldModel == nil then
		warn(string.format("[LimitedItemWorldPurchaseController] Missing Workspace.%s.", WORLD_MODEL_NAME))
		return nil, nil, nil
	end

	local guiPart = worldModel:WaitForChild(GUI_PART_NAME, 10)
	local proxPart = worldModel:WaitForChild(PROX_PART_NAME, 10)
	if guiPart == nil or proxPart == nil then
		warn(string.format("[LimitedItemWorldPurchaseController] %s needs GUI and Prox children.", worldModel:GetFullName()))
		return nil, nil, nil
	end

	local billboardGui = guiPart:FindFirstChild(BILLBOARD_GUI_NAME)
	if billboardGui == nil or not billboardGui:IsA("BillboardGui") then
		warn(string.format("[LimitedItemWorldPurchaseController] %s.%s needs a BillboardGui.", guiPart:GetFullName(), BILLBOARD_GUI_NAME))
		return nil, nil, nil
	end

	local rawCountLabel = billboardGui:FindFirstChild(COUNT_LABEL_NAME)
	local rawCostLabel = billboardGui:FindFirstChild(COST_LABEL_NAME)
	local prompt = proxPart:FindFirstChildWhichIsA("ProximityPrompt")
	local countLabel: TextLabel? = nil
	local costLabel: TextLabel? = nil

	if rawCountLabel ~= nil and rawCountLabel:IsA("TextLabel") then
		countLabel = rawCountLabel
	elseif rawCountLabel ~= nil then
		warn(string.format("[LimitedItemWorldPurchaseController] %s must be a TextLabel.", rawCountLabel:GetFullName()))
	end

	if rawCostLabel ~= nil and rawCostLabel:IsA("TextLabel") then
		costLabel = rawCostLabel
	elseif rawCostLabel ~= nil then
		warn(string.format("[LimitedItemWorldPurchaseController] %s must be a TextLabel.", rawCostLabel:GetFullName()))
	end

	if prompt == nil then
		warn(string.format("[LimitedItemWorldPurchaseController] %s needs a ProximityPrompt.", proxPart:GetFullName()))
	end

	return countLabel, costLabel, prompt
end

local function getStockRemaining(snapshot: LimitedItemsSnapshot?): number
	if snapshot == nil then
		return 0
	end

	return snapshot.stockRemainingByItemId[ITEM_ID] or 0
end

local function getMaxStock(snapshot: LimitedItemsSnapshot?): number
	if snapshot == nil then
		return LimitedItemCatalog.getDefinition(ITEM_ID).maxStock
	end

	return snapshot.maxStockByItemId[ITEM_ID] or LimitedItemCatalog.getDefinition(ITEM_ID).maxStock
end

local function fetchInitialSnapshot(getSnapshot: RemoteFunction): LimitedItemsSnapshot
	local success, snapshot = pcall(function()
		return getSnapshot:InvokeServer()
	end)

	if success and type(snapshot) == "table" then
		return snapshot :: LimitedItemsSnapshot
	end

	warn(string.format("[LimitedItemWorldPurchaseController] Failed to fetch limited item stock: %s", tostring(snapshot)))
	return getDefaultSnapshot()
end

local function formatRobuxPrice(priceInRobux: number): string
	return "Only " .. ROBUX_ICON .. NumberFormatter.formatFull(math.max(0, math.floor(priceInRobux))) .. "!"
end

local function updateCostText(costLabel: TextLabel?)
	if costLabel == nil then
		return
	end

	local definition = LimitedItemCatalog.getDefinition(ITEM_ID)
	if not LimitedItemCatalog.isConfigured(definition) then
		costLabel.Text = PRICE_UNAVAILABLE_TEXT
		return
	end

	task.spawn(function()
		local success, productInfo = pcall(function()
			return MarketplaceService:GetProductInfo(definition.developerProductId, Enum.InfoType.Product)
		end)

		if not success or type(productInfo) ~= "table" then
			costLabel.Text = PRICE_UNAVAILABLE_TEXT
			return
		end

		local productInfoValues = productInfo :: { [string]: unknown }
		local priceInRobux = productInfoValues.PriceInRobux
		costLabel.Text = if type(priceInRobux) == "number" then formatRobuxPrice(priceInRobux) else PRICE_UNAVAILABLE_TEXT
	end)
end

local function renderStock(countLabel: TextLabel?, prompt: ProximityPrompt?)
	local stockRemaining = getStockRemaining(latestSnapshot)
	local maxStock = getMaxStock(latestSnapshot)
	local isSoldOut = stockRemaining <= 0

	if countLabel ~= nil then
		if originalCountTextColor == nil then
			originalCountTextColor = countLabel.TextColor3
		end

		if isSoldOut then
			countLabel.Text = SOLD_OUT_TEXT
			countLabel.TextColor3 = SOLD_OUT_COLOR
		else
			countLabel.Text = string.format("%d/%d", stockRemaining, maxStock)
			countLabel.TextColor3 = originalCountTextColor :: Color3
		end
	end

	if prompt ~= nil then
		prompt.Enabled = not isSoldOut and not isPurchasePending
	end
end

local function showReserveFailureToast(status: string)
	if status == "SoldOut" then
		HudNotificationController.showToast("Sold Out!", "Error")
	elseif status == "Unavailable" then
		HudNotificationController.showToast("Purchase Unavailable!", "Error")
	else
		HudNotificationController.showToast("Purchase Failed!", "Error")
	end
end

local function handlePromptTriggered(
	reservePurchase: RemoteFunction,
	countLabel: TextLabel?,
	prompt: ProximityPrompt?
)
	if isPurchasePending or getStockRemaining(latestSnapshot) <= 0 then
		return
	end

	local definition = LimitedItemCatalog.getDefinition(ITEM_ID)
	if not LimitedItemCatalog.isConfigured(definition) then
		HudNotificationController.showToast("Purchase Unavailable!", "Error")
		return
	end

	isPurchasePending = true
	if prompt ~= nil then
		prompt.Enabled = false
	end

	local reserveSuccess, reserveResult = pcall(function()
		return reservePurchase:InvokeServer({
			itemId = ITEM_ID,
		})
	end)
	if not reserveSuccess or type(reserveResult) ~= "table" then
		isPurchasePending = false
		renderStock(countLabel, prompt)
		HudNotificationController.showToast("Purchase Failed!", "Error")
		return
	end

	local result = reserveResult :: LimitedItemReserveResult
	latestSnapshot = result.snapshot
	renderStock(countLabel, prompt)

	if not result.success or result.developerProductId == nil then
		isPurchasePending = false
		renderStock(countLabel, prompt)
		showReserveFailureToast(result.status)
		return
	end

	pendingProductId = result.developerProductId
	pendingItemId = ITEM_ID
	MarketplaceService:PromptProductPurchase(localPlayer, result.developerProductId)
end

local function runWorldPurchaseUi()
	local countLabel, costLabel, prompt = getWorldWidgets()
	local snapshotUpdated, getSnapshot, reservePurchase, releaseReservation = getLimitedItemRemotes()
	updateCostText(costLabel)

	latestSnapshot = fetchInitialSnapshot(getSnapshot)
	renderStock(countLabel, prompt)

	snapshotUpdated.OnClientEvent:Connect(function(snapshot: LimitedItemsSnapshot)
		latestSnapshot = snapshot
		renderStock(countLabel, prompt)
	end)

	if prompt ~= nil then
		prompt.Triggered:Connect(function()
			handlePromptTriggered(reservePurchase, countLabel, prompt)
		end)
	end

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, wasPurchased: boolean)
		if userId ~= localPlayer.UserId or productId ~= pendingProductId then
			return
		end

		local reservedItemId = pendingItemId
		pendingProductId = nil
		pendingItemId = nil
		isPurchasePending = false

		if not wasPurchased and reservedItemId ~= nil then
			releaseReservation:FireServer(reservedItemId)
		end

		renderStock(countLabel, prompt)
	end)
end

local LimitedItemWorldPurchaseController = {}

function LimitedItemWorldPurchaseController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	task.spawn(function()
		local success, errorMessage = pcall(runWorldPurchaseUi)
		if not success then
			warn(string.format("[LimitedItemWorldPurchaseController] Failed to start: %s", tostring(errorMessage)))
		end
	end)
end

return table.freeze(LimitedItemWorldPurchaseController)

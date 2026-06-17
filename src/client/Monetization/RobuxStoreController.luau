--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local formattingFolder = sharedFolder:WaitForChild("Formatting") :: Folder
local monetizationFolder = sharedFolder:WaitForChild("Monetization") :: Folder
local uiFolder = sharedFolder:WaitForChild("UI") :: Folder

local ButtonSoundConfig = require(uiFolder:WaitForChild("ButtonSoundConfig") :: ModuleScript)
local FrameManager = require(script.Parent.Parent.UI.FrameManager)
local HudNotificationController = require(script.Parent.Parent.Notifications.HudNotificationController)
local NumberFormatter = require(formattingFolder:WaitForChild("NumberFormatter") :: ModuleScript)
local RobuxStoreCatalog = require(monetizationFolder:WaitForChild("RobuxStoreCatalog") :: ModuleScript)
local RobuxStoreTypes = require(monetizationFolder:WaitForChild("RobuxStoreTypes") :: ModuleScript)

type RobuxStoreProductDefinition = RobuxStoreTypes.RobuxStoreProductDefinition
type RobuxStoreProductId = RobuxStoreTypes.RobuxStoreProductId
type GuiButtonLike = TextButton | ImageButton

type ProductWidgets = {
	container: GuiObject,
	robuxButton: GuiButtonLike,
	bestValueBadge: GuiObject?,
}

local ROOT_GUI_NAME = "GUI"
local HUD_NAME = "HUD"
local LEFT_CONTAINER_NAME = "Left"
local STORE_FRAME_ID = "RobuxStore"
local MENU_FRAME_GROUP = "Menu"
local SCROLLING_FRAME_NAME = "ScrollingFrame"
local LIST_NAME = "List"
local CASH_PACKS_NAME = "CashPacks"
local GRID_NAME = "Grid"
local ROBUX_BUTTON_NAME = "RobuxButton"
local BEST_VALUE_NAME = "BestValue"
local PRICE_LABEL_NAME = "Text"
local ROBUX_SYMBOL = ""
local UNCONFIGURED_PRICE_TEXT = "--"
local LOADING_PRICE_TEXT = "..."
local UNAVAILABLE_PRICE_TEXT = "N/A"

local CASH_PACK_FRAME_NAMES_BY_PRODUCT_ID: { [RobuxStoreProductId]: string } = {
	Cash25K = "25k",
	Cash150K = "150k",
	Cash800K = "800k",
	Cash10M = "10m",
}

local hasStarted = false
local productWidgetsById: { [RobuxStoreProductId]: ProductWidgets } = {}
local priceTextByDeveloperProductId: { [number]: string } = {}
local pendingPriceFetchByDeveloperProductId: { [number]: boolean } = {}

local function getRootGui(): ScreenGui
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before starting RobuxStoreController")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild(ROOT_GUI_NAME)
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")
	return rootGui
end

local function findGuiObjectChild(parent: Instance, childName: string): GuiObject?
	local child = parent:FindFirstChild(childName)
	if child == nil or not child:IsA("GuiObject") then
		return nil
	end

	return child
end

local function getRequiredGuiObjectChild(parent: Instance, childName: string): GuiObject
	local child = findGuiObjectChild(parent, childName)
	assert(child ~= nil, string.format("%s.%s must be a GuiObject", parent:GetFullName(), childName))
	return child :: GuiObject
end

local function getRequiredGuiButton(parent: Instance, childName: string): GuiButtonLike
	local child = parent:FindFirstChild(childName)
	assert(child ~= nil, string.format("%s.%s is required", parent:GetFullName(), childName))
	assert(
		child:IsA("TextButton") or child:IsA("ImageButton"),
		string.format("%s.%s must be a GuiButton", parent:GetFullName(), childName)
	)
	return child :: GuiButtonLike
end

local function findTextLabel(parent: Instance, childName: string): TextLabel?
	local child = parent:FindFirstChild(childName, true)
	if child == nil or not child:IsA("TextLabel") then
		return nil
	end

	return child
end

local function getOpenButton(rootGui: ScreenGui): GuiButtonLike
	local hud = getRequiredGuiObjectChild(rootGui, HUD_NAME)
	local leftContainer = getRequiredGuiObjectChild(hud, LEFT_CONTAINER_NAME)
	return getRequiredGuiButton(leftContainer, STORE_FRAME_ID)
end

local function getStoreFrame(rootGui: ScreenGui): Frame
	local directFrame = rootGui:FindFirstChild(STORE_FRAME_ID)
	if directFrame ~= nil then
		assert(directFrame:IsA("Frame"), "PlayerGui.GUI.RobuxStore must be a Frame")
		return directFrame :: Frame
	end

	local frames = rootGui:FindFirstChild("Frames")
	assert(frames ~= nil, "PlayerGui.GUI must contain RobuxStore or Frames.RobuxStore")
	local frame = frames:FindFirstChild(STORE_FRAME_ID)
	assert(frame ~= nil, "PlayerGui.GUI.Frames.RobuxStore is required")
	assert(frame:IsA("Frame"), "PlayerGui.GUI.Frames.RobuxStore must be a Frame")
	return frame :: Frame
end

local function getClosedPanelPosition(panel: Frame): UDim2
	local panelHeight = math.max(panel.AbsoluteSize.Y, panel.Size.Y.Offset, 64)
	return UDim2.new(panel.Position.X.Scale, panel.Position.X.Offset, 1, panelHeight + 48)
end

local function setButtonText(button: GuiButtonLike, text: string)
	local robuxText = ROBUX_SYMBOL .. " " .. text
	local priceLabel = findTextLabel(button, PRICE_LABEL_NAME)
	if priceLabel ~= nil then
		priceLabel.Text = robuxText
	elseif button:IsA("TextButton") then
		button.Text = robuxText
	end
end

local function setButtonAvailable(button: GuiButtonLike, isAvailable: boolean)
	button.Active = true
	button.AutoButtonColor = isAvailable
	button:SetAttribute(ButtonSoundConfig.SuppressSoundAttributeName, not isAvailable)
end

local function getPriceText(productDefinition: RobuxStoreProductDefinition): string
	if not RobuxStoreCatalog.isConfigured(productDefinition) then
		return UNCONFIGURED_PRICE_TEXT
	end

	return priceTextByDeveloperProductId[productDefinition.developerProductId] or LOADING_PRICE_TEXT
end

local function getCashPacksContainer(scrollingFrame: ScrollingFrame): GuiObject
	local directCashPacks = findGuiObjectChild(scrollingFrame, CASH_PACKS_NAME)
	if directCashPacks ~= nil then
		return directCashPacks
	end

	local list = findGuiObjectChild(scrollingFrame, LIST_NAME)
	assert(list ~= nil, string.format("%s must contain CashPacks or List.CashPacks", scrollingFrame:GetFullName()))
	local cashPacks = findGuiObjectChild(list, CASH_PACKS_NAME)
	assert(cashPacks ~= nil, string.format("%s.%s must be a GuiObject", list:GetFullName(), CASH_PACKS_NAME))
	return cashPacks :: GuiObject
end

local function getProductWidgets(storeFrame: Frame, productDefinition: RobuxStoreProductDefinition): ProductWidgets
	local scrollingFrame = getRequiredGuiObjectChild(storeFrame, SCROLLING_FRAME_NAME)
	assert(scrollingFrame:IsA("ScrollingFrame"), string.format("%s must be a ScrollingFrame", scrollingFrame:GetFullName()))

	local cashPacks = getCashPacksContainer(scrollingFrame :: ScrollingFrame)
	local grid = getRequiredGuiObjectChild(cashPacks, GRID_NAME)
	local frameName = CASH_PACK_FRAME_NAMES_BY_PRODUCT_ID[productDefinition.id]
	local container = getRequiredGuiObjectChild(grid, frameName)
	local robuxButton = getRequiredGuiButton(container, ROBUX_BUTTON_NAME)
	local bestValueBadge = findGuiObjectChild(container, BEST_VALUE_NAME)

	return {
		container = container,
		robuxButton = robuxButton,
		bestValueBadge = bestValueBadge,
	}
end

local function renderProduct(productDefinition: RobuxStoreProductDefinition)
	local widgets = productWidgetsById[productDefinition.id]
	if widgets == nil then
		return
	end

	widgets.container.LayoutOrder = productDefinition.sortOrder
	widgets.container.Visible = true
	if widgets.bestValueBadge ~= nil then
		widgets.bestValueBadge.Visible = productDefinition.isBestValue
	end

	local isConfigured = RobuxStoreCatalog.isConfigured(productDefinition)
	setButtonAvailable(widgets.robuxButton, isConfigured)
	setButtonText(widgets.robuxButton, getPriceText(productDefinition))
end

local function renderAllProducts()
	for _, productDefinition in ipairs(RobuxStoreCatalog.getCashPackProducts()) do
		renderProduct(productDefinition)
	end
end

local function fetchPriceAsync(productDefinition: RobuxStoreProductDefinition)
	if not RobuxStoreCatalog.isConfigured(productDefinition) then
		return
	end

	local developerProductId = productDefinition.developerProductId
	if priceTextByDeveloperProductId[developerProductId] ~= nil or pendingPriceFetchByDeveloperProductId[developerProductId] == true then
		return
	end

	pendingPriceFetchByDeveloperProductId[developerProductId] = true
	task.spawn(function()
		local success, result = pcall(function(): unknown
			return MarketplaceService:GetProductInfo(developerProductId, Enum.InfoType.Product)
		end)

		pendingPriceFetchByDeveloperProductId[developerProductId] = nil
		if not success or type(result) ~= "table" then
			priceTextByDeveloperProductId[developerProductId] = UNAVAILABLE_PRICE_TEXT
			renderProduct(productDefinition)
			return
		end

		local productInfo = result :: { [string]: unknown }
		local priceInRobux = productInfo.PriceInRobux
		if type(priceInRobux) ~= "number" then
			priceTextByDeveloperProductId[developerProductId] = UNAVAILABLE_PRICE_TEXT
			renderProduct(productDefinition)
			return
		end

		priceTextByDeveloperProductId[developerProductId] = NumberFormatter.formatFull(priceInRobux)
		renderProduct(productDefinition)
	end)
end

local function bindProductButton(productDefinition: RobuxStoreProductDefinition)
	local widgets = productWidgetsById[productDefinition.id]
	if widgets == nil then
		return
	end

	widgets.robuxButton.Activated:Connect(function()
		local localPlayer = Players.LocalPlayer
		if localPlayer == nil then
			return
		end

		if not RobuxStoreCatalog.isConfigured(productDefinition) then
			HudNotificationController.showToast("Purchase Unavailable!", "Error")
			return
		end

		MarketplaceService:PromptProductPurchase(localPlayer, productDefinition.developerProductId)
	end)
end

local function bindCloseButton(storeFrame: Frame)
	local closeButton = storeFrame:FindFirstChild("Close")
	if closeButton == nil or not (closeButton:IsA("TextButton") or closeButton:IsA("ImageButton")) then
		return
	end

	(closeButton :: GuiButtonLike).Activated:Connect(function()
		FrameManager.close(STORE_FRAME_ID)
	end)
end

local function bindProducts(storeFrame: Frame)
	for _, productDefinition in ipairs(RobuxStoreCatalog.getCashPackProducts()) do
		productWidgetsById[productDefinition.id] = getProductWidgets(storeFrame, productDefinition)
		bindProductButton(productDefinition)
		fetchPriceAsync(productDefinition)
	end

	renderAllProducts()
end

local RobuxStoreController = {}

function RobuxStoreController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local rootGui = getRootGui()
	local openButton = getOpenButton(rootGui)
	local storeFrame = getStoreFrame(rootGui)

	FrameManager.registerFrame({
		id = STORE_FRAME_ID,
		frame = storeFrame,
		group = MENU_FRAME_GROUP,
		defaultOpen = storeFrame.Visible,
		closedPosition = getClosedPanelPosition(storeFrame),
	})

	bindProducts(storeFrame)
	bindCloseButton(storeFrame)

	openButton.Activated:Connect(function()
		FrameManager.toggle(STORE_FRAME_ID)
	end)
end

return table.freeze(RobuxStoreController)

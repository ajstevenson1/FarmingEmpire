--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local formattingFolder = sharedFolder:WaitForChild("Formatting") :: Folder
local shopsFolder = sharedFolder:WaitForChild("Shops") :: Folder

local NumberFormatter = require(formattingFolder:WaitForChild("NumberFormatter") :: ModuleScript)
local ShopTypes = require(shopsFolder:WaitForChild("ShopTypes") :: ModuleScript)

type ShopId = ShopTypes.ShopId
type ShopProductDefinition = ShopTypes.ShopProductDefinition
type ShopProductId = ShopTypes.ShopProductId

export type RenderProduct = {
	productDefinition: ShopProductDefinition,
	displayName: string,
	stockRemaining: number,
	canAfford: boolean,
}

type ShopWidgets = {
	frame: Frame,
	template: GuiObject,
	scrollingFrame: ScrollingFrame,
	timerLabel: TextLabel,
	closeButton: GuiButton,
}

export type ShopMenuView = {
	_widgetsByShopId: { [ShopId]: ShopWidgets },
	_purchaseCallbacks: { (ShopProductId) -> () },
	_closeCallbacks: { (ShopId) -> () },
	_rowFramesByShopId: { [ShopId]: { GuiObject } },
	_robuxPriceTextByDeveloperProductId: { [string]: string },
	_pendingRobuxPriceFetchByDeveloperProductId: { [string]: boolean },
	getFrame: (self: ShopMenuView, shopId: ShopId) -> Frame,
	render: (self: ShopMenuView, shopId: ShopId, secondsUntilRestock: number, products: { RenderProduct }) -> (),
	connectCloseRequested: (self: ShopMenuView, listener: (ShopId) -> ()) -> (),
	connectPurchaseRequested: (self: ShopMenuView, listener: (ShopProductId) -> ()) -> (),
	destroy: (self: ShopMenuView) -> (),
}

local SHOP_FRAME_NAMES: { [ShopId]: string } = {
	TreesShop = "TreesShop",
	MillsShop = "MillsShop",
}

local TEMPLATE_NAMES: { [ShopId]: string } = {
	TreesShop = "TreesTemplate",
	MillsShop = "MillsTemplate",
}

local PRODUCT_IMAGE_PREFIX = "rbxassetid://"
local PRODUCT_THUMBNAIL_PREFIX = "rbxthumb://"
local ROBUX_PRICE_UNAVAILABLE_TEXT = "N/A"
local ROBUX_PRICE_LOADING_TEXT = "..."

local ShopMenuView = {}
ShopMenuView.__index = ShopMenuView

local function getRootGui(): ScreenGui
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before creating ShopMenuView")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild("GUI")
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")
	return rootGui
end

local function getFramesFolder(rootGui: ScreenGui): Instance
	local frames = rootGui:WaitForChild("Frames")
	assert(frames:IsA("GuiObject") or frames:IsA("Folder"), "PlayerGui.GUI.Frames must be a GuiObject or Folder")
	return frames
end

local function getTemplatesFolder(): Folder
	local templatesFolder = ReplicatedStorage:WaitForChild("Templates")
	assert(templatesFolder:IsA("Folder"), "ReplicatedStorage.Templates must be a Folder")
	return templatesFolder
end

local function findRequiredChild(parent: Instance, childName: string): Instance
	local child = parent:FindFirstChild(childName)
	assert(child ~= nil, string.format("%s.%s is required", parent:GetFullName(), childName))
	return child
end

local function findRequiredDescendant(parent: Instance, descendantName: string): Instance
	local descendant = parent:FindFirstChild(descendantName, true)
	assert(descendant ~= nil, string.format("%s must contain %s", parent:GetFullName(), descendantName))
	return descendant
end

local function findTextLabel(parent: Instance, name: string): TextLabel?
	local child = parent:FindFirstChild(name, true)
	if child ~= nil and child:IsA("TextLabel") then
		return child
	end

	return nil
end

local function setText(instance: Instance, text: string)
	if instance:IsA("TextLabel") then
		instance.Text = text
	elseif instance:IsA("TextButton") then
		instance.Text = text
	end
end

local function setRequiredNamedText(parent: Instance, name: string, text: string)
	setText(findRequiredDescendant(parent, name), text)
end

local function setButtonText(button: GuiButton, text: string)
	local mainText = findTextLabel(button, "Text")
	if mainText ~= nil then
		mainText.Text = text
	else
		setText(button, text)
	end

	local tripleText = findTextLabel(button, "TripleText")
	if tripleText ~= nil then
		tripleText.Text = text
	end
end

local function formatCash(cash: number): string
	return "$" .. NumberFormatter.formatAbbreviated(math.max(0, math.floor(cash)), {
		decimalPlaces = 1,
		trimTrailingZeros = true,
	})
end

local function formatStock(stockRemaining: number): string
	return string.format("Stock: %d", math.max(0, math.floor(stockRemaining)))
end

local function getImageAssetText(imageAssetId: string): string
	if imageAssetId == "" then
		return ""
	end

	if string.sub(imageAssetId, 1, #PRODUCT_IMAGE_PREFIX) == PRODUCT_IMAGE_PREFIX then
		return imageAssetId
	end

	if string.sub(imageAssetId, 1, #PRODUCT_THUMBNAIL_PREFIX) == PRODUCT_THUMBNAIL_PREFIX then
		return imageAssetId
	end

	return string.format("rbxthumb://type=Asset&id=%s&w=420&h=420", imageAssetId)
end

local function getDeveloperProductPriceText(developerProductId: string, priceCache: { [string]: string }): string
	if developerProductId == "" then
		return ROBUX_PRICE_UNAVAILABLE_TEXT
	end

	return priceCache[developerProductId] or ROBUX_PRICE_LOADING_TEXT
end

local function createShopWidgets(framesFolder: Instance, templatesFolder: Folder, shopId: ShopId): ShopWidgets
	local frame = findRequiredChild(framesFolder, SHOP_FRAME_NAMES[shopId])
	assert(frame:IsA("Frame"), string.format("%s must be a Frame", frame:GetFullName()))

	local template = findRequiredChild(templatesFolder, TEMPLATE_NAMES[shopId])
	assert(template:IsA("GuiObject"), string.format("%s must be a GuiObject", template:GetFullName()))
	template.Visible = false

	local design = findRequiredChild(frame, "Design")
	local timerLabel = findRequiredChild(design, "Timer")
	assert(timerLabel:IsA("TextLabel"), string.format("%s must be a TextLabel", timerLabel:GetFullName()))

	local scrollingFrame = findRequiredChild(frame, "ScrollingFrame")
	assert(scrollingFrame:IsA("ScrollingFrame"), string.format("%s must be a ScrollingFrame", scrollingFrame:GetFullName()))

	local closeButton = findRequiredChild(frame, "Close")
	assert(closeButton:IsA("GuiButton"), string.format("%s must be a GuiButton", closeButton:GetFullName()))

	return {
		frame = frame,
		template = template,
		scrollingFrame = scrollingFrame,
		timerLabel = timerLabel,
		closeButton = closeButton,
	}
end

local function fetchDeveloperProductPriceAsync(self: ShopMenuView, developerProductId: string)
	if developerProductId == "" then
		return
	end

	if self._robuxPriceTextByDeveloperProductId[developerProductId] ~= nil then
		return
	end

	if self._pendingRobuxPriceFetchByDeveloperProductId[developerProductId] == true then
		return
	end

	local productId = tonumber(developerProductId)
	if productId == nil then
		self._robuxPriceTextByDeveloperProductId[developerProductId] = ROBUX_PRICE_UNAVAILABLE_TEXT
		return
	end

	self._pendingRobuxPriceFetchByDeveloperProductId[developerProductId] = true
	task.spawn(function()
		local success, productInfo = pcall(function()
			return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
		end)

		self._pendingRobuxPriceFetchByDeveloperProductId[developerProductId] = nil
		if not success or type(productInfo) ~= "table" then
			self._robuxPriceTextByDeveloperProductId[developerProductId] = ROBUX_PRICE_UNAVAILABLE_TEXT
			return
		end

		local productInfoTable = productInfo :: { [string]: unknown }
		local priceInRobux = productInfoTable.PriceInRobux
		if type(priceInRobux) ~= "number" then
			self._robuxPriceTextByDeveloperProductId[developerProductId] = ROBUX_PRICE_UNAVAILABLE_TEXT
			return
		end

		self._robuxPriceTextByDeveloperProductId[developerProductId] = NumberFormatter.formatFull(priceInRobux)
	end)
end

local function createProductRow(
	self: ShopMenuView,
	shopWidgets: ShopWidgets,
	renderProduct: RenderProduct
): GuiObject
	local productDefinition = renderProduct.productDefinition
	local row = shopWidgets.template:Clone()
	row.Name = productDefinition.id
	row.LayoutOrder = productDefinition.sortOrder
	row.Visible = true
	row.Parent = shopWidgets.scrollingFrame

	local itemImage = findRequiredDescendant(row, "ItemImage")
	if itemImage:IsA("ImageLabel") then
		itemImage.Image = getImageAssetText(productDefinition.imageAssetId)
	elseif itemImage:IsA("ImageButton") then
		itemImage.Image = getImageAssetText(productDefinition.imageAssetId)
	else
		error(string.format("%s must be an ImageLabel or ImageButton", itemImage:GetFullName()))
	end

	setRequiredNamedText(row, "ItemName", renderProduct.displayName)
	setRequiredNamedText(row, "ItemStock", formatStock(renderProduct.stockRemaining))
	setRequiredNamedText(row, "ItemPrice", formatCash(productDefinition.price))

	local buyButton = findRequiredDescendant(row, "BuyButton")
	assert(buyButton:IsA("GuiButton"), string.format("%s must be a GuiButton", buyButton:GetFullName()))

	local isInStock = renderProduct.stockRemaining > 0
	local canBuy = isInStock and renderProduct.canAfford
	buyButton.Active = canBuy
	buyButton.AutoButtonColor = canBuy
	setButtonText(buyButton, formatCash(productDefinition.price))

	buyButton.Activated:Connect(function()
		if not canBuy then
			return
		end

		for _, callback in ipairs(self._purchaseCallbacks) do
			callback(productDefinition.id)
		end
	end)

	local robuxButton = findRequiredDescendant(row, "RobuxButton")
	assert(robuxButton:IsA("GuiButton"), string.format("%s must be a GuiButton", robuxButton:GetFullName()))
	setButtonText(
		robuxButton,
		getDeveloperProductPriceText(productDefinition.developerProductId, self._robuxPriceTextByDeveloperProductId)
	)
	fetchDeveloperProductPriceAsync(self, productDefinition.developerProductId)

	return row
end

function ShopMenuView.new(): ShopMenuView
	local rootGui = getRootGui()
	local framesFolder = getFramesFolder(rootGui)
	local templatesFolder = getTemplatesFolder()
	local widgetsByShopId: { [ShopId]: ShopWidgets } = {
		TreesShop = createShopWidgets(framesFolder, templatesFolder, "TreesShop"),
		MillsShop = createShopWidgets(framesFolder, templatesFolder, "MillsShop"),
	}

	local self = setmetatable({
		_widgetsByShopId = widgetsByShopId,
		_purchaseCallbacks = {},
		_closeCallbacks = {},
		_rowFramesByShopId = {
			TreesShop = {},
			MillsShop = {},
		},
		_robuxPriceTextByDeveloperProductId = {},
		_pendingRobuxPriceFetchByDeveloperProductId = {},
	}, ShopMenuView) :: ShopMenuView

	for shopId, shopWidgets in pairs(widgetsByShopId) do
		shopWidgets.closeButton.Activated:Connect(function()
			for _, callback in ipairs(self._closeCallbacks) do
				callback(shopId)
			end
		end)
	end

	return self
end

function ShopMenuView:getFrame(shopId: ShopId): Frame
	return self._widgetsByShopId[shopId].frame
end

function ShopMenuView:render(shopId: ShopId, secondsUntilRestock: number, products: { RenderProduct })
	local shopWidgets = self._widgetsByShopId[shopId]
	local minutes = math.floor(secondsUntilRestock / 60)
	local seconds = secondsUntilRestock % 60
	shopWidgets.timerLabel.Text = string.format("%02d:%02d", minutes, seconds)

	local rowFrames = self._rowFramesByShopId[shopId]
	for _, rowFrame in ipairs(rowFrames) do
		rowFrame:Destroy()
	end
	table.clear(rowFrames)

	for _, renderProduct in ipairs(products) do
		table.insert(rowFrames, createProductRow(self, shopWidgets, renderProduct))
	end
end

function ShopMenuView:connectCloseRequested(listener: (ShopId) -> ())
	table.insert(self._closeCallbacks, listener)
end

function ShopMenuView:connectPurchaseRequested(listener: (ShopProductId) -> ())
	table.insert(self._purchaseCallbacks, listener)
end

function ShopMenuView:destroy()
	for _, rowFrames in pairs(self._rowFramesByShopId) do
		for _, rowFrame in ipairs(rowFrames) do
			rowFrame:Destroy()
		end
		table.clear(rowFrames)
	end
end

return ShopMenuView

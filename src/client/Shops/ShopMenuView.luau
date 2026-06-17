--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local formattingFolder = sharedFolder:WaitForChild("Formatting") :: Folder
local progressionFolder = sharedFolder:WaitForChild("Progression") :: Folder
local shopsFolder = sharedFolder:WaitForChild("Shops") :: Folder
local uiFolder = sharedFolder:WaitForChild("UI") :: Folder
local windmillsFolder = sharedFolder:WaitForChild("Windmills") :: Folder

local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local ButtonSoundConfig = require(uiFolder:WaitForChild("ButtonSoundConfig") :: ModuleScript)
local NumberFormatter = require(formattingFolder:WaitForChild("NumberFormatter") :: ModuleScript)
local ProgressionConfig = require(progressionFolder:WaitForChild("ProgressionConfig") :: ModuleScript)
local ShopCatalog = require(shopsFolder:WaitForChild("ShopCatalog") :: ModuleScript)
local ShopTypes = require(shopsFolder:WaitForChild("ShopTypes") :: ModuleScript)
local WindmillConfig = require(windmillsFolder:WaitForChild("WindmillConfig") :: ModuleScript)

type BuildingId = BuildingTypes.BuildingId
type MillTierDefinition = ProgressionConfig.MillTierDefinition
type ShopId = ShopTypes.ShopId
type ShopProductDefinition = ShopTypes.ShopProductDefinition
type ShopProductId = ShopTypes.ShopProductId
type TreeTierDefinition = ProgressionConfig.TreeTierDefinition
type WindmillCategory = WindmillConfig.WindmillCategory

export type RenderProduct = {
	productDefinition: ShopProductDefinition,
	displayName: string,
	stockRemaining: number,
	canAfford: boolean,
	effectivePrice: number,
	isOwned: boolean,
}

type ShopWidgets = {
	frame: Frame,
	template: GuiObject,
	scrollingFrame: ScrollingFrame,
	timerLabel: TextLabel?,
	closeButton: GuiButton,
}

export type ShopMenuView = {
	_widgetsByShopId: { [ShopId]: ShopWidgets },
	_purchaseCallbacks: { (ShopProductId) -> () },
	_robuxPurchaseCallbacks: { (ShopProductId) -> () },
	_closeCallbacks: { (ShopId) -> () },
	_rowFramesByShopId: { [ShopId]: { [string]: GuiObject } },
	_robuxPriceTextByDeveloperProductId: { [string]: string },
	_pendingRobuxPriceFetchByDeveloperProductId: { [string]: boolean },
	getFrame: (self: ShopMenuView, shopId: ShopId) -> Frame,
	render: (self: ShopMenuView, shopId: ShopId, secondsUntilRestock: number, products: { RenderProduct }) -> (),
	connectCloseRequested: (self: ShopMenuView, listener: (ShopId) -> ()) -> (),
	connectPurchaseRequested: (self: ShopMenuView, listener: (ShopProductId) -> ()) -> (),
	connectRobuxPurchaseRequested: (self: ShopMenuView, listener: (ShopProductId) -> ()) -> (),
	destroy: (self: ShopMenuView) -> (),
}

local SHOP_FRAME_NAMES: { [ShopId]: string } = {
	TreesShop = "TreesShop",
	MillsShop = "MillsShop",
	WindmillShop = "WindmillShop",
}

local TEMPLATE_NAMES: { [ShopId]: string } = {
	TreesShop = "TreesTemplate",
	MillsShop = "MillsTemplate",
	WindmillShop = "WindmillTemplate",
}

local FALLBACK_SHOP_FRAME_NAMES: { [ShopId]: string } = {
	TreesShop = "TreesShop",
	MillsShop = "MillsShop",
	WindmillShop = "MillsShop",
}

local FALLBACK_TEMPLATE_NAMES: { [ShopId]: string } = {
	TreesShop = "TreesTemplate",
	MillsShop = "MillsTemplate",
	WindmillShop = "WindmillTemplate",
}

local WINDMILL_SHOP_ID: ShopId = "WindmillShop"
local WINDMILL_PRODUCT_TEMPLATE_NAME = "WindmillTemplate"
local WINDMILL_HEADER_TEMPLATE_BY_CATEGORY: { [WindmillCategory]: string } = {
	Offline = "OfflineTotemHeader",
	Cash = "CashTotemHeader",
}
local WINDMILL_CATEGORY_ORDER: { WindmillCategory } = { "Offline", "Cash" }
local ITEM_IMAGE_NAMES: { string } = { "ItemImage", "Image", "Icon" }
local ITEM_NAME_LABEL_NAMES: { string } = { "ItemName", "Name", "NameLabel", "Title", "TitleLabel" }
local ITEM_STOCK_LABEL_NAMES: { string } = { "ItemStock", "Stock", "StockLabel" }
local ITEM_PRICE_LABEL_NAMES: { string } = { "ItemPrice", "Price", "PriceLabel" }
local ITEM_DESCRIPTION_LABEL_NAMES: { string } = { "Desc", "Description", "DescriptionLabel" }
local PER_SECOND_LABEL_NAMES: { string } = { "PerSec" }
local BUY_BUTTON_NAMES: { string } = { "BuyButton", "Buy", "PurchaseButton", "Purchase" }
local ROBUX_BUTTON_NAMES: { string } = { "RobuxButton", "Robux", "PremiumButton" }
local GENERATED_WINDMILL_PRODUCT_ATTRIBUTE = "GeneratedWindmillProduct"
local WINDMILL_BUY_CONNECTED_ATTRIBUTE = "WindmillBuyConnected"
local WINDMILL_BUY_PRODUCT_ID_ATTRIBUTE = "WindmillBuyProductId"
local ROBUX_BUY_CONNECTED_ATTRIBUTE = "RobuxBuyConnected"

local PRODUCT_IMAGE_PREFIX = "rbxassetid://"
local PRODUCT_THUMBNAIL_PREFIX = "rbxthumb://"
local ROBUX_PRICE_UNAVAILABLE_TEXT = "N/A"
local ROBUX_PRICE_LOADING_TEXT = "..."
local ROBUX_PRICE_PREFIX = " "
local OWNED_BUTTON_TEXT = "Owned"
local OWNED_BUTTON_COLOR = Color3.fromRGB(37, 145, 65)

local productionRatePerSecondByProductId: { [ShopProductId]: number } = {}

for _, treeDefinition: TreeTierDefinition in ipairs(ProgressionConfig.getTreeDefinitions()) do
	productionRatePerSecondByProductId[treeDefinition.id :: ShopProductId] = treeDefinition.fruitPerInterval
		/ ProgressionConfig.getTreeProduceIntervalSeconds()
end

for _, millDefinition: MillTierDefinition in ipairs(ProgressionConfig.getMillDefinitions()) do
	productionRatePerSecondByProductId[millDefinition.id :: ShopProductId] = millDefinition.outputAmount
end

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

local function getOrCreatePlaceholderChild(parent: Instance, childName: string, fallbackChildName: string): Instance
	local child = parent:FindFirstChild(childName)
	if child ~= nil then
		return child
	end

	local fallbackChild = findRequiredChild(parent, fallbackChildName)
	local clonedChild = fallbackChild:Clone()
	clonedChild.Name = childName
	if clonedChild:IsA("GuiObject") then
		clonedChild.Visible = false
	end
	clonedChild.Parent = parent
	return clonedChild
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

local function findFirstGuiObject(root: Instance, names: { string }): GuiObject?
	for _, name in ipairs(names) do
		local candidate = root:FindFirstChild(name, true)
		if candidate ~= nil and candidate:IsA("GuiObject") then
			return candidate
		end
	end

	return nil
end

local function findFirstTextLabel(root: Instance, names: { string }): TextLabel?
	for _, name in ipairs(names) do
		local candidate = root:FindFirstChild(name, true)
		if candidate ~= nil and candidate:IsA("TextLabel") then
			return candidate
		end
	end

	return nil
end

local function findFirstGuiButton(root: Instance, names: { string }): GuiButton?
	for _, name in ipairs(names) do
		local candidate = root:FindFirstChild(name, true)
		if candidate ~= nil and candidate:IsA("GuiButton") then
			return candidate
		end
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

local function setOptionalNamedText(parent: Instance, names: { string }, text: string)
	local label = findFirstTextLabel(parent, names)
	if label ~= nil then
		label.Text = text
	end
end

local function setOptionalNamedTextVisible(parent: Instance, names: { string }, isVisible: boolean)
	local label = findFirstTextLabel(parent, names)
	if label ~= nil then
		label.Visible = isVisible
	end
end

local function setOptionalGuiButtonVisible(parent: Instance, names: { string }, isVisible: boolean)
	local button = findFirstGuiButton(parent, names)
	if button == nil then
		return
	end

	button.Visible = isVisible
	button.Active = isVisible
	if not isVisible then
		button:SetAttribute(ButtonSoundConfig.SuppressSoundAttributeName, true)
	end
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

local function setGuiBackgroundColor(instance: Instance, color: Color3)
	if instance:IsA("GuiObject") then
		instance.BackgroundColor3 = color
	end
end

local function applyOwnedButtonState(button: GuiButton)
	button.Active = false
	button.AutoButtonColor = false
	button:SetAttribute(ButtonSoundConfig.SuppressSoundAttributeName, true)
	setButtonText(button, OWNED_BUTTON_TEXT)
	setGuiBackgroundColor(button, OWNED_BUTTON_COLOR)

	local design = button:FindFirstChild("Design")
	if design ~= nil then
		setGuiBackgroundColor(design, OWNED_BUTTON_COLOR)
	end
end

local function formatCash(cash: number): string
	return "$" .. NumberFormatter.formatAbbreviated(math.max(0, math.floor(cash)), {
		decimalPlaces = 1,
		trimTrailingZeros = true,
	})
end

local function formatPlainAmount(amount: number): string
	return NumberFormatter.formatAbbreviated(math.max(0, math.floor(amount)), {
		decimalPlaces = 1,
		trimTrailingZeros = true,
	})
end

local function formatPerSecond(ratePerSecond: number): string
	return string.format("%s/s", NumberFormatter.formatAbbreviated(math.max(0, ratePerSecond), {
		decimalPlaces = 1,
		trimTrailingZeros = true,
	}))
end

local function formatPercent(percent: number): string
	local roundedWholePercent = math.floor(percent + 0.5)
	if math.abs(percent - roundedWholePercent) < 0.05 then
		return tostring(roundedWholePercent)
	end

	return NumberFormatter.formatAbbreviated(math.max(0, percent), {
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

local function getDeveloperProductPriceText(developerProductId: number?, priceCache: { [string]: string }): string
	if developerProductId == nil then
		return ROBUX_PRICE_UNAVAILABLE_TEXT
	end

	local priceText = priceCache[tostring(developerProductId)] or ROBUX_PRICE_LOADING_TEXT
	if priceText == ROBUX_PRICE_UNAVAILABLE_TEXT then
		return ROBUX_PRICE_UNAVAILABLE_TEXT
	end

	return ROBUX_PRICE_PREFIX .. priceText
end

local function createShopWidgets(framesFolder: Instance, templatesFolder: Folder, shopId: ShopId): ShopWidgets
	local frame = getOrCreatePlaceholderChild(framesFolder, SHOP_FRAME_NAMES[shopId], FALLBACK_SHOP_FRAME_NAMES[shopId])
	assert(frame:IsA("Frame"), string.format("%s must be a Frame", frame:GetFullName()))

	local template = getOrCreatePlaceholderChild(templatesFolder, TEMPLATE_NAMES[shopId], FALLBACK_TEMPLATE_NAMES[shopId])
	assert(template:IsA("GuiObject"), string.format("%s must be a GuiObject", template:GetFullName()))
	template.Visible = false

	local design = findRequiredChild(frame, "Design")
	local timerLabel: TextLabel? = nil
	local timerChild = design:FindFirstChild("Timer")
	if timerChild ~= nil then
		assert(timerChild:IsA("TextLabel"), string.format("%s must be a TextLabel", timerChild:GetFullName()))
		timerLabel = timerChild
	elseif ShopCatalog.getShopDefinition(shopId).usesStock then
		error(string.format("%s.Timer is required for stocked shops.", design:GetFullName()))
	end

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

local function fetchDeveloperProductPriceAsync(self: ShopMenuView, developerProductId: number?)
	if developerProductId == nil then
		return
	end

	local developerProductIdKey = tostring(developerProductId)
	if self._robuxPriceTextByDeveloperProductId[developerProductIdKey] ~= nil then
		return
	end

	if self._pendingRobuxPriceFetchByDeveloperProductId[developerProductIdKey] == true then
		return
	end

	self._pendingRobuxPriceFetchByDeveloperProductId[developerProductIdKey] = true
	task.spawn(function()
		local success, productInfo = pcall(function()
			return MarketplaceService:GetProductInfo(developerProductId, Enum.InfoType.Product)
		end)

		self._pendingRobuxPriceFetchByDeveloperProductId[developerProductIdKey] = nil
		if not success or type(productInfo) ~= "table" then
			self._robuxPriceTextByDeveloperProductId[developerProductIdKey] = ROBUX_PRICE_UNAVAILABLE_TEXT
			return
		end

		local productInfoTable = productInfo :: { [string]: unknown }
		local priceInRobux = productInfoTable.PriceInRobux
		if type(priceInRobux) ~= "number" then
			self._robuxPriceTextByDeveloperProductId[developerProductIdKey] = ROBUX_PRICE_UNAVAILABLE_TEXT
			return
		end

		self._robuxPriceTextByDeveloperProductId[developerProductIdKey] = NumberFormatter.formatFull(priceInRobux)
	end)
end

local function getWindmillCategory(renderProduct: RenderProduct): WindmillCategory?
	local itemId = renderProduct.productDefinition.itemId
	if not WindmillConfig.isWindmillBuildingId(itemId) then
		return nil
	end

	local windmillDefinition = WindmillConfig.getDefinition(itemId :: BuildingId)
	return if windmillDefinition == nil then nil else windmillDefinition.category
end

local function getWindmillDescriptionText(renderProduct: RenderProduct): string
	local itemId = renderProduct.productDefinition.itemId
	if not WindmillConfig.isWindmillBuildingId(itemId) then
		return ""
	end

	local windmillDefinition = WindmillConfig.getDefinition(itemId :: BuildingId)
	if windmillDefinition == nil then
		return ""
	end

	local category = windmillDefinition.category
	local boost = if category == "Offline"
		then windmillDefinition.boosts.offlineEarningsMultiplierBonus
		else windmillDefinition.boosts.ciderSellCashMultiplierBonus

	return string.format("+%s%% %s", formatPercent(boost * 100), category)
end

local function groupWindmillProductsByCategory(products: { RenderProduct }): { [WindmillCategory]: { RenderProduct } }
	local groupedProducts: { [WindmillCategory]: { RenderProduct } } = {
		Offline = {},
		Cash = {},
	}

	for _, renderProduct in ipairs(products) do
		local category = getWindmillCategory(renderProduct)
		if category ~= nil then
			table.insert(groupedProducts[category], renderProduct)
		end
	end

	for _, categoryProducts in pairs(groupedProducts) do
		table.sort(categoryProducts, function(leftProduct: RenderProduct, rightProduct: RenderProduct): boolean
			if leftProduct.productDefinition.price == rightProduct.productDefinition.price then
				return leftProduct.displayName < rightProduct.displayName
			end

			return leftProduct.productDefinition.price < rightProduct.productDefinition.price
		end)
	end

	return groupedProducts
end

local function setProductImage(row: GuiObject, imageAssetId: string)
	local imageTarget = findFirstGuiObject(row, ITEM_IMAGE_NAMES)
	if imageTarget == nil then
		return
	end

	local imageText = getImageAssetText(imageAssetId)
	if imageTarget:IsA("ImageLabel") then
		imageTarget.Image = imageText
	elseif imageTarget:IsA("ImageButton") then
		imageTarget.Image = imageText
	end
end

local function connectProductBuyButton(self: ShopMenuView, row: GuiObject, renderProduct: RenderProduct)
	local buyButton = findFirstGuiButton(row, BUY_BUTTON_NAMES)
	if buyButton == nil then
		return
	end

	buyButton:SetAttribute(WINDMILL_BUY_PRODUCT_ID_ATTRIBUTE, renderProduct.productDefinition.id)
	if renderProduct.isOwned then
		applyOwnedButtonState(buyButton)
		return
	end

	local isInStock = renderProduct.stockRemaining > 0
	local canBuy = isInStock and renderProduct.canAfford
	buyButton.Active = true
	buyButton.AutoButtonColor = canBuy
	buyButton:SetAttribute(ButtonSoundConfig.SuppressSoundAttributeName, not canBuy)
	setButtonText(buyButton, formatPlainAmount(renderProduct.effectivePrice))

	if buyButton:GetAttribute(WINDMILL_BUY_CONNECTED_ATTRIBUTE) == true then
		return
	end

	buyButton:SetAttribute(WINDMILL_BUY_CONNECTED_ATTRIBUTE, true)
	buyButton.Activated:Connect(function()
		local productId = buyButton:GetAttribute(WINDMILL_BUY_PRODUCT_ID_ATTRIBUTE)
		if type(productId) ~= "string" then
			return
		end

		for _, callback in ipairs(self._purchaseCallbacks) do
			callback(productId :: ShopProductId)
		end
	end)
end

local function populateWindmillProductRow(self: ShopMenuView, row: GuiObject, renderProduct: RenderProduct)
	row.Name = renderProduct.productDefinition.id
	row.Visible = true
	setProductImage(row, renderProduct.productDefinition.imageAssetId)
	setOptionalNamedText(row, ITEM_NAME_LABEL_NAMES, renderProduct.displayName)
	setOptionalNamedText(row, ITEM_DESCRIPTION_LABEL_NAMES, getWindmillDescriptionText(renderProduct))
	setOptionalNamedTextVisible(row, ITEM_STOCK_LABEL_NAMES, false)
	setOptionalNamedText(
		row,
		ITEM_PRICE_LABEL_NAMES,
		if renderProduct.isOwned then OWNED_BUTTON_TEXT else formatPlainAmount(renderProduct.effectivePrice)
	)
	setOptionalGuiButtonVisible(row, ROBUX_BUTTON_NAMES, not renderProduct.isOwned)
	connectProductBuyButton(self, row, renderProduct)
end

local function createWindmillProductRow(
	self: ShopMenuView,
	renderProduct: RenderProduct,
	layoutOrder: number
): GuiObject
	local category = getWindmillCategory(renderProduct)
	assert(category ~= nil, string.format("%s is not a windmill product", renderProduct.productDefinition.id))

	local templateName = WINDMILL_PRODUCT_TEMPLATE_NAME
	local template = getTemplatesFolder():WaitForChild(templateName)
	assert(template:IsA("GuiObject"), string.format("Templates.%s must be a GuiObject", templateName))

	local row = template:Clone()
	row.LayoutOrder = layoutOrder
	populateWindmillProductRow(self, row, renderProduct)
	row:SetAttribute(GENERATED_WINDMILL_PRODUCT_ATTRIBUTE, true)

	return row
end

local function createWindmillCategoryHeader(category: WindmillCategory, layoutOrder: number): GuiObject
	local templateName = WINDMILL_HEADER_TEMPLATE_BY_CATEGORY[category]
	local template = getTemplatesFolder():WaitForChild(templateName)
	assert(template:IsA("GuiObject"), string.format("Templates.%s must be a GuiObject", templateName))

	local header = template:Clone()
	header.Name = templateName
	header.LayoutOrder = layoutOrder
	header.Visible = true
	header:SetAttribute(GENERATED_WINDMILL_PRODUCT_ATTRIBUTE, true)

	return header
end

local function renderWindmillProducts(
	self: ShopMenuView,
	shopWidgets: ShopWidgets,
	products: { RenderProduct },
	activeRowKeys: { [string]: boolean }
)
	local groupedProducts = groupWindmillProductsByCategory(products)
	local layoutOrder = 1
	local rowFrames = self._rowFramesByShopId[WINDMILL_SHOP_ID]

	for _, category in ipairs(WINDMILL_CATEGORY_ORDER) do
		local headerKey = "Header:" .. category
		activeRowKeys[headerKey] = true

		local header = rowFrames[headerKey]
		if header == nil then
			header = createWindmillCategoryHeader(category, layoutOrder)
			header.Parent = shopWidgets.scrollingFrame
			rowFrames[headerKey] = header
		else
			header.LayoutOrder = layoutOrder
			header.Visible = true
		end
		layoutOrder += 1

		local categoryProducts = groupedProducts[category]
		for index, renderProduct in ipairs(categoryProducts) do
			local productKey = renderProduct.productDefinition.id
			activeRowKeys[productKey] = true

			local row = rowFrames[productKey]
			if row == nil then
				row = createWindmillProductRow(self, renderProduct, layoutOrder + index - 1)
				row.Parent = shopWidgets.scrollingFrame
				rowFrames[productKey] = row
			else
				row.LayoutOrder = layoutOrder + index - 1
				populateWindmillProductRow(self, row, renderProduct)
			end
		end

		layoutOrder += #categoryProducts
	end
end

local function populateProductRow(
	self: ShopMenuView,
	row: GuiObject,
	renderProduct: RenderProduct
)
	local productDefinition = renderProduct.productDefinition
	row.Name = productDefinition.id
	row.LayoutOrder = productDefinition.sortOrder
	row.Visible = true

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
	setRequiredNamedText(row, "ItemPrice", formatCash(renderProduct.effectivePrice))
	local ratePerSecond = productionRatePerSecondByProductId[productDefinition.id]
	setOptionalNamedText(row, PER_SECOND_LABEL_NAMES, if ratePerSecond == nil then "" else formatPerSecond(ratePerSecond))

	local buyButton = findRequiredDescendant(row, "BuyButton")
	assert(buyButton:IsA("GuiButton"), string.format("%s must be a GuiButton", buyButton:GetFullName()))

	local isInStock = renderProduct.stockRemaining > 0
	local canBuy = isInStock and renderProduct.canAfford
	buyButton.Active = true
	buyButton.AutoButtonColor = canBuy
	buyButton:SetAttribute(ButtonSoundConfig.SuppressSoundAttributeName, not canBuy)
	setButtonText(buyButton, formatCash(renderProduct.effectivePrice))

	local robuxButton = findRequiredDescendant(row, "RobuxButton")
	assert(robuxButton:IsA("GuiButton"), string.format("%s must be a GuiButton", robuxButton:GetFullName()))
	local canBuyWithRobux = productDefinition.developerProductId ~= nil and isInStock
	robuxButton.Active = canBuyWithRobux
	robuxButton.AutoButtonColor = canBuyWithRobux
	robuxButton:SetAttribute(ButtonSoundConfig.SuppressSoundAttributeName, not canBuyWithRobux)
	setButtonText(
		robuxButton,
		getDeveloperProductPriceText(productDefinition.developerProductId, self._robuxPriceTextByDeveloperProductId)
	)
	fetchDeveloperProductPriceAsync(self, productDefinition.developerProductId)
end

local function createProductRow(
	self: ShopMenuView,
	shopWidgets: ShopWidgets,
	renderProduct: RenderProduct
): GuiObject
	local productDefinition = renderProduct.productDefinition
	local row = shopWidgets.template:Clone()
	row.Parent = shopWidgets.scrollingFrame

	populateProductRow(self, row, renderProduct)

	local buyButton = findRequiredDescendant(row, "BuyButton")
	assert(buyButton:IsA("GuiButton"), string.format("%s must be a GuiButton", buyButton:GetFullName()))
	local robuxButton = findRequiredDescendant(row, "RobuxButton")
	assert(robuxButton:IsA("GuiButton"), string.format("%s must be a GuiButton", robuxButton:GetFullName()))

	buyButton.Activated:Connect(function()
		for _, callback in ipairs(self._purchaseCallbacks) do
			callback(productDefinition.id)
		end
	end)

	if robuxButton:GetAttribute(ROBUX_BUY_CONNECTED_ATTRIBUTE) ~= true then
		robuxButton:SetAttribute(ROBUX_BUY_CONNECTED_ATTRIBUTE, true)
		robuxButton.Activated:Connect(function()
			if productDefinition.developerProductId == nil then
				return
			end

			for _, callback in ipairs(self._robuxPurchaseCallbacks) do
				callback(productDefinition.id)
			end
		end)
	end

	return row
end

function ShopMenuView.new(): ShopMenuView
	local rootGui = getRootGui()
	local framesFolder = getFramesFolder(rootGui)
	local templatesFolder = getTemplatesFolder()
	local widgetsByShopId: { [ShopId]: ShopWidgets } = {
		TreesShop = createShopWidgets(framesFolder, templatesFolder, "TreesShop"),
		MillsShop = createShopWidgets(framesFolder, templatesFolder, "MillsShop"),
		WindmillShop = createShopWidgets(framesFolder, templatesFolder, "WindmillShop"),
	}

	local self = setmetatable({
		_widgetsByShopId = widgetsByShopId,
		_purchaseCallbacks = {},
		_robuxPurchaseCallbacks = {},
		_closeCallbacks = {},
		_rowFramesByShopId = {
			TreesShop = {},
			MillsShop = {},
			WindmillShop = {},
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
	if shopWidgets.timerLabel ~= nil then
		shopWidgets.timerLabel.Visible = ShopCatalog.getShopDefinition(shopId).usesStock
		shopWidgets.timerLabel.Text = string.format("%02d:%02d", minutes, seconds)
	end

	local rowFrames = self._rowFramesByShopId[shopId]
	local activeRowKeys: { [string]: boolean } = {}

	if shopId == WINDMILL_SHOP_ID then
		renderWindmillProducts(self, shopWidgets, products, activeRowKeys)
	else
		for _, renderProduct in ipairs(products) do
			local productKey = renderProduct.productDefinition.id
			activeRowKeys[productKey] = true

			local row = rowFrames[productKey]
			if row == nil then
				rowFrames[productKey] = createProductRow(self, shopWidgets, renderProduct)
			else
				populateProductRow(self, row, renderProduct)
			end
		end
	end

	for rowKey, rowFrame in pairs(rowFrames) do
		if activeRowKeys[rowKey] ~= true then
			rowFrame:Destroy()
			rowFrames[rowKey] = nil
		end
	end
end

function ShopMenuView:connectCloseRequested(listener: (ShopId) -> ())
	table.insert(self._closeCallbacks, listener)
end

function ShopMenuView:connectPurchaseRequested(listener: (ShopProductId) -> ())
	table.insert(self._purchaseCallbacks, listener)
end

function ShopMenuView:connectRobuxPurchaseRequested(listener: (ShopProductId) -> ())
	table.insert(self._robuxPurchaseCallbacks, listener)
end

function ShopMenuView:destroy()
	for _, rowFrames in pairs(self._rowFramesByShopId) do
		for _, rowFrame in pairs(rowFrames) do
			rowFrame:Destroy()
		end
		table.clear(rowFrames)
	end
end

return ShopMenuView

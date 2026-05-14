--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local formattingFolder = sharedFolder:WaitForChild("Formatting") :: Folder
local shopsFolder = sharedFolder:WaitForChild("Shops") :: Folder

local NumberFormatter = require(formattingFolder:WaitForChild("NumberFormatter") :: ModuleScript)
local ShopTypes = require(shopsFolder:WaitForChild("ShopTypes") :: ModuleScript)

type ShopProductDefinition = ShopTypes.ShopProductDefinition
type ShopProductId = ShopTypes.ShopProductId

export type RenderProduct = {
	productDefinition: ShopProductDefinition,
	displayName: string,
	stockRemaining: number,
	canAfford: boolean,
	isUnlocked: boolean,
	unlockLifetimeCash: number,
}

type Widgets = {
	rootGui: ScreenGui,
	frame: Frame,
	headerFrame: Frame,
	titleLabel: TextLabel,
	timerLabel: TextLabel,
	cashLabel: TextLabel,
	productList: ScrollingFrame,
	statusLabel: TextLabel,
	closeButton: TextButton,
}

export type ShopMenuView = {
	_widgets: Widgets,
	_purchaseCallbacks: { (ShopProductId) -> () },
	_rowFrames: { Frame },
	getFrame: (self: ShopMenuView) -> Frame,
	render: (
		self: ShopMenuView,
		shopName: string,
		secondsUntilRestock: number,
		cash: number,
		products: { RenderProduct },
		statusText: string?
	) -> (),
	connectCloseRequested: (self: ShopMenuView, listener: () -> ()) -> RBXScriptConnection,
	connectPurchaseRequested: (self: ShopMenuView, listener: (ShopProductId) -> ()) -> (),
	destroy: (self: ShopMenuView) -> (),
}

local FRAME_SIZE = UDim2.fromOffset(560, 430)
local PANEL_COLOR = Color3.fromRGB(32, 28, 22)
local ROW_COLOR = Color3.fromRGB(44, 38, 30)
local ROW_MUTED_COLOR = Color3.fromRGB(38, 34, 29)
local PANEL_STROKE_COLOR = Color3.fromRGB(158, 126, 69)
local TEXT_COLOR = Color3.fromRGB(250, 244, 232)
local MUTED_TEXT_COLOR = Color3.fromRGB(219, 205, 180)
local BUTTON_COLOR = Color3.fromRGB(176, 113, 51)
local BUTTON_DISABLED_COLOR = Color3.fromRGB(92, 80, 68)
local SUCCESS_COLOR = Color3.fromRGB(136, 218, 135)
local WARNING_COLOR = Color3.fromRGB(237, 177, 93)

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

local function getFrameParent(rootGui: ScreenGui): Instance
	local frames = rootGui:WaitForChild("Frames", 10)
	if frames ~= nil and frames:IsA("GuiObject") then
		return frames
	end

	return rootGui
end

local function formatCash(cash: number): string
	return "$" .. NumberFormatter.formatAbbreviated(math.max(0, math.floor(cash)), {
		decimalPlaces = 1,
		trimTrailingZeros = true,
	})
end

local function createLabel(parent: Instance, name: string, textSize: number, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = font
	label.Text = ""
	label.TextColor3 = TEXT_COLOR
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function applyCorner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function applyStroke(parent: GuiObject, color: Color3, transparency: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 1
	stroke.Transparency = transparency
	stroke.Parent = parent
end

local function createWidgets(): Widgets
	local rootGui = getRootGui()
	local frameParent = getFrameParent(rootGui)

	local frame = Instance.new("Frame")
	frame.Name = "ShopMenu"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = FRAME_SIZE
	frame.BackgroundColor3 = PANEL_COLOR
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = frameParent
	applyCorner(frame, 8)
	applyStroke(frame, PANEL_STROKE_COLOR, 0.12)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 16)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "Header"
	headerFrame.BackgroundTransparency = 1
	headerFrame.LayoutOrder = 0
	headerFrame.Size = UDim2.new(1, 0, 0, 54)
	headerFrame.Parent = frame

	local titleLabel = createLabel(headerFrame, "TitleLabel", 24, Enum.Font.GothamBold)
	titleLabel.Position = UDim2.fromOffset(0, 0)
	titleLabel.Size = UDim2.new(1, -160, 0, 30)

	local timerLabel = createLabel(headerFrame, "TimerLabel", 15, Enum.Font.GothamMedium)
	timerLabel.Position = UDim2.fromOffset(0, 31)
	timerLabel.Size = UDim2.new(1, -160, 0, 22)
	timerLabel.TextColor3 = MUTED_TEXT_COLOR

	local cashLabel = createLabel(headerFrame, "CashLabel", 18, Enum.Font.GothamBold)
	cashLabel.AnchorPoint = Vector2.new(1, 0)
	cashLabel.Position = UDim2.new(1, 0, 0, 5)
	cashLabel.Size = UDim2.fromOffset(150, 26)
	cashLabel.TextXAlignment = Enum.TextXAlignment.Right

	local productList = Instance.new("ScrollingFrame")
	productList.Name = "ProductList"
	productList.LayoutOrder = 1
	productList.Size = UDim2.new(1, 0, 0, 246)
	productList.BackgroundTransparency = 1
	productList.BorderSizePixel = 0
	productList.ScrollBarThickness = 5
	productList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	productList.CanvasSize = UDim2.fromOffset(0, 0)
	productList.Parent = frame

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = productList

	local statusLabel = createLabel(frame, "StatusLabel", 14, Enum.Font.GothamMedium)
	statusLabel.LayoutOrder = 2
	statusLabel.Size = UDim2.new(1, 0, 0, 20)
	statusLabel.TextColor3 = MUTED_TEXT_COLOR

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.LayoutOrder = 3
	closeButton.Size = UDim2.new(1, 0, 0, 42)
	closeButton.BackgroundColor3 = BUTTON_COLOR
	closeButton.BorderSizePixel = 0
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Text = "Close"
	closeButton.TextColor3 = TEXT_COLOR
	closeButton.TextSize = 18
	closeButton.Parent = frame
	applyCorner(closeButton, 8)

	return {
		rootGui = rootGui,
		frame = frame,
		headerFrame = headerFrame,
		titleLabel = titleLabel,
		timerLabel = timerLabel,
		cashLabel = cashLabel,
		productList = productList,
		statusLabel = statusLabel,
		closeButton = closeButton,
	}
end

local function createRow(parent: Instance, renderProduct: RenderProduct, callbacks: { (ShopProductId) -> () }): Frame
	local productDefinition = renderProduct.productDefinition
	local isUnlocked = renderProduct.isUnlocked
	local isInStock = renderProduct.stockRemaining > 0
	local canBuy = isUnlocked and isInStock and renderProduct.canAfford

	local row = Instance.new("Frame")
	row.Name = productDefinition.id
	row.BackgroundColor3 = if canBuy then ROW_COLOR else ROW_MUTED_COLOR
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, -8, 0, 82)
	row.Parent = parent
	applyCorner(row, 8)
	applyStroke(row, PANEL_STROKE_COLOR, 0.7)

	local rowPadding = Instance.new("UIPadding")
	rowPadding.PaddingTop = UDim.new(0, 10)
	rowPadding.PaddingBottom = UDim.new(0, 10)
	rowPadding.PaddingLeft = UDim.new(0, 12)
	rowPadding.PaddingRight = UDim.new(0, 12)
	rowPadding.Parent = row

	local nameLabel = createLabel(row, "NameLabel", 17, Enum.Font.GothamBold)
	nameLabel.Position = UDim2.fromOffset(0, 0)
	nameLabel.Size = UDim2.new(1, -132, 0, 22)
	nameLabel.Text = renderProduct.displayName

	local descriptionLabel = createLabel(row, "DescriptionLabel", 13, Enum.Font.GothamMedium)
	descriptionLabel.Position = UDim2.fromOffset(0, 25)
	descriptionLabel.Size = UDim2.new(1, -132, 0, 36)
	descriptionLabel.Text = productDefinition.description
	descriptionLabel.TextColor3 = MUTED_TEXT_COLOR
	descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top

	local stockLabel = createLabel(row, "StockLabel", 13, Enum.Font.GothamBold)
	stockLabel.AnchorPoint = Vector2.new(1, 0)
	stockLabel.Position = UDim2.new(1, 0, 0, 0)
	stockLabel.Size = UDim2.fromOffset(120, 20)
	stockLabel.TextXAlignment = Enum.TextXAlignment.Right
	stockLabel.TextColor3 = if not isUnlocked then MUTED_TEXT_COLOR elseif isInStock then MUTED_TEXT_COLOR else WARNING_COLOR
	stockLabel.Text = if not isUnlocked
		then string.format("Unlock: %s", formatCash(renderProduct.unlockLifetimeCash))
		else string.format("Stock: %d", renderProduct.stockRemaining)

	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BuyButton"
	buyButton.AnchorPoint = Vector2.new(1, 1)
	buyButton.Position = UDim2.new(1, 0, 1, 0)
	buyButton.Size = UDim2.fromOffset(118, 34)
	buyButton.BackgroundColor3 = if canBuy then BUTTON_COLOR else BUTTON_DISABLED_COLOR
	buyButton.BorderSizePixel = 0
	buyButton.AutoButtonColor = canBuy
	buyButton.Active = canBuy
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextColor3 = TEXT_COLOR
	buyButton.TextSize = 14
	buyButton.Text = if not isUnlocked
		then "Locked"
		elseif isInStock
		then string.format("Buy %s", formatCash(productDefinition.price))
		else "Sold Out"
	buyButton.Parent = row
	applyCorner(buyButton, 8)

	if isUnlocked and not canBuy and isInStock then
		buyButton.Text = string.format("Need %s", formatCash(productDefinition.price))
	end

	buyButton.Activated:Connect(function()
		if not canBuy then
			return
		end

		for _, callback in ipairs(callbacks) do
			callback(productDefinition.id)
		end
	end)

	return row
end

function ShopMenuView.new(): ShopMenuView
	local self = setmetatable({
		_widgets = createWidgets(),
		_purchaseCallbacks = {},
		_rowFrames = {},
	}, ShopMenuView) :: ShopMenuView

	return self
end

function ShopMenuView:getFrame(): Frame
	return self._widgets.frame
end

function ShopMenuView:render(
	shopName: string,
	secondsUntilRestock: number,
	cash: number,
	products: { RenderProduct },
	statusText: string?
)
	local minutes = math.floor(secondsUntilRestock / 60)
	local seconds = secondsUntilRestock % 60

	self._widgets.titleLabel.Text = shopName
	self._widgets.timerLabel.Text = string.format("Restock: %02d:%02d", minutes, seconds)
	self._widgets.cashLabel.Text = formatCash(cash)
	self._widgets.statusLabel.Text = statusText or ""
	self._widgets.statusLabel.TextColor3 = if statusText == "Purchased" then SUCCESS_COLOR else MUTED_TEXT_COLOR

	for _, rowFrame in ipairs(self._rowFrames) do
		rowFrame:Destroy()
	end
	table.clear(self._rowFrames)

	for _, renderProduct in ipairs(products) do
		table.insert(self._rowFrames, createRow(self._widgets.productList, renderProduct, self._purchaseCallbacks))
	end
end

function ShopMenuView:connectCloseRequested(listener: () -> ()): RBXScriptConnection
	return self._widgets.closeButton.Activated:Connect(listener)
end

function ShopMenuView:connectPurchaseRequested(listener: (ShopProductId) -> ())
	table.insert(self._purchaseCallbacks, listener)
end

function ShopMenuView:destroy()
	self._widgets.frame:Destroy()
end

return ShopMenuView

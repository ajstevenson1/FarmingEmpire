--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local economyFolder = sharedFolder:WaitForChild("Economy") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local EconomyTypes = require(economyFolder:WaitForChild("EconomyTypes") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)

type EconomySnapshot = EconomyTypes.EconomySnapshot
type MarketSnapshot = EconomyTypes.MarketSnapshot
type ResourceSnapshot = ResourceTypes.ResourceSnapshot

type Widgets = {
	rootGui: ScreenGui,
	cashLabel: TextLabel,
	applesLabel: TextLabel,
	ciderLabel: TextLabel,
	priceLabel: TextLabel,
	timerLabel: TextLabel,
	sellButton: TextButton,
}

export type ResourceStatusView = {
	_widgets: Widgets,
	render: (self: ResourceStatusView, resourceSnapshot: ResourceSnapshot, economySnapshot: EconomySnapshot, marketSnapshot: MarketSnapshot, secondsUntilPriceChange: number) -> (),
	connectSellRequested: (self: ResourceStatusView, listener: () -> ()) -> RBXScriptConnection,
	destroy: (self: ResourceStatusView) -> (),
}

local PANEL_SIZE = UDim2.fromOffset(240, 172)

local ResourceStatusView = {}
ResourceStatusView.__index = ResourceStatusView

local function createLabel(parent: Instance, name: string, layoutOrder: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.LayoutOrder = layoutOrder
	label.Size = UDim2.new(1, 0, 0, 22)
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(247, 244, 236)
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function createWidgets(): Widgets
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before creating ResourceStatusView")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	local rootGui = Instance.new("ScreenGui")
	rootGui.Name = "ResourceStatusGui"
	rootGui.IgnoreGuiInset = true
	rootGui.ResetOnSpawn = false
	rootGui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -18, 0, 18)
	panel.Size = PANEL_SIZE
	panel.BackgroundColor3 = Color3.fromRGB(33, 28, 20)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = rootGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(137, 111, 66)
	stroke.Thickness = 1
	stroke.Transparency = 0.15
	stroke.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel

	local titleLabel = createLabel(panel, "TitleLabel", 0)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.Text = "Orchard Ledger"

	local cashLabel = createLabel(panel, "CashLabel", 1)
	local applesLabel = createLabel(panel, "ApplesLabel", 2)
	local ciderLabel = createLabel(panel, "CiderLabel", 3)
	local priceLabel = createLabel(panel, "PriceLabel", 4)
	local timerLabel = createLabel(panel, "TimerLabel", 5)

	local sellButton = Instance.new("TextButton")
	sellButton.Name = "SellButton"
	sellButton.LayoutOrder = 6
	sellButton.Size = UDim2.new(1, 0, 0, 34)
	sellButton.BackgroundColor3 = Color3.fromRGB(177, 113, 48)
	sellButton.BorderSizePixel = 0
	sellButton.Font = Enum.Font.GothamBold
	sellButton.Text = "Sell All Cider"
	sellButton.TextColor3 = Color3.fromRGB(255, 247, 236)
	sellButton.TextSize = 16
	sellButton.Parent = panel

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 10)
	buttonCorner.Parent = sellButton

	return {
		rootGui = rootGui,
		cashLabel = cashLabel,
		applesLabel = applesLabel,
		ciderLabel = ciderLabel,
		priceLabel = priceLabel,
		timerLabel = timerLabel,
		sellButton = sellButton,
	}
end

function ResourceStatusView.new(): ResourceStatusView
	local self = setmetatable({
		_widgets = createWidgets(),
	}, ResourceStatusView) :: ResourceStatusView

	return self
end

function ResourceStatusView:render(
	resourceSnapshot: ResourceSnapshot,
	economySnapshot: EconomySnapshot,
	marketSnapshot: MarketSnapshot,
	secondsUntilPriceChange: number
)
	local apples = resourceSnapshot.amountsByResourceId.Apple or 0
	local cider = resourceSnapshot.amountsByResourceId.Cider or 0

	self._widgets.cashLabel.Text = string.format("Cash: $%d", economySnapshot.cash)
	self._widgets.applesLabel.Text = string.format("Apples: %d", apples)
	self._widgets.ciderLabel.Text = string.format("Cider: %d", cider)
	self._widgets.priceLabel.Text = string.format("Cider Price: $%d", marketSnapshot.ciderSellPrice)
	self._widgets.timerLabel.Text = string.format("Next Price Change: %ds", secondsUntilPriceChange)
	self._widgets.sellButton.AutoButtonColor = cider > 0
	self._widgets.sellButton.BackgroundTransparency = if cider > 0 then 0 else 0.35
end

function ResourceStatusView:connectSellRequested(listener: () -> ()): RBXScriptConnection
	return self._widgets.sellButton.Activated:Connect(listener)
end

function ResourceStatusView:destroy()
	self._widgets.rootGui:Destroy()
end

return ResourceStatusView

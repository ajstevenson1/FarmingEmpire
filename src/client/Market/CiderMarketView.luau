--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local economyFolder = sharedFolder:WaitForChild("Economy") :: Folder

local MarketPriceRank = require(economyFolder:WaitForChild("MarketPriceRank") :: ModuleScript)

type Widgets = {
	rootGui: ScreenGui,
	frame: Frame,
	titleLabel: TextLabel,
	countdownLabel: TextLabel,
	priceLabel: TextLabel,
	rankLabel: TextLabel,
	ciderLabel: TextLabel,
	valueLabel: TextLabel,
	cashLabel: TextLabel,
	meterTrack: Frame,
	meterMarker: Frame,
	statusLabel: TextLabel,
	sellButton: TextButton,
	closeButton: TextButton,
}

export type CiderMarketView = {
	_widgets: Widgets,
	getFrame: (self: CiderMarketView) -> Frame,
	render: (
		self: CiderMarketView,
		ciderSellPrice: number,
		secondsUntilPriceChange: number,
		ciderAmount: number,
		cash: number,
		statusText: string?
	) -> (),
	connectCloseRequested: (self: CiderMarketView, listener: () -> ()) -> RBXScriptConnection,
	connectSellRequested: (self: CiderMarketView, listener: () -> ()) -> RBXScriptConnection,
	destroy: (self: CiderMarketView) -> (),
}

local FRAME_SIZE = UDim2.fromOffset(500, 380)
local PANEL_COLOR = Color3.fromRGB(28, 30, 26)
local SECTION_COLOR = Color3.fromRGB(38, 42, 35)
local METER_COLOR = Color3.fromRGB(23, 25, 22)
local STROKE_COLOR = Color3.fromRGB(142, 173, 94)
local TEXT_COLOR = Color3.fromRGB(245, 248, 236)
local MUTED_TEXT_COLOR = Color3.fromRGB(205, 214, 190)
local PRICE_COLOR = Color3.fromRGB(166, 224, 112)
local WARNING_COLOR = Color3.fromRGB(239, 174, 91)
local BUTTON_COLOR = Color3.fromRGB(82, 144, 73)
local BUTTON_DISABLED_COLOR = Color3.fromRGB(80, 86, 74)
local CLOSE_BUTTON_COLOR = Color3.fromRGB(112, 95, 75)
local RANK_COLORS: { [string]: Color3 } = {
	Low = Color3.fromRGB(104, 134, 92),
	Average = Color3.fromRGB(143, 166, 89),
	Good = Color3.fromRGB(176, 171, 78),
	Insane = Color3.fromRGB(218, 148, 74),
}

local CiderMarketView = {}
CiderMarketView.__index = CiderMarketView

local function getRootGui(): ScreenGui
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before creating CiderMarketView")

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
	return string.format("$%d", math.max(0, math.floor(cash)))
end

local function formatSeconds(totalSeconds: number): string
	local minutes = math.floor(totalSeconds / 60)
	local seconds = totalSeconds % 60
	return string.format("%02d:%02d", minutes, seconds)
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

local function createStatFrame(parent: Instance, name: string, layoutOrder: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = SECTION_COLOR
	frame.BorderSizePixel = 0
	frame.LayoutOrder = layoutOrder
	frame.Size = UDim2.new(1, 0, 0, 48)
	frame.Parent = parent
	applyCorner(frame, 8)
	applyStroke(frame, STROKE_COLOR, 0.75)
	return frame
end

local function createRankMeter(parent: Instance): (Frame, Frame, TextLabel)
	local meterFrame = Instance.new("Frame")
	meterFrame.Name = "PriceRankMeter"
	meterFrame.BackgroundColor3 = METER_COLOR
	meterFrame.BorderSizePixel = 0
	meterFrame.LayoutOrder = 3
	meterFrame.Size = UDim2.new(1, 0, 0, 116)
	meterFrame.ClipsDescendants = true
	meterFrame.Parent = parent
	applyCorner(meterFrame, 8)
	applyStroke(meterFrame, STROKE_COLOR, 0.68)

	local rankLabel = createLabel(meterFrame, "RankLabel", 17, Enum.Font.GothamBold)
	rankLabel.Position = UDim2.fromOffset(12, 8)
	rankLabel.Size = UDim2.new(1, -24, 0, 24)

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = Color3.fromRGB(31, 35, 29)
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(12, 42)
	track.Size = UDim2.new(1, -24, 0, 50)
	track.ClipsDescendants = true
	track.Parent = meterFrame
	applyCorner(track, 8)

	local segmentsContainer = Instance.new("Frame")
	segmentsContainer.Name = "Segments"
	segmentsContainer.BackgroundTransparency = 1
	segmentsContainer.BorderSizePixel = 0
	segmentsContainer.Size = UDim2.fromScale(1, 1)
	segmentsContainer.Parent = track

	local trackLayout = Instance.new("UIListLayout")
	trackLayout.FillDirection = Enum.FillDirection.Horizontal
	trackLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	trackLayout.SortOrder = Enum.SortOrder.LayoutOrder
	trackLayout.Parent = segmentsContainer

	for _, rankDefinition in ipairs(MarketPriceRank.getAllRanks()) do
		local segment = Instance.new("Frame")
		segment.Name = rankDefinition.id
		segment.BackgroundColor3 = RANK_COLORS[rankDefinition.id] or SECTION_COLOR
		segment.BorderSizePixel = 0
		segment.LayoutOrder = rankDefinition.sortOrder
		segment.Size = UDim2.new(0.25, 0, 1, 0)
		segment.Parent = segmentsContainer

		local segmentLabel = createLabel(segment, "Label", 12, Enum.Font.GothamBold)
		segmentLabel.Size = UDim2.new(1, -6, 1, 0)
		segmentLabel.Position = UDim2.fromOffset(3, 0)
		segmentLabel.Text = rankDefinition.displayName
		segmentLabel.TextXAlignment = Enum.TextXAlignment.Center
	end

	local marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.AnchorPoint = Vector2.new(0.5, 0)
	marker.Position = UDim2.fromScale(0, 0)
	marker.Size = UDim2.new(0, 6, 1, 0)
	marker.BackgroundColor3 = TEXT_COLOR
	marker.BorderSizePixel = 0
	marker.ZIndex = 3
	marker.Parent = track
	applyCorner(marker, 3)

	return track, marker, rankLabel
end

local function createWidgets(): Widgets
	local rootGui = getRootGui()
	local frameParent = getFrameParent(rootGui)

	local frame = Instance.new("Frame")
	frame.Name = "CiderMarket"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = FRAME_SIZE
	frame.BackgroundColor3 = PANEL_COLOR
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = frameParent
	applyCorner(frame, 8)
	applyStroke(frame, STROKE_COLOR, 0.12)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 16)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "Header"
	headerFrame.BackgroundTransparency = 1
	headerFrame.LayoutOrder = 0
	headerFrame.Size = UDim2.new(1, 0, 0, 50)
	headerFrame.Parent = frame

	local titleLabel = createLabel(headerFrame, "TitleLabel", 24, Enum.Font.GothamBold)
	titleLabel.Position = UDim2.fromOffset(0, 0)
	titleLabel.Size = UDim2.new(1, -150, 0, 28)
	titleLabel.Text = "Cider Market"

	local countdownLabel = createLabel(headerFrame, "CountdownLabel", 14, Enum.Font.GothamMedium)
	countdownLabel.Position = UDim2.fromOffset(0, 29)
	countdownLabel.Size = UDim2.new(1, -150, 0, 20)
	countdownLabel.TextColor3 = MUTED_TEXT_COLOR

	local cashLabel = createLabel(headerFrame, "CashLabel", 17, Enum.Font.GothamBold)
	cashLabel.AnchorPoint = Vector2.new(1, 0)
	cashLabel.Position = UDim2.new(1, 0, 0, 5)
	cashLabel.Size = UDim2.fromOffset(140, 24)
	cashLabel.TextXAlignment = Enum.TextXAlignment.Right

	local priceFrame = createStatFrame(frame, "PriceFrame", 1)
	local priceLabel = createLabel(priceFrame, "PriceLabel", 20, Enum.Font.GothamBold)
	priceLabel.Position = UDim2.fromOffset(12, 6)
	priceLabel.Size = UDim2.new(1, -24, 0, 34)
	priceLabel.TextColor3 = PRICE_COLOR

	local stockFrame = createStatFrame(frame, "StockFrame", 2)
	local ciderLabel = createLabel(stockFrame, "CiderLabel", 16, Enum.Font.GothamBold)
	ciderLabel.Position = UDim2.fromOffset(12, 5)
	ciderLabel.Size = UDim2.new(0.5, -16, 0, 36)

	local valueLabel = createLabel(stockFrame, "ValueLabel", 16, Enum.Font.GothamBold)
	valueLabel.AnchorPoint = Vector2.new(1, 0)
	valueLabel.Position = UDim2.new(1, -12, 0, 5)
	valueLabel.Size = UDim2.new(0.5, -16, 0, 36)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.TextColor3 = PRICE_COLOR

	local meterTrack, meterMarker, rankLabel = createRankMeter(frame)

	local statusLabel = createLabel(frame, "StatusLabel", 14, Enum.Font.GothamMedium)
	statusLabel.LayoutOrder = 4
	statusLabel.Size = UDim2.new(1, 0, 0, 20)
	statusLabel.TextColor3 = MUTED_TEXT_COLOR

	local buttonRow = Instance.new("Frame")
	buttonRow.Name = "ButtonRow"
	buttonRow.BackgroundTransparency = 1
	buttonRow.LayoutOrder = 5
	buttonRow.Size = UDim2.new(1, 0, 0, 42)
	buttonRow.Parent = frame

	local sellButton = Instance.new("TextButton")
	sellButton.Name = "SellButton"
	sellButton.Position = UDim2.fromOffset(0, 0)
	sellButton.Size = UDim2.new(1, -114, 1, 0)
	sellButton.BackgroundColor3 = BUTTON_COLOR
	sellButton.BorderSizePixel = 0
	sellButton.Font = Enum.Font.GothamBold
	sellButton.Text = "Sell All Cider"
	sellButton.TextColor3 = TEXT_COLOR
	sellButton.TextSize = 17
	sellButton.Parent = buttonRow
	applyCorner(sellButton, 8)

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, 0, 0, 0)
	closeButton.Size = UDim2.fromOffset(104, 42)
	closeButton.BackgroundColor3 = CLOSE_BUTTON_COLOR
	closeButton.BorderSizePixel = 0
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Text = "Close"
	closeButton.TextColor3 = TEXT_COLOR
	closeButton.TextSize = 17
	closeButton.Parent = buttonRow
	applyCorner(closeButton, 8)

	return {
		rootGui = rootGui,
		frame = frame,
		titleLabel = titleLabel,
		countdownLabel = countdownLabel,
		priceLabel = priceLabel,
		rankLabel = rankLabel,
		ciderLabel = ciderLabel,
		valueLabel = valueLabel,
		cashLabel = cashLabel,
		meterTrack = meterTrack,
		meterMarker = meterMarker,
		statusLabel = statusLabel,
		sellButton = sellButton,
		closeButton = closeButton,
	}
end

function CiderMarketView.new(): CiderMarketView
	local self = setmetatable({
		_widgets = createWidgets(),
	}, CiderMarketView) :: CiderMarketView

	return self
end

function CiderMarketView:getFrame(): Frame
	return self._widgets.frame
end

function CiderMarketView:render(
	ciderSellPrice: number,
	secondsUntilPriceChange: number,
	ciderAmount: number,
	cash: number,
	statusText: string?
)
	local rankDefinition = MarketPriceRank.getCiderPriceRank(ciderSellPrice)
	local normalizedPrice = MarketPriceRank.getNormalizedCiderPrice(ciderSellPrice)

	self._widgets.countdownLabel.Text = string.format("Next price change: %s", formatSeconds(secondsUntilPriceChange))
	self._widgets.priceLabel.Text = string.format("Current price: %s / cider", formatCash(ciderSellPrice))
	self._widgets.rankLabel.Text = string.format("Market rank: %s", rankDefinition.displayName)
	self._widgets.rankLabel.TextColor3 = RANK_COLORS[rankDefinition.id] or PRICE_COLOR
	self._widgets.meterMarker.Position = UDim2.new(normalizedPrice, 0, 0, 0)
	self._widgets.ciderLabel.Text = string.format("Your cider: %d", math.max(0, math.floor(ciderAmount)))
	self._widgets.valueLabel.Text = string.format("Estimated sale: %s", formatCash(ciderAmount * ciderSellPrice))
	self._widgets.cashLabel.Text = formatCash(cash)
	self._widgets.statusLabel.Text = statusText or ""
	self._widgets.statusLabel.TextColor3 = if ciderAmount > 0 then MUTED_TEXT_COLOR else WARNING_COLOR

	local canSell = ciderAmount > 0
	self._widgets.sellButton.BackgroundColor3 = if canSell then BUTTON_COLOR else BUTTON_DISABLED_COLOR
	self._widgets.sellButton.AutoButtonColor = canSell
	self._widgets.sellButton.Active = canSell
end

function CiderMarketView:connectCloseRequested(listener: () -> ()): RBXScriptConnection
	return self._widgets.closeButton.Activated:Connect(listener)
end

function CiderMarketView:connectSellRequested(listener: () -> ()): RBXScriptConnection
	return self._widgets.sellButton.Activated:Connect(listener)
end

function CiderMarketView:destroy()
	self._widgets.frame:Destroy()
end

return CiderMarketView

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local economyFolder = sharedFolder:WaitForChild("Economy") :: Folder

local MarketPriceRank = require(economyFolder:WaitForChild("MarketPriceRank") :: ModuleScript)

type GuiButtonLike = TextButton | ImageButton

type Widgets = {
	rootGui: ScreenGui,
	frame: Frame,
	pricePanelCurrentLabel: TextLabel,
	pricePanelNextLabel: TextLabel,
	barFrame: Frame,
	priceBar: Frame,
	arrow: GuiObject,
	barCurrentLabel: TextLabel,
	sellButton: GuiButtonLike,
	closeButton: GuiButtonLike,
}

export type CiderMarketView = {
	_widgets: Widgets,
	_lastPrice: number?,
	_displayedPrice: number?,
	_priceAnimationId: number,
	_activeTweens: { Tween },
	_arrowBaseXOffset: number,
	_barCurrentBaseXOffset: number,
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
	_cancelPriceTweens: (self: CiderMarketView) -> (),
	_applyPricePosition: (self: CiderMarketView, price: number) -> (),
	_playPricePositionTween: (self: CiderMarketView, targetPrice: number, previousPrice: number) -> (),
	_animatePriceText: (self: CiderMarketView, targetPrice: number, previousPrice: number) -> (),
}

local ROOT_GUI_NAME = "GUI"
local FRAMES_NAME = "Frames"
local SELL_FRAME_NAME = "Sell"

local BAR_OVERSHOOT = 0.055
local ARROW_LEFT_OFFSET_SCALE = -0.055
local CURRENT_TEXT_LEFT_OFFSET_SCALE = -0.075
local SLIDE_OUT_TWEEN_INFO = TweenInfo.new(0.56, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SETTLE_TWEEN_INFO = TweenInfo.new(0.36, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local COUNT_STEP_SECONDS = 0.085

local CiderMarketView = {}
CiderMarketView.__index = CiderMarketView

local function getRootGui(): ScreenGui
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before creating CiderMarketView")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild(ROOT_GUI_NAME)
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")
	return rootGui
end

local function getGuiObjectChild(parent: Instance, childName: string): GuiObject
	local child = parent:WaitForChild(childName)
	assert(child:IsA("GuiObject"), string.format("%s.%s must be a GuiObject", parent:GetFullName(), childName))
	return child
end

local function getFrameChild(parent: Instance, childName: string): Frame
	local child = parent:WaitForChild(childName)
	assert(child:IsA("Frame"), string.format("%s.%s must be a Frame", parent:GetFullName(), childName))
	return child
end

local function getTextLabelChild(parent: Instance, childName: string): TextLabel
	local child = parent:WaitForChild(childName)
	assert(child:IsA("TextLabel"), string.format("%s.%s must be a TextLabel", parent:GetFullName(), childName))
	return child
end

local function getButtonChild(parent: Instance, childName: string): GuiButtonLike
	local child = parent:WaitForChild(childName)
	assert(
		child:IsA("TextButton") or child:IsA("ImageButton"),
		string.format("%s.%s must be a TextButton or ImageButton", parent:GetFullName(), childName)
	)
	return child :: GuiButtonLike
end

local function getSellFrame(rootGui: ScreenGui): Frame
	local frames = rootGui:WaitForChild(FRAMES_NAME)
	assert(frames:IsA("GuiObject"), "PlayerGui.GUI.Frames must be a GuiObject")

	local sellFrame = frames:WaitForChild(SELL_FRAME_NAME)
	assert(sellFrame:IsA("Frame"), "PlayerGui.GUI.Frames.Sell must be a Frame")
	return sellFrame
end

local function formatCash(value: number): string
	return string.format("$%d", math.max(0, math.floor(value)))
end

local function formatSeconds(totalSeconds: number): string
	local clampedSeconds = math.max(0, math.floor(totalSeconds))
	local minutes = math.floor(clampedSeconds / 60)
	local seconds = clampedSeconds % 60
	return string.format("%02d:%02d", minutes, seconds)
end

local function getMarkerXScale(ciderSellPrice: number): number
	return MarketPriceRank.getNormalizedCiderPrice(ciderSellPrice)
end

local function getPriceBarXScale(markerXScale: number): number
	return 1 - markerXScale
end

local function setButtonEnabled(button: GuiButtonLike, isEnabled: boolean)
	button.Active = isEnabled
	button.AutoButtonColor = isEnabled

	if button:IsA("TextButton") then
		button.TextTransparency = if isEnabled then 0 else 0.35
	elseif button:IsA("ImageButton") then
		button.ImageTransparency = if isEnabled then 0 else 0.35
	end
end

local function setPositionX(guiObject: GuiObject, xScale: number, xOffset: number, leftOffsetScale: number)
	local position = guiObject.Position
	guiObject.Position = UDim2.new(math.clamp(xScale + leftOffsetScale, 0, 1), xOffset, position.Y.Scale, position.Y.Offset)
end

local function setPriceBarSizeX(priceBar: Frame, xScale: number)
	local size = priceBar.Size
	priceBar.Size = UDim2.new(xScale, size.X.Offset, size.Y.Scale, size.Y.Offset)
end

local function setPriceText(widgets: Widgets, price: number)
	local priceText = formatCash(price)
	widgets.pricePanelCurrentLabel.Text = string.format("Current Price: %s", priceText)
	widgets.barCurrentLabel.Text = priceText
end

local function createWidgets(): Widgets
	local rootGui = getRootGui()
	local frame = getSellFrame(rootGui)

	local sellPrice = getFrameChild(frame, "SellPrice")
	local barFrame = getFrameChild(frame, "Bar")
	local priceBar = getFrameChild(barFrame, "PriceBar")
	local arrow = getGuiObjectChild(barFrame, "Arrow")

	return {
		rootGui = rootGui,
		frame = frame,
		pricePanelCurrentLabel = getTextLabelChild(sellPrice, "Current"),
		pricePanelNextLabel = getTextLabelChild(sellPrice, "Next"),
		barFrame = barFrame,
		priceBar = priceBar,
		arrow = arrow,
		barCurrentLabel = getTextLabelChild(barFrame, "Current"),
		sellButton = getButtonChild(frame, "SellButton"),
		closeButton = getButtonChild(frame, "Close"),
	}
end

function CiderMarketView.new(): CiderMarketView
	local widgets = createWidgets()
	local self = setmetatable({
		_widgets = widgets,
		_lastPrice = nil,
		_displayedPrice = nil,
		_priceAnimationId = 0,
		_activeTweens = {},
		_arrowBaseXOffset = widgets.arrow.Position.X.Offset,
		_barCurrentBaseXOffset = widgets.barCurrentLabel.Position.X.Offset,
	}, CiderMarketView) :: CiderMarketView

	widgets.frame.Visible = false
	return self
end

function CiderMarketView:getFrame(): Frame
	return self._widgets.frame
end

function CiderMarketView:_cancelPriceTweens()
	for _, tween in ipairs(self._activeTweens) do
		tween:Cancel()
	end

	table.clear(self._activeTweens)
end

function CiderMarketView:_applyPricePosition(price: number)
	local markerXScale = getMarkerXScale(price)
	setPriceBarSizeX(self._widgets.priceBar, getPriceBarXScale(markerXScale))
	setPositionX(self._widgets.arrow, markerXScale, self._arrowBaseXOffset, ARROW_LEFT_OFFSET_SCALE)
	setPositionX(self._widgets.barCurrentLabel, markerXScale, self._barCurrentBaseXOffset, CURRENT_TEXT_LEFT_OFFSET_SCALE)
end

function CiderMarketView:_playPricePositionTween(targetPrice: number, previousPrice: number)
	self:_cancelPriceTweens()

	local targetMarkerXScale = getMarkerXScale(targetPrice)
	local previousMarkerXScale = getMarkerXScale(previousPrice)
	local direction = if targetMarkerXScale >= previousMarkerXScale then 1 else -1
	local overshootMarkerXScale = math.clamp(targetMarkerXScale + (BAR_OVERSHOOT * direction), 0, 1)

	local overshootBarXScale = getPriceBarXScale(overshootMarkerXScale)
	local targetBarXScale = getPriceBarXScale(targetMarkerXScale)

	local slideTweens = {
		TweenService:Create(self._widgets.priceBar, SLIDE_OUT_TWEEN_INFO, {
			Size = UDim2.new(overshootBarXScale, self._widgets.priceBar.Size.X.Offset, self._widgets.priceBar.Size.Y.Scale, self._widgets.priceBar.Size.Y.Offset),
		}),
		TweenService:Create(self._widgets.arrow, SLIDE_OUT_TWEEN_INFO, {
			Position = UDim2.new(
				math.clamp(overshootMarkerXScale + ARROW_LEFT_OFFSET_SCALE, 0, 1),
				self._arrowBaseXOffset,
				self._widgets.arrow.Position.Y.Scale,
				self._widgets.arrow.Position.Y.Offset
			),
		}),
		TweenService:Create(self._widgets.barCurrentLabel, SLIDE_OUT_TWEEN_INFO, {
			Position = UDim2.new(
				math.clamp(overshootMarkerXScale + CURRENT_TEXT_LEFT_OFFSET_SCALE, 0, 1),
				self._barCurrentBaseXOffset,
				self._widgets.barCurrentLabel.Position.Y.Scale,
				self._widgets.barCurrentLabel.Position.Y.Offset
			),
		}),
	}

	self._activeTweens = slideTweens
	local completedCount = 0
	local expectedCount = #slideTweens

	local function playSettleTweens()
		local settleTweens = {
			TweenService:Create(self._widgets.priceBar, SETTLE_TWEEN_INFO, {
				Size = UDim2.new(targetBarXScale, self._widgets.priceBar.Size.X.Offset, self._widgets.priceBar.Size.Y.Scale, self._widgets.priceBar.Size.Y.Offset),
			}),
			TweenService:Create(self._widgets.arrow, SETTLE_TWEEN_INFO, {
				Position = UDim2.new(
					math.clamp(targetMarkerXScale + ARROW_LEFT_OFFSET_SCALE, 0, 1),
					self._arrowBaseXOffset,
					self._widgets.arrow.Position.Y.Scale,
					self._widgets.arrow.Position.Y.Offset
				),
			}),
			TweenService:Create(self._widgets.barCurrentLabel, SETTLE_TWEEN_INFO, {
				Position = UDim2.new(
					math.clamp(targetMarkerXScale + CURRENT_TEXT_LEFT_OFFSET_SCALE, 0, 1),
					self._barCurrentBaseXOffset,
					self._widgets.barCurrentLabel.Position.Y.Scale,
					self._widgets.barCurrentLabel.Position.Y.Offset
				),
			}),
		}

		self._activeTweens = settleTweens
		for _, tween in ipairs(settleTweens) do
			tween:Play()
		end
	end

	for _, tween in ipairs(slideTweens) do
		tween.Completed:Connect(function(playbackState: Enum.PlaybackState)
			if playbackState ~= Enum.PlaybackState.Completed then
				return
			end

			completedCount += 1
			if completedCount == expectedCount then
				playSettleTweens()
			end
		end)
		tween:Play()
	end
end

function CiderMarketView:_animatePriceText(targetPrice: number, previousPrice: number)
	self._priceAnimationId += 1
	local animationId = self._priceAnimationId
	local startPrice = math.floor(previousPrice)
	local endPrice = math.floor(targetPrice)

	if startPrice == endPrice then
		self._displayedPrice = endPrice
		setPriceText(self._widgets, endPrice)
		return
	end

	local step = if endPrice > startPrice then 1 else -1
	task.spawn(function()
		local displayedPrice = startPrice
		while animationId == self._priceAnimationId do
			displayedPrice += step
			self._displayedPrice = displayedPrice
			setPriceText(self._widgets, displayedPrice)

			if displayedPrice == endPrice then
				break
			end

			task.wait(COUNT_STEP_SECONDS)
		end
	end)
end

function CiderMarketView:render(
	ciderSellPrice: number,
	secondsUntilPriceChange: number,
	ciderAmount: number,
	_cash: number,
	_statusText: string?
)
	self._widgets.pricePanelNextLabel.Text = string.format("Next Price in: %s", formatSeconds(secondsUntilPriceChange))
	setButtonEnabled(self._widgets.sellButton, ciderAmount > 0)

	local previousPrice = self._lastPrice
	if previousPrice == nil then
		self._lastPrice = ciderSellPrice
		self._displayedPrice = ciderSellPrice
		setPriceText(self._widgets, ciderSellPrice)
		self:_applyPricePosition(ciderSellPrice)
		return
	end

	if previousPrice == ciderSellPrice then
		if self._displayedPrice == nil then
			setPriceText(self._widgets, ciderSellPrice)
		end
		return
	end

	self._lastPrice = ciderSellPrice
	self:_playPricePositionTween(ciderSellPrice, previousPrice)
	self:_animatePriceText(ciderSellPrice, previousPrice)
end

function CiderMarketView:connectCloseRequested(listener: () -> ()): RBXScriptConnection
	return self._widgets.closeButton.Activated:Connect(listener)
end

function CiderMarketView:connectSellRequested(listener: () -> ()): RBXScriptConnection
	return self._widgets.sellButton.Activated:Connect(listener)
end

function CiderMarketView:destroy()
	self:_cancelPriceTweens()
	self._priceAnimationId += 1
end

return CiderMarketView

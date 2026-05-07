--!strict

local Players = game:GetService("Players")

type Widgets = {
	rootGui: ScreenGui,
	frame: Frame,
	titleLabel: TextLabel,
	timerLabel: TextLabel,
	closeButton: TextButton,
}

export type ShopMenuView = {
	_widgets: Widgets,
	getFrame: (self: ShopMenuView) -> Frame,
	render: (self: ShopMenuView, shopName: string, secondsUntilRestock: number) -> (),
	connectCloseRequested: (self: ShopMenuView, listener: () -> ()) -> RBXScriptConnection,
	destroy: (self: ShopMenuView) -> (),
}

local FRAME_SIZE = UDim2.fromOffset(360, 200)
local PANEL_COLOR = Color3.fromRGB(32, 28, 22)
local PANEL_STROKE_COLOR = Color3.fromRGB(158, 126, 69)
local TEXT_COLOR = Color3.fromRGB(250, 244, 232)
local MUTED_TEXT_COLOR = Color3.fromRGB(219, 205, 180)
local BUTTON_COLOR = Color3.fromRGB(176, 113, 51)

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

local function createLabel(parent: Instance, name: string, layoutOrder: number, textSize: number, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.LayoutOrder = layoutOrder
	label.Size = UDim2.new(1, 0, 0, 32)
	label.Font = font
	label.Text = ""
	label.TextColor3 = TEXT_COLOR
	label.TextSize = textSize
	label.TextWrapped = true
	label.Parent = parent
	return label
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

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = PANEL_STROKE_COLOR
	stroke.Thickness = 1
	stroke.Transparency = 0.12
	stroke.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 18)
	padding.PaddingBottom = UDim.new(0, 18)
	padding.PaddingLeft = UDim.new(0, 20)
	padding.PaddingRight = UDim.new(0, 20)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local titleLabel = createLabel(frame, "TitleLabel", 0, 24, Enum.Font.GothamBold)
	titleLabel.Size = UDim2.new(1, 0, 0, 42)

	local timerLabel = createLabel(frame, "TimerLabel", 1, 18, Enum.Font.GothamMedium)
	timerLabel.TextColor3 = MUTED_TEXT_COLOR

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.LayoutOrder = 2
	closeButton.Size = UDim2.new(1, 0, 0, 44)
	closeButton.BackgroundColor3 = BUTTON_COLOR
	closeButton.BorderSizePixel = 0
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Text = "Close"
	closeButton.TextColor3 = TEXT_COLOR
	closeButton.TextSize = 18
	closeButton.Parent = frame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 8)
	buttonCorner.Parent = closeButton

	return {
		rootGui = rootGui,
		frame = frame,
		titleLabel = titleLabel,
		timerLabel = timerLabel,
		closeButton = closeButton,
	}
end

function ShopMenuView.new(): ShopMenuView
	local self = setmetatable({
		_widgets = createWidgets(),
	}, ShopMenuView) :: ShopMenuView

	return self
end

function ShopMenuView:getFrame(): Frame
	return self._widgets.frame
end

function ShopMenuView:render(shopName: string, secondsUntilRestock: number)
	local minutes = math.floor(secondsUntilRestock / 60)
	local seconds = secondsUntilRestock % 60

	self._widgets.titleLabel.Text = shopName
	self._widgets.timerLabel.Text = string.format("Restock: %02d:%02d", minutes, seconds)
end

function ShopMenuView:connectCloseRequested(listener: () -> ()): RBXScriptConnection
	return self._widgets.closeButton.Activated:Connect(listener)
end

function ShopMenuView:destroy()
	self._widgets.frame:Destroy()
end

return ShopMenuView

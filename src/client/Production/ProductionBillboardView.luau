--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)

type BillboardWidgets = {
	rootGui: BillboardGui,
	statusLabel: TextLabel,
	barFill: Frame,
}

export type ProductionBillboardView = {
	_part: BasePart,
	_widgets: BillboardWidgets,
	refresh: (self: ProductionBillboardView) -> (),
	destroy: (self: ProductionBillboardView) -> (),
}

local READY_BAR_COLOR = Color3.fromRGB(107, 204, 113)
local GROWING_BAR_COLOR = Color3.fromRGB(232, 190, 88)
local BAR_BACKGROUND_COLOR = Color3.fromRGB(43, 43, 43)

local ProductionBillboardView = {}
ProductionBillboardView.__index = ProductionBillboardView

local function createWidgets(part: BasePart): BillboardWidgets
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before creating production billboards")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	local rootGui = Instance.new("BillboardGui")
	rootGui.Name = "ProductionStatusBillboard"
	rootGui.Adornee = part
	rootGui.AlwaysOnTop = true
	rootGui.LightInfluence = 0
	rootGui.MaxDistance = 100
	rootGui.Size = UDim2.fromOffset(120, 54)
	rootGui.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	rootGui.Parent = playerGui

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
	container.BackgroundTransparency = 0.15
	container.BorderSizePixel = 0
	container.Size = UDim2.fromScale(1, 1)
	container.Parent = rootGui

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 10)
	containerCorner.Parent = container

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = container

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.BackgroundTransparency = 1
	statusLabel.Size = UDim2.new(1, 0, 0, 18)
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.Text = ""
	statusLabel.TextColor3 = Color3.fromRGB(248, 243, 231)
	statusLabel.TextScaled = true
	statusLabel.Parent = container

	local barBackground = Instance.new("Frame")
	barBackground.Name = "BarBackground"
	barBackground.BackgroundColor3 = BAR_BACKGROUND_COLOR
	barBackground.BorderSizePixel = 0
	barBackground.Size = UDim2.new(1, 0, 0, 12)
	barBackground.Parent = container

	local barBackgroundCorner = Instance.new("UICorner")
	barBackgroundCorner.CornerRadius = UDim.new(1, 0)
	barBackgroundCorner.Parent = barBackground

	local barFill = Instance.new("Frame")
	barFill.Name = "BarFill"
	barFill.BackgroundColor3 = GROWING_BAR_COLOR
	barFill.BorderSizePixel = 0
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.Parent = barBackground

	local barFillCorner = Instance.new("UICorner")
	barFillCorner.CornerRadius = UDim.new(1, 0)
	barFillCorner.Parent = barFill

	return {
		rootGui = rootGui,
		statusLabel = statusLabel,
		barFill = barFill,
	}
end

function ProductionBillboardView.new(part: BasePart): ProductionBillboardView
	local self = setmetatable({
		_part = part,
		_widgets = createWidgets(part),
	}, ProductionBillboardView) :: ProductionBillboardView

	self:refresh()

	return self
end

function ProductionBillboardView:refresh()
	local progressValue = self._part:GetAttribute(BuildingAttributeNames.productionProgress)
	local statusTextValue = self._part:GetAttribute(BuildingAttributeNames.productionStatusText)
	local productionStateValue = self._part:GetAttribute(BuildingAttributeNames.productionState)

	local progress = if type(progressValue) == "number" then math.clamp(progressValue, 0, 1) else 0
	local statusText = if type(statusTextValue) == "string" then statusTextValue else ""
	local productionState = if type(productionStateValue) == "string" then productionStateValue else "Growing"

	self._widgets.statusLabel.Text = statusText
	self._widgets.barFill.Size = UDim2.fromScale(progress, 1)
	self._widgets.barFill.BackgroundColor3 = if productionState == "Ready" then READY_BAR_COLOR else GROWING_BAR_COLOR
end

function ProductionBillboardView:destroy()
	self._widgets.rootGui:Destroy()
end

return ProductionBillboardView

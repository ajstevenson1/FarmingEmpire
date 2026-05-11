--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local formattingFolder = sharedFolder:WaitForChild("Formatting") :: Folder
local templatesFolder = ReplicatedStorage:WaitForChild("Templates") :: Folder

local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local NumberFormatter = require(formattingFolder:WaitForChild("NumberFormatter") :: ModuleScript)

type AppleCounterWidgets = {
	rootGui: BillboardGui,
	countLabel: TextLabel,
	stroke: UIStroke,
}

export type AppleCounterBillboardView = {
	_part: BasePart,
	_widgets: AppleCounterWidgets,
	refresh: (self: AppleCounterBillboardView) -> (),
	destroy: (self: AppleCounterBillboardView) -> (),
}

local TEMPLATE_NAME = "AppleCounter"
local COUNT_LABEL_NAME = "Count"
local STROKE_NAME = "Stroke"

local EMPTY_TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local EMPTY_STROKE_COLOR = Color3.fromRGB(0, 0, 0)
local FULL_TEXT_COLOR = Color3.fromRGB(72, 214, 91)
local FULL_STROKE_COLOR = Color3.fromRGB(21, 96, 39)

local AppleCounterBillboardView = {}
AppleCounterBillboardView.__index = AppleCounterBillboardView

local function getNumberAttribute(part: BasePart, attributeName: string): number
	local value = part:GetAttribute(attributeName)
	return if type(value) == "number" then value else 0
end

local function getClampedCounterValues(part: BasePart): (number, number)
	local storageCap = math.max(0, math.floor(getNumberAttribute(part, BuildingAttributeNames.productionStorageCap)))
	local storedAmount = math.clamp(
		math.floor(getNumberAttribute(part, BuildingAttributeNames.productionStoredAmount)),
		0,
		storageCap
	)

	return storedAmount, storageCap
end

local function createWidgets(part: BasePart): AppleCounterWidgets
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before creating apple counter billboards")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local template = templatesFolder:WaitForChild(TEMPLATE_NAME)
	assert(template:IsA("BillboardGui"), string.format("Templates.%s must be a BillboardGui", TEMPLATE_NAME))

	local rootGui = template:Clone() :: BillboardGui
	rootGui.Name = "AppleCounterBillboard"
	rootGui.Adornee = part
	rootGui.Parent = playerGui

	local countLabelInstance = rootGui:FindFirstChild(COUNT_LABEL_NAME, true)
	assert(
		countLabelInstance ~= nil and countLabelInstance:IsA("TextLabel"),
		string.format("Templates.%s must contain a TextLabel named %s", TEMPLATE_NAME, COUNT_LABEL_NAME)
	)

	local countLabel = countLabelInstance :: TextLabel
	local strokeInstance = countLabel:FindFirstChild(STROKE_NAME)
	assert(
		strokeInstance ~= nil and strokeInstance:IsA("UIStroke"),
		string.format("Templates.%s.%s must contain a UIStroke named %s", TEMPLATE_NAME, COUNT_LABEL_NAME, STROKE_NAME)
	)

	return {
		rootGui = rootGui,
		countLabel = countLabel,
		stroke = strokeInstance :: UIStroke,
	}
end

function AppleCounterBillboardView.new(part: BasePart): AppleCounterBillboardView
	local self = setmetatable({
		_part = part,
		_widgets = createWidgets(part),
	}, AppleCounterBillboardView) :: AppleCounterBillboardView

	self:refresh()

	return self
end

function AppleCounterBillboardView:refresh()
	local storedAmount, storageCap = getClampedCounterValues(self._part)
	local isFull = storageCap > 0 and storedAmount >= storageCap

	self._widgets.countLabel.Text = string.format(
		"%s/%s",
		NumberFormatter.formatAbbreviated(storedAmount),
		NumberFormatter.formatAbbreviated(storageCap)
	)
	self._widgets.countLabel.TextColor3 = if isFull then FULL_TEXT_COLOR else EMPTY_TEXT_COLOR
	self._widgets.stroke.Color = if isFull then FULL_STROKE_COLOR else EMPTY_STROKE_COLOR
end

function AppleCounterBillboardView:destroy()
	self._widgets.rootGui:Destroy()
end

return AppleCounterBillboardView

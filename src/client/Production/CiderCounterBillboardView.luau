--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local formattingFolder = sharedFolder:WaitForChild("Formatting") :: Folder
local templatesFolder = ReplicatedStorage:WaitForChild("Templates") :: Folder

local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local NumberFormatter = require(formattingFolder:WaitForChild("NumberFormatter") :: ModuleScript)

type CiderCounterWidgets = {
	rootGui: BillboardGui,
	countRoot: GuiObject,
	countLabel: TextLabel,
	perSecondLabel: TextLabel,
	multiplierLabel: TextLabel,
	stroke: UIStroke,
}

export type CiderCounterBillboardView = {
	_part: BasePart,
	_widgets: CiderCounterWidgets,
	refresh: (self: CiderCounterBillboardView) -> (),
	setCountVisible: (self: CiderCounterBillboardView, isVisible: boolean) -> (),
	destroy: (self: CiderCounterBillboardView) -> (),
}

local TEMPLATE_NAME = "CiderCounter"
local COUNT_LABEL_NAME = "Count"
local PER_SECOND_LABEL_NAME = "PerSec"
local MULTIPLIER_LABEL_NAME = "Multiplier"

local EMPTY_TEXT_COLOR = Color3.fromRGB(235, 238, 230)
local EMPTY_STROKE_COLOR = Color3.fromRGB(25, 45, 30)
local READY_TEXT_COLOR = Color3.fromRGB(255, 196, 83)
local READY_STROKE_COLOR = Color3.fromRGB(36, 86, 46)

local CiderCounterBillboardView = {}
CiderCounterBillboardView.__index = CiderCounterBillboardView

local function getStoredAmount(part: BasePart): number
	local value = part:GetAttribute(BuildingAttributeNames.productionStoredAmount)
	return if type(value) == "number" then math.max(0, math.floor(value)) else 0
end

local function getProductionMultiplier(part: BasePart): number
	local value = part:GetAttribute(BuildingAttributeNames.productionMultiplier)
	return if type(value) == "number" then math.max(1, math.floor(value)) else 1
end

local function getProductionRatePerSecond(part: BasePart): number
	local value = part:GetAttribute(BuildingAttributeNames.productionRatePerSecond)
	return if type(value) == "number" then math.max(0, value) else 0
end

local function formatPerSecond(ratePerSecond: number): string
	if ratePerSecond >= 1000 then
		return string.format("%s/s", NumberFormatter.formatAbbreviated(ratePerSecond, {
			decimalPlaces = 1,
			trimTrailingZeros = true,
		}))
	end

	local roundedRate = math.floor((ratePerSecond * 10) + 0.5) / 10
	if roundedRate % 1 == 0 then
		return string.format("%d/s", roundedRate)
	end

	return string.format("%.1f/s", roundedRate)
end

local function findRequiredTextLabel(root: Instance, labelName: string): TextLabel
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.Name == labelName and descendant:IsA("TextLabel") then
			return descendant
		end
	end

	error(string.format("Templates.%s must contain a TextLabel named %s", TEMPLATE_NAME, labelName))
end

local function findRequiredGuiObject(root: Instance, objectName: string): GuiObject
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.Name == objectName and descendant:IsA("GuiObject") then
			return descendant
		end
	end

	error(string.format("Templates.%s must contain a GuiObject named %s", TEMPLATE_NAME, objectName))
end

local function findStroke(countLabel: TextLabel): UIStroke
	for _, child in ipairs(countLabel:GetChildren()) do
		if child:IsA("UIStroke") then
			return child
		end
	end

	error(string.format("Templates.%s.%s must contain a UIStroke", TEMPLATE_NAME, COUNT_LABEL_NAME))
end

local function createWidgets(part: BasePart): CiderCounterWidgets
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before creating cider counter billboards")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local template = templatesFolder:WaitForChild(TEMPLATE_NAME)
	assert(template:IsA("BillboardGui"), string.format("Templates.%s must be a BillboardGui", TEMPLATE_NAME))

	local rootGui = template:Clone() :: BillboardGui
	rootGui.Name = "CiderCounterBillboard"
	rootGui.Adornee = part
	rootGui.Parent = playerGui

	local countLabel = findRequiredTextLabel(rootGui, COUNT_LABEL_NAME)

	return {
		rootGui = rootGui,
		countRoot = findRequiredGuiObject(rootGui, COUNT_LABEL_NAME),
		countLabel = countLabel,
		perSecondLabel = findRequiredTextLabel(rootGui, PER_SECOND_LABEL_NAME),
		multiplierLabel = findRequiredTextLabel(rootGui, MULTIPLIER_LABEL_NAME),
		stroke = findStroke(countLabel),
	}
end

function CiderCounterBillboardView.new(part: BasePart): CiderCounterBillboardView
	local self = setmetatable({
		_part = part,
		_widgets = createWidgets(part),
	}, CiderCounterBillboardView) :: CiderCounterBillboardView

	self:refresh()

	return self
end

function CiderCounterBillboardView:refresh()
	local storedAmount = getStoredAmount(self._part)
	local productionMultiplier = getProductionMultiplier(self._part)
	local ratePerSecond = getProductionRatePerSecond(self._part)
	local hasCider = storedAmount > 0

	self._widgets.countLabel.Text = NumberFormatter.formatAbbreviated(storedAmount)
	self._widgets.countLabel.TextColor3 = if hasCider then READY_TEXT_COLOR else EMPTY_TEXT_COLOR
	self._widgets.stroke.Color = if hasCider then READY_STROKE_COLOR else EMPTY_STROKE_COLOR
	self._widgets.perSecondLabel.Text = formatPerSecond(ratePerSecond)
	self._widgets.perSecondLabel.Visible = ratePerSecond > 0
	self._widgets.multiplierLabel.Text = string.format("%dx", productionMultiplier)
	self._widgets.multiplierLabel.Visible = productionMultiplier > 1
end

function CiderCounterBillboardView:setCountVisible(isVisible: boolean)
	self._widgets.countRoot.Visible = isVisible
end

function CiderCounterBillboardView:destroy()
	self._widgets.rootGui:Destroy()
end

return CiderCounterBillboardView

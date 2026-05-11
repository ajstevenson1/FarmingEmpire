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
	countLabel: TextLabel,
	stroke: UIStroke,
}

export type CiderCounterBillboardView = {
	_part: BasePart,
	_widgets: CiderCounterWidgets,
	refresh: (self: CiderCounterBillboardView) -> (),
	destroy: (self: CiderCounterBillboardView) -> (),
}

local TEMPLATE_NAME = "CiderCounter"
local COUNT_LABEL_NAME = "Count"

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

	local countLabelInstance = rootGui:FindFirstChild(COUNT_LABEL_NAME, true)
	assert(
		countLabelInstance ~= nil and countLabelInstance:IsA("TextLabel"),
		string.format("Templates.%s must contain a TextLabel named %s", TEMPLATE_NAME, COUNT_LABEL_NAME)
	)

	local countLabel = countLabelInstance :: TextLabel

	return {
		rootGui = rootGui,
		countLabel = countLabel,
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
	local hasCider = storedAmount > 0

	self._widgets.countLabel.Text = NumberFormatter.formatAbbreviated(storedAmount)
	self._widgets.countLabel.TextColor3 = if hasCider then READY_TEXT_COLOR else EMPTY_TEXT_COLOR
	self._widgets.stroke.Color = if hasCider then READY_STROKE_COLOR else EMPTY_STROKE_COLOR
end

function CiderCounterBillboardView:destroy()
	self._widgets.rootGui:Destroy()
end

return CiderCounterBillboardView

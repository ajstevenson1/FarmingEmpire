--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local formattingFolder = sharedFolder:WaitForChild("Formatting") :: Folder

local NumberFormatter = require(formattingFolder:WaitForChild("NumberFormatter") :: ModuleScript)

type ToastAnchorId = "Money" | "Apple" | "Cider"
type ToastTemplateId = "Collected" | "Used"

type Widgets = {
	moneyText: TextLabel,
	appleText: TextLabel,
	ciderText: TextLabel,
}

type TransparencyTarget = {
	instance: Instance,
	propertyName: string,
}

export type ResourceGainToastView = {
	_widgets: Widgets,
	_activeToastCountsByAnchorId: { [ToastAnchorId]: number },
	showCashGain: (self: ResourceGainToastView, amount: number) -> (),
	showCashUsed: (self: ResourceGainToastView, amount: number) -> (),
	showAppleGain: (self: ResourceGainToastView, amount: number) -> (),
	showCiderGain: (self: ResourceGainToastView, amount: number) -> (),
	showCiderUsed: (self: ResourceGainToastView, amount: number) -> (),
	destroy: (self: ResourceGainToastView) -> (),
}

local HUD_NAME = "HUD"
local BOTTOM_LEFT_NAME = "BottomLeft"
local TEMPLATES_FOLDER_NAME = "Templates"
local ITEM_COLLECTED_TEMPLATE_NAME = "ItemCollected"
local ITEM_USED_TEMPLATE_NAME = "ItemUsed"

local FLOAT_DISTANCE = 28
local START_ROTATION_DEGREES = -30
local TOAST_TWEEN_INFO = TweenInfo.new(1.02, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local templatesFolder = ReplicatedStorage:WaitForChild(TEMPLATES_FOLDER_NAME)
local itemCollectedTemplateInstance = templatesFolder:WaitForChild(ITEM_COLLECTED_TEMPLATE_NAME)
assert(itemCollectedTemplateInstance:IsA("TextLabel"), "ReplicatedStorage.Templates.ItemCollected must be a TextLabel")
local itemCollectedTemplate = itemCollectedTemplateInstance :: TextLabel

local itemUsedTemplateInstance = templatesFolder:WaitForChild(ITEM_USED_TEMPLATE_NAME)
assert(itemUsedTemplateInstance:IsA("TextLabel"), "ReplicatedStorage.Templates.ItemUsed must be a TextLabel")
local itemUsedTemplate = itemUsedTemplateInstance :: TextLabel

local ResourceGainToastView = {}
ResourceGainToastView.__index = ResourceGainToastView

local function findRequiredTextLabel(parent: Instance, childName: string): TextLabel
	local child = parent:WaitForChild(childName)
	assert(child:IsA("TextLabel"), string.format("%s.%s must be a TextLabel", parent:GetFullName(), childName))
	return child
end

local function createWidgets(): Widgets
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before creating ResourceGainToastView")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild("GUI")
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")
	local hud = rootGui:WaitForChild(HUD_NAME)
	assert(hud:IsA("Frame"), "GUI.HUD must be a Frame")

	local bottomLeft = hud:WaitForChild(BOTTOM_LEFT_NAME)
	assert(bottomLeft:IsA("Frame"), "GUI.HUD.BottomLeft must be a Frame")

	return {
		moneyText = findRequiredTextLabel(bottomLeft, "MoneyText"),
		appleText = findRequiredTextLabel(bottomLeft, "AppleText"),
		ciderText = findRequiredTextLabel(bottomLeft, "CiderText"),
	}
end

local function getAnchorLabel(widgets: Widgets, anchorId: ToastAnchorId): TextLabel
	if anchorId == "Money" then
		return widgets.moneyText
	end

	if anchorId == "Apple" then
		return widgets.appleText
	end

	return widgets.ciderText
end

local function collectTransparencyTargets(instance: Instance, transparencyTargets: { TransparencyTarget })
	if instance:IsA("TextLabel") or instance:IsA("TextButton") then
		table.insert(transparencyTargets, {
			instance = instance,
			propertyName = "BackgroundTransparency",
		})
		table.insert(transparencyTargets, {
			instance = instance,
			propertyName = "TextTransparency",
		})
		table.insert(transparencyTargets, {
			instance = instance,
			propertyName = "TextStrokeTransparency",
		})
	elseif instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		table.insert(transparencyTargets, {
			instance = instance,
			propertyName = "BackgroundTransparency",
		})
		table.insert(transparencyTargets, {
			instance = instance,
			propertyName = "ImageTransparency",
		})
	elseif instance:IsA("Frame") or instance:IsA("ScrollingFrame") or instance:IsA("ViewportFrame") then
		table.insert(transparencyTargets, {
			instance = instance,
			propertyName = "BackgroundTransparency",
		})
	elseif instance:IsA("UIStroke") then
		table.insert(transparencyTargets, {
			instance = instance,
			propertyName = "Transparency",
		})
	end

	for _, child in ipairs(instance:GetChildren()) do
		collectTransparencyTargets(child, transparencyTargets)
	end
end

local function getToastTemplate(templateId: ToastTemplateId): TextLabel
	if templateId == "Collected" then
		return itemCollectedTemplate
	end

	return itemUsedTemplate
end

local function playToast(self: ResourceGainToastView, anchorId: ToastAnchorId, templateId: ToastTemplateId, text: string)
	local anchorLabel = getAnchorLabel(self._widgets, anchorId)
	local toast = getToastTemplate(templateId):Clone()
	local stackIndex = (self._activeToastCountsByAnchorId[anchorId] or 0) + 1
	self._activeToastCountsByAnchorId[anchorId] = stackIndex

	toast.Name = string.format("%s%sToast", anchorId, templateId)
	toast.Text = text
	toast.Visible = true
	toast.Rotation = START_ROTATION_DEGREES
	toast.ZIndex = anchorLabel.ZIndex + 1
	local startPosition = UDim2.new(
		0,
		0,
		0,
		0
	)
	toast.Position = startPosition
	toast.Parent = anchorLabel

	local movementTween = TweenService:Create(toast, TOAST_TWEEN_INFO, {
		Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset,
			startPosition.Y.Scale,
			startPosition.Y.Offset - FLOAT_DISTANCE
		),
		Rotation = START_ROTATION_DEGREES,
	})

	local transparencyTargets: { TransparencyTarget } = {}
	collectTransparencyTargets(toast, transparencyTargets)
	for _, transparencyTarget in ipairs(transparencyTargets) do
		TweenService:Create(transparencyTarget.instance, TOAST_TWEEN_INFO, {
			[transparencyTarget.propertyName] = 1,
		}):Play()
	end

	movementTween.Completed:Connect(function()
		local activeCount = self._activeToastCountsByAnchorId[anchorId]
		if activeCount ~= nil then
			self._activeToastCountsByAnchorId[anchorId] = math.max(activeCount - 1, 0)
		end
		toast:Destroy()
	end)
	movementTween:Play()
end

function ResourceGainToastView.new(): ResourceGainToastView
	local self = setmetatable({
		_widgets = createWidgets(),
		_activeToastCountsByAnchorId = {},
	}, ResourceGainToastView) :: ResourceGainToastView

	return self
end

function ResourceGainToastView:showCashGain(amount: number)
	if amount <= 0 then
		return
	end

	playToast(self, "Money", "Collected", string.format("+$%s", NumberFormatter.formatAbbreviated(amount)))
end

function ResourceGainToastView:showCashUsed(amount: number)
	if amount <= 0 then
		return
	end

	playToast(self, "Money", "Used", string.format("-$%s", NumberFormatter.formatAbbreviated(amount)))
end

function ResourceGainToastView:showAppleGain(amount: number)
	if amount <= 0 then
		return
	end

	playToast(self, "Apple", "Collected", string.format("+%s", NumberFormatter.formatAbbreviated(amount)))
end

function ResourceGainToastView:showCiderGain(amount: number)
	if amount <= 0 then
		return
	end

	playToast(self, "Cider", "Collected", string.format("+%s", NumberFormatter.formatAbbreviated(amount)))
end

function ResourceGainToastView:showCiderUsed(amount: number)
	if amount <= 0 then
		return
	end

	playToast(self, "Cider", "Used", string.format("-%s", NumberFormatter.formatAbbreviated(amount)))
end

function ResourceGainToastView:destroy()
end

return ResourceGainToastView

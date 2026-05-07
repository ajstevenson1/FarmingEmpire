--!strict

local Players = game:GetService("Players")

local LABEL_NAMES = {
	moneyText = "MoneyText",
	appleText = "AppleText",
	ciderText = "CiderText",
}

type Widgets = {
	moneyText: TextLabel,
	appleText: TextLabel,
	ciderText: TextLabel,
}

export type ResourceStatusView = {
	_widgets: Widgets,
	render: (self: ResourceStatusView, apples: number, cider: number, cash: number) -> (),
	destroy: (self: ResourceStatusView) -> (),
}

local ResourceStatusView = {}
ResourceStatusView.__index = ResourceStatusView

local function getGuiRoot(playerGui: PlayerGui): ScreenGui
	local rootGui = playerGui:WaitForChild("GUI")
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")
	return rootGui
end

local function findRequiredTextLabel(parent: Instance, childName: string): TextLabel
	local child = parent:WaitForChild(childName)
	assert(child:IsA("TextLabel"), string.format("%s.%s must be a TextLabel", parent:GetFullName(), childName))
	return child
end

local function createWidgets(): Widgets
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before creating ResourceStatusView")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = getGuiRoot(playerGui)

	local hud = rootGui:WaitForChild("HUD")
	assert(hud:IsA("Frame"), "GUI.HUD must be a Frame")

	local bottomLeft = hud:WaitForChild("BottomLeft")
	assert(bottomLeft:IsA("Frame"), "GUI.HUD.BottomLeft must be a Frame")

	return {
		moneyText = findRequiredTextLabel(bottomLeft, LABEL_NAMES.moneyText),
		appleText = findRequiredTextLabel(bottomLeft, LABEL_NAMES.appleText),
		ciderText = findRequiredTextLabel(bottomLeft, LABEL_NAMES.ciderText),
	}
end

function ResourceStatusView.new(): ResourceStatusView
	local self = setmetatable({
		_widgets = createWidgets(),
	}, ResourceStatusView) :: ResourceStatusView

	return self
end

function ResourceStatusView:render(apples: number, cider: number, cash: number)
	self._widgets.moneyText.Text = tostring(cash)
	self._widgets.appleText.Text = tostring(apples)
	self._widgets.ciderText.Text = tostring(cider)
end

function ResourceStatusView:destroy()
end

return ResourceStatusView

--!strict

local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before creating AutoHarvestView")

export type AutoHarvestView = {
	_button: TextButton,
	_stroke: UIStroke,
	_isEnabled: boolean,
	_toggleCallbacks: { () -> () },
	connectToggleRequested: (self: AutoHarvestView, callback: () -> ()) -> (),
	setVisible: (self: AutoHarvestView, isVisible: boolean) -> (),
	setEnabled: (self: AutoHarvestView, isEnabled: boolean) -> (),
	destroy: (self: AutoHarvestView) -> (),
}

local AutoHarvestView = {}
AutoHarvestView.__index = AutoHarvestView

local ACTIVE_STROKE_COLOR = Color3.fromRGB(255, 255, 255)
local INACTIVE_STROKE_COLOR = Color3.fromRGB(0, 0, 0)

local function getRootGui(): ScreenGui
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild("GUI")
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")
	return rootGui
end

local function getHud(rootGui: ScreenGui): GuiObject
	local hud = rootGui:WaitForChild("HUD")
	assert(hud:IsA("GuiObject"), "GUI.HUD must be a GuiObject")
	return hud
end

local function findStroke(button: TextButton): UIStroke
	local designFrame = button:FindFirstChild("Design")
	if designFrame ~= nil then
		assert(designFrame:IsA("GuiObject"), "GUI.HUD.Right.AutoScythe.Design must be a GuiObject")

		local designStroke = designFrame:FindFirstChild("Stroke")
		assert(designStroke ~= nil, "GUI.HUD.Right.AutoScythe.Design must contain a Stroke child")
		assert(designStroke:IsA("UIStroke"), "GUI.HUD.Right.AutoScythe.Design.Stroke must be a UIStroke")
		return designStroke
	end

	local directStroke = button:FindFirstChildWhichIsA("UIStroke")
	assert(directStroke ~= nil, "GUI.HUD.Right.AutoScythe must contain a UIStroke")
	return directStroke
end

local function getAutoScytheButton(hud: GuiObject): (TextButton, UIStroke)
	local rightFrame = hud:WaitForChild("Right")
	assert(rightFrame:IsA("GuiObject"), "GUI.HUD.Right must be a GuiObject")

	local button = rightFrame:WaitForChild("AutoScythe")
	assert(button:IsA("TextButton"), "GUI.HUD.Right.AutoScythe must be a TextButton")

	return button, findStroke(button)
end

function AutoHarvestView.new(): AutoHarvestView
	local rootGui = getRootGui()
	local hud = getHud(rootGui)
	local oldCreatedButton = hud:FindFirstChild("AutoHarvestButton")
	if oldCreatedButton ~= nil then
		oldCreatedButton:Destroy()
	end

	local button, stroke = getAutoScytheButton(hud)
	button.Visible = false
	local self = setmetatable({
		_button = button,
		_stroke = stroke,
		_isEnabled = false,
		_toggleCallbacks = {},
	}, AutoHarvestView) :: AutoHarvestView

	button.Activated:Connect(function()
		for _, callback in ipairs(self._toggleCallbacks) do
			callback()
		end
	end)

	self:setEnabled(false)
	return self
end

function AutoHarvestView:connectToggleRequested(callback: () -> ())
	table.insert(self._toggleCallbacks, callback)
end

function AutoHarvestView:setVisible(isVisible: boolean)
	self._button.Visible = isVisible
end

function AutoHarvestView:setEnabled(isEnabled: boolean)
	self._isEnabled = isEnabled
	self._stroke.Color = if isEnabled then ACTIVE_STROKE_COLOR else INACTIVE_STROKE_COLOR
end

function AutoHarvestView:destroy()
	self._button.Visible = false
	table.clear(self._toggleCallbacks)
end

return AutoHarvestView

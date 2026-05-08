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

local BUTTON_SIZE = UDim2.fromOffset(132, 44)
local BUTTON_POSITION = UDim2.new(1, -24, 1, -112)
local INACTIVE_COLOR = Color3.fromRGB(35, 42, 38)
local ACTIVE_COLOR = Color3.fromRGB(45, 116, 72)
local STROKE_INACTIVE_COLOR = Color3.fromRGB(197, 215, 189)
local STROKE_ACTIVE_COLOR = Color3.fromRGB(221, 255, 216)
local TEXT_COLOR = Color3.fromRGB(246, 248, 239)

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

local function createButton(parent: Instance): (TextButton, UIStroke)
	local button = Instance.new("TextButton")
	button.Name = "AutoHarvestButton"
	button.AnchorPoint = Vector2.new(1, 1)
	button.AutoButtonColor = true
	button.BackgroundColor3 = INACTIVE_COLOR
	button.BackgroundTransparency = 0.08
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Position = BUTTON_POSITION
	button.Size = BUTTON_SIZE
	button.Text = "Auto"
	button.TextColor3 = TEXT_COLOR
	button.TextSize = 16
	button.Visible = false
	button.ZIndex = 25
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = STROKE_INACTIVE_COLOR
	stroke.Thickness = 1
	stroke.Transparency = 0.15
	stroke.Parent = button

	return button, stroke
end

function AutoHarvestView.new(): AutoHarvestView
	local rootGui = getRootGui()
	local hud = getHud(rootGui)
	local existingButton = hud:FindFirstChild("AutoHarvestButton")
	if existingButton ~= nil then
		existingButton:Destroy()
	end

	local button, stroke = createButton(hud)
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
	self._button.Text = if isEnabled then "Auto On" else "Auto"
	self._button.BackgroundColor3 = if isEnabled then ACTIVE_COLOR else INACTIVE_COLOR
	self._stroke.Color = if isEnabled then STROKE_ACTIVE_COLOR else STROKE_INACTIVE_COLOR
end

function AutoHarvestView:destroy()
	self._button:Destroy()
	table.clear(self._toggleCallbacks)
end

return AutoHarvestView

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local formattingFolder = sharedFolder:WaitForChild("Formatting") :: Folder

local NumberFormatter = require(formattingFolder:WaitForChild("NumberFormatter") :: ModuleScript)

local ROOT_GUI_NAME = "GUI"
local HUD_NAME = "HUD"
local TOP_NAME = "Top"
local TEXT_NAME = "Text"
local VALUE_LABEL_NAME = "OfflineValue"

export type OfflineRateView = {
	_valueLabel: TextLabel,
	render: (self: OfflineRateView, ciderPerHour: number) -> (),
	destroy: (self: OfflineRateView) -> (),
}

local OfflineRateView = {}
OfflineRateView.__index = OfflineRateView

local function getGuiRoot(playerGui: PlayerGui): ScreenGui
	local rootGui = playerGui:WaitForChild(ROOT_GUI_NAME)
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")
	return rootGui
end

local function getValueLabel(): TextLabel
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before creating OfflineRateView")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = getGuiRoot(playerGui)
	local hud = rootGui:WaitForChild(HUD_NAME)
	assert(hud:IsA("Frame"), "GUI.HUD must be a Frame")

	local top = hud:WaitForChild(TOP_NAME)
	assert(top:IsA("Frame"), "GUI.HUD.Top must be a Frame")

	local textFrame = top:WaitForChild(TEXT_NAME)
	assert(textFrame:IsA("Frame"), "GUI.HUD.Top.Text must be a Frame")

	local valueLabel = textFrame:WaitForChild(VALUE_LABEL_NAME)
	assert(valueLabel:IsA("TextLabel"), "GUI.HUD.Top.Text.OfflineValue must be a TextLabel")
	return valueLabel
end

local function formatOfflineRate(ciderPerHour: number): string
	local roundedRate = math.max(0, math.floor(ciderPerHour + 0.5))
	return string.format("+%s/hr", NumberFormatter.formatAbbreviated(roundedRate, {
		decimalPlaces = 1,
		trimTrailingZeros = true,
	}))
end

function OfflineRateView.new(): OfflineRateView
	local self = setmetatable({
		_valueLabel = getValueLabel(),
	}, OfflineRateView) :: OfflineRateView

	return self
end

function OfflineRateView:render(ciderPerHour: number)
	self._valueLabel.Text = formatOfflineRate(ciderPerHour)
end

function OfflineRateView:destroy()
end

return OfflineRateView

--!strict

local Players = game:GetService("Players")

local ROOT_GUI_NAME = "GUI"
local HUD_NAME = "HUD"
local TOP_NAME = "Top"
local EVENT_FRAME_NAME = "Event"
local EVENT_LABEL_NAME = "Event"

export type WeatherEventHudView = {
	_label: TextLabel,
	render: (self: WeatherEventHudView, displayMessage: string) -> (),
	destroy: (self: WeatherEventHudView) -> (),
}

local WeatherEventHudView = {}
WeatherEventHudView.__index = WeatherEventHudView

local function getEventLabel(): TextLabel
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before creating WeatherEventHudView")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild(ROOT_GUI_NAME)
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")

	local hud = rootGui:WaitForChild(HUD_NAME)
	assert(hud:IsA("Frame"), "GUI.HUD must be a Frame")

	local top = hud:WaitForChild(TOP_NAME)
	assert(top:IsA("Frame"), "GUI.HUD.Top must be a Frame")

	local eventFrame = top:WaitForChild(EVENT_FRAME_NAME)
	assert(eventFrame:IsA("Frame"), "GUI.HUD.Top.Event must be a Frame")

	local eventLabel = eventFrame:WaitForChild(EVENT_LABEL_NAME)
	assert(eventLabel:IsA("TextLabel"), "GUI.HUD.Top.Event.Event must be a TextLabel")
	return eventLabel
end

function WeatherEventHudView.new(): WeatherEventHudView
	local label = getEventLabel()
	label.RichText = true

	local self = setmetatable({
		_label = label,
	}, WeatherEventHudView) :: WeatherEventHudView

	return self
end

function WeatherEventHudView:render(displayMessage: string)
	self._label.Text = displayMessage
end

function WeatherEventHudView:destroy()
end

return WeatherEventHudView

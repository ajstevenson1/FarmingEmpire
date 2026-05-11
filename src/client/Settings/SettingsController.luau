--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local settingsFolder = sharedFolder:WaitForChild("Settings") :: Folder

local AudioService = require(script.Parent.Parent.Audio.AudioService)
local FrameManager = require(script.Parent.Parent.UI.FrameManager)
local Slider = require(script.Parent.Parent.UI.Slider)
local SettingsConfig = require(settingsFolder:WaitForChild("SettingsConfig") :: ModuleScript)

type SettingId = SettingsConfig.SettingId
type SettingDefinition = SettingsConfig.SettingDefinition
type SettingsValues = SettingsConfig.SettingsValues
type SliderInstance = Slider.Slider
type GuiButtonLike = TextButton | ImageButton
type AudioBusId = "Music" | "SFX"

type SettingWidgets = {
	container: GuiObject,
	sliderTrack: GuiObject,
	filledBar: GuiObject,
	knob: GuiButtonLike,
}

local SETTINGS_FRAME_ID = "Settings"
local MENU_FRAME_GROUP = "Menu"

local hasStarted = false
local slidersById: { [SettingId]: SliderInstance } = {}
local valuesById: SettingsValues = SettingsConfig.getDefaultValues()

local function getRootGui(): ScreenGui
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before starting SettingsController")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild("GUI")
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")
	return rootGui
end

local function getRequiredChild(parent: Instance, childName: string, className: string): Instance
	local child = parent:FindFirstChild(childName)
	assert(child ~= nil, string.format("%s must contain a child named %s", parent:GetFullName(), childName))
	assert(child:IsA(className), string.format("%s.%s must be a %s", parent:GetFullName(), childName, className))
	return child
end

local function getRequiredGuiButton(parent: Instance, childName: string): GuiButtonLike
	local child = parent:FindFirstChild(childName)
	assert(child ~= nil, string.format("%s must contain a child named %s", parent:GetFullName(), childName))
	assert(
		child:IsA("TextButton") or child:IsA("ImageButton"),
		string.format("%s.%s must be a TextButton or ImageButton", parent:GetFullName(), childName)
	)
	return child :: GuiButtonLike
end

local function getSettingsFrame(rootGui: ScreenGui): Frame
	local frames = getRequiredChild(rootGui, "Frames", "Frame")
	local settingsFrame = getRequiredChild(frames, "Settings", "Frame")
	return settingsFrame :: Frame
end

local function getClosedPanelPosition(panel: Frame): UDim2
	local panelHeight = math.max(panel.AbsoluteSize.Y, panel.Size.Y.Offset, 64)
	return UDim2.new(panel.Position.X.Scale, panel.Position.X.Offset, 1, panelHeight + 48)
end

local function getOpenButton(rootGui: ScreenGui): GuiButtonLike
	local hud = getRequiredChild(rootGui, "HUD", "GuiObject")
	local left = getRequiredChild(hud, "Left", "GuiObject")
	return getRequiredGuiButton(left, "Settings")
end

local function getSettingWidgets(settingsFrame: Frame, settingId: SettingId): SettingWidgets
	local scrollingFrame = getRequiredChild(settingsFrame, "ScrollingFrame", "ScrollingFrame")
	local container = getRequiredChild(scrollingFrame, settingId, "GuiObject")
	local sliderTrack = getRequiredChild(container, "Slider", "GuiObject")
	local filledBar = getRequiredChild(sliderTrack, "Filled", "GuiObject")
	local knobInstance = getRequiredGuiButton(sliderTrack, "Knob")

	return {
		container = container :: GuiObject,
		sliderTrack = sliderTrack :: GuiObject,
		filledBar = filledBar :: GuiObject,
		knob = knobInstance,
	}
end

local function applySetting(definition: SettingDefinition, value: number)
	if definition.soundGroupName == nil then
		return
	end

	AudioService.setBusVolume(definition.soundGroupName :: AudioBusId, value)
end

local function bindSettingSlider(settingsFrame: Frame, definition: SettingDefinition)
	local widgets = getSettingWidgets(settingsFrame, definition.id)
	local slider = Slider.new(widgets.sliderTrack, widgets.filledBar, widgets.knob, {
		defaultValue = valuesById[definition.id],
		step = definition.step,
	})

	slider:connectChanged(function(value: number)
		valuesById[definition.id] = value
		applySetting(definition, value)
	end)

	slidersById[definition.id] = slider
	slider:setValue(valuesById[definition.id], false)
	applySetting(definition, valuesById[definition.id])
end

local SettingsController = {}

function SettingsController.start()
	if hasStarted then
		return
	end

	hasStarted = true
	AudioService.start()

	local rootGui = getRootGui()
	local settingsFrame = getSettingsFrame(rootGui)
	local openButton = getOpenButton(rootGui)

	FrameManager.registerFrame({
		id = SETTINGS_FRAME_ID,
		frame = settingsFrame,
		group = MENU_FRAME_GROUP,
		defaultOpen = settingsFrame.Visible,
		closedPosition = getClosedPanelPosition(settingsFrame),
	})

	for _, definition in ipairs(SettingsConfig.getAllSettingDefinitions()) do
		bindSettingSlider(settingsFrame, definition)
	end

	openButton.Activated:Connect(function()
		FrameManager.toggle(SETTINGS_FRAME_ID)
	end)

	settingsFrame.Destroying:Connect(function()
		for settingId, slider in pairs(slidersById) do
			slider:destroy()
			slidersById[settingId] = nil
		end
	end)
end

function SettingsController.getValue(settingId: SettingId): number
	return valuesById[settingId]
end

return table.freeze(SettingsController)

--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local uiFolder = sharedFolder:WaitForChild("UI") :: Folder
local CoreMenuLeavePromptConfig = require(uiFolder:WaitForChild("CoreMenuLeavePromptConfig") :: ModuleScript)

export type CoreMenuLeavePromptController = {
	start: () -> (),
	destroy: () -> (),
}

type PromptWidgets = {
	frames: { Frame },
	gradients: { UIGradient },
}

type ControllerState = {
	widgets: PromptWidgets?,
	isMenuOpen: boolean,
	hasWarnedMissingWidgets: boolean,
	menuOpenedConnection: RBXScriptConnection?,
	menuClosedConnection: RBXScriptConnection?,
	renderConnection: RBXScriptConnection?,
}

local state: ControllerState = {
	widgets = nil,
	isMenuOpen = false,
	hasWarnedMissingWidgets = false,
	menuOpenedConnection = nil,
	menuClosedConnection = nil,
	renderConnection = nil,
}

local hasStarted = false

local function getRootGui(): ScreenGui?
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before starting CoreMenuLeavePromptController")

	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if playerGui == nil or not playerGui:IsA("PlayerGui") then
		return nil
	end

	local rootGui = playerGui:FindFirstChild(CoreMenuLeavePromptConfig.RootGuiName)
	if rootGui == nil then
		return nil
	end

	assert(rootGui:IsA("ScreenGui"), string.format("PlayerGui.%s must be a ScreenGui", CoreMenuLeavePromptConfig.RootGuiName))

	return rootGui
end

local function getContainer(rootGui: ScreenGui): Instance?
	local container = rootGui:FindFirstChild(CoreMenuLeavePromptConfig.ContainerName)
	if container == nil then
		return nil
	end

	assert(
		container:IsA("GuiObject") or container:IsA("Folder"),
		string.format(
			"PlayerGui.%s.%s must be a GuiObject or Folder",
			CoreMenuLeavePromptConfig.RootGuiName,
			CoreMenuLeavePromptConfig.ContainerName
		)
	)

	return container
end

local function getLeaveFrame(container: Instance, frameName: string): Frame?
	local frame = container:FindFirstChild(frameName)
	if frame == nil then
		return nil
	end

	assert(
		frame:IsA("Frame"),
		string.format(
			"PlayerGui.%s.%s.%s must be a Frame",
			CoreMenuLeavePromptConfig.RootGuiName,
			CoreMenuLeavePromptConfig.ContainerName,
			frameName
		)
	)

	return frame
end

local function getTextLabel(frame: Frame): TextLabel?
	local textLabel = frame:FindFirstChild(CoreMenuLeavePromptConfig.TextLabelName)
	if textLabel == nil then
		return nil
	end

	assert(
		textLabel:IsA("TextLabel"),
		string.format(
			"PlayerGui.%s.%s.%s.%s must be a TextLabel",
			CoreMenuLeavePromptConfig.RootGuiName,
			CoreMenuLeavePromptConfig.ContainerName,
			frame.Name,
			CoreMenuLeavePromptConfig.TextLabelName
		)
	)

	return textLabel
end

local function warnMissingWidgets()
	if state.hasWarnedMissingWidgets then
		return
	end

	state.hasWarnedMissingWidgets = true
	warn(string.format(
		"[CoreMenuLeavePromptController] Create PlayerGui.%s.%s.%s.%s and PlayerGui.%s.%s.%s.%s in Studio to show the escape menu leave prompt.",
		CoreMenuLeavePromptConfig.RootGuiName,
		CoreMenuLeavePromptConfig.ContainerName,
		CoreMenuLeavePromptConfig.FrameNames[1],
		CoreMenuLeavePromptConfig.TextLabelName,
		CoreMenuLeavePromptConfig.RootGuiName,
		CoreMenuLeavePromptConfig.ContainerName,
		CoreMenuLeavePromptConfig.FrameNames[2],
		CoreMenuLeavePromptConfig.TextLabelName
	))
end

local function getOrCreateGradient(textLabel: TextLabel): UIGradient
	local existingGradient = textLabel:FindFirstChildOfClass("UIGradient")
	if existingGradient ~= nil then
		local gradient = existingGradient :: UIGradient
		gradient.Name = CoreMenuLeavePromptConfig.GradientName
		gradient.Color = CoreMenuLeavePromptConfig.RainbowGradient
		gradient.Rotation = CoreMenuLeavePromptConfig.GradientRotationDegrees
		return gradient
	end

	local gradient = Instance.new("UIGradient")
	gradient.Name = CoreMenuLeavePromptConfig.GradientName
	gradient.Color = CoreMenuLeavePromptConfig.RainbowGradient
	gradient.Rotation = CoreMenuLeavePromptConfig.GradientRotationDegrees
	gradient.Parent = textLabel

	return gradient
end

local function collectWidgets(): PromptWidgets?
	local rootGui = getRootGui()
	if rootGui == nil then
		return nil
	end

	local container = getContainer(rootGui)
	if container == nil then
		return nil
	end

	local frames: { Frame } = {}
	local gradients: { UIGradient } = {}

	for _, frameName in ipairs(CoreMenuLeavePromptConfig.FrameNames) do
		local frame = getLeaveFrame(container, frameName)
		if frame == nil then
			return nil
		end

		local textLabel = getTextLabel(frame)
		if textLabel == nil then
			return nil
		end

		local gradient = getOrCreateGradient(textLabel)

		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		frame.Visible = state.isMenuOpen
		table.insert(frames, frame)
		table.insert(gradients, gradient)
	end

	return {
		frames = frames,
		gradients = gradients,
	}
end

local function getWidgets(): PromptWidgets?
	if state.widgets == nil then
		state.widgets = collectWidgets()
	end

	return state.widgets
end

local function stopGradientAnimation()
	if state.renderConnection ~= nil then
		state.renderConnection:Disconnect()
		state.renderConnection = nil
	end
end

local function setPromptFramesVisible(isVisible: boolean)
	local widgets = getWidgets()
	if widgets == nil then
		warnMissingWidgets()
		return
	end

	for _, frame in ipairs(widgets.frames) do
		frame.Visible = isVisible
	end
end

local function animateGradients()
	local widgets = getWidgets()
	if widgets == nil then
		warnMissingWidgets()
		return
	end

	local offset = ((os.clock() * CoreMenuLeavePromptConfig.GradientSpeedCyclesPerSecond) % 2) - 1

	for _, gradient in ipairs(widgets.gradients) do
		if gradient.Parent == nil then
			state.widgets = nil
			return
		end

		gradient.Offset = Vector2.new(offset, 0)
	end
end

local function startGradientAnimation()
	if state.renderConnection ~= nil then
		return
	end

	animateGradients()
	state.renderConnection = RunService.RenderStepped:Connect(function(_deltaTime: number)
		animateGradients()
	end)
end

local function applyMenuOpenState(isMenuOpen: boolean)
	if state.isMenuOpen == isMenuOpen then
		return
	end

	state.isMenuOpen = isMenuOpen
	setPromptFramesVisible(isMenuOpen)

	if isMenuOpen then
		startGradientAnimation()
	else
		stopGradientAnimation()
	end
end

local CoreMenuLeavePromptController = {} :: CoreMenuLeavePromptController

function CoreMenuLeavePromptController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	state.menuOpenedConnection = GuiService.MenuOpened:Connect(function()
		applyMenuOpenState(true)
	end)

	state.menuClosedConnection = GuiService.MenuClosed:Connect(function()
		applyMenuOpenState(false)
	end)
end

function CoreMenuLeavePromptController.destroy()
	applyMenuOpenState(false)
	stopGradientAnimation()

	if state.menuOpenedConnection ~= nil then
		state.menuOpenedConnection:Disconnect()
		state.menuOpenedConnection = nil
	end

	if state.menuClosedConnection ~= nil then
		state.menuClosedConnection:Disconnect()
		state.menuClosedConnection = nil
	end

	state.widgets = nil
	state.isMenuOpen = false
	state.hasWarnedMissingWidgets = false
	hasStarted = false
end

return table.freeze(CoreMenuLeavePromptController)

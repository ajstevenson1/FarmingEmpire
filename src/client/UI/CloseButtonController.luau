--!strict

local Players = game:GetService("Players")

local FrameManager = require(script.Parent.FrameManager)

type GuiButtonLike = TextButton | ImageButton

export type CloseButtonController = {
	start: () -> (),
	destroy: () -> (),
}

local ROOT_GUI_NAME = "GUI"
local CLOSE_TAG_ATTRIBUTE_NAME = "Tag"
local CLOSE_TAG_ATTRIBUTE_VALUE = "Close"

local hasStarted = false
local rootConnection: RBXScriptConnection? = nil
local boundConnectionsByButton: { [GuiButtonLike]: RBXScriptConnection } = {}

local function isGuiButtonLike(instance: Instance): boolean
	return instance:IsA("TextButton") or instance:IsA("ImageButton")
end

local function isCloseButton(button: GuiButtonLike): boolean
	return button:GetAttribute(CLOSE_TAG_ATTRIBUTE_NAME) == CLOSE_TAG_ATTRIBUTE_VALUE
end

local function unbindButton(button: GuiButtonLike)
	local connection = boundConnectionsByButton[button]
	if connection == nil then
		return
	end

	connection:Disconnect()
	boundConnectionsByButton[button] = nil
end

local function bindButton(button: GuiButtonLike)
	if boundConnectionsByButton[button] ~= nil or not isCloseButton(button) then
		return
	end

	boundConnectionsByButton[button] = button.Activated:Connect(function()
		local frameId = FrameManager.getFrameIdForInstance(button)
		if frameId == nil then
			return
		end

		FrameManager.close(frameId)
	end)

	button.Destroying:Connect(function()
		unbindButton(button)
	end)
end

local function bindDescendantTree(rootGui: ScreenGui)
	for _, descendant in ipairs(rootGui:GetDescendants()) do
		if isGuiButtonLike(descendant) then
			bindButton(descendant :: GuiButtonLike)
		end
	end
end

local CloseButtonController = {} :: CloseButtonController

function CloseButtonController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before starting CloseButtonController")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild(ROOT_GUI_NAME)
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")

	bindDescendantTree(rootGui)

	rootConnection = rootGui.DescendantAdded:Connect(function(descendant: Instance)
		if isGuiButtonLike(descendant) then
			bindButton(descendant :: GuiButtonLike)
		end
	end)
end

function CloseButtonController.destroy()
	if rootConnection ~= nil then
		rootConnection:Disconnect()
		rootConnection = nil
	end

	for button in pairs(table.clone(boundConnectionsByButton)) do
		unbindButton(button)
	end

	hasStarted = false
end

return table.freeze(CloseButtonController)

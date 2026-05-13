--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local FrameManager = require(script.Parent.FrameManager)

local INVENTORY_FRAME_ID = "InventoryMenu"
local MENU_FRAME_GROUP = "Menu"
local HIDDEN_VERTICAL_PADDING = 72
local MIN_HIDDEN_OFFSET = 64
local TWEEN_INFO = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

type BottomNavState = {
	hotbarFrame: Frame?,
	openPosition: UDim2?,
	isHidden: boolean,
	activeTween: Tween?,
	tweenCompletedConnection: RBXScriptConnection?,
	positionConnection: RBXScriptConnection?,
	isApplyingControlledPosition: boolean,
}

local state: BottomNavState = {
	hotbarFrame = nil,
	openPosition = nil,
	isHidden = false,
	activeTween = nil,
	tweenCompletedConnection = nil,
	positionConnection = nil,
	isApplyingControlledPosition = false,
}

local hasStarted = false

local function getHotbarFrame(): Frame
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before starting BottomNavController")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild("GUI")
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")

	local hud = rootGui:WaitForChild("HUD")
	assert(hud:IsA("GuiObject"), "GUI.HUD must be a GuiObject")

	local inventoryHud = hud:WaitForChild("Inventory")
	assert(inventoryHud:IsA("GuiObject"), "GUI.HUD.Inventory must be a GuiObject")

	local hotbarFrame = inventoryHud:WaitForChild("hotBar")
	assert(hotbarFrame:IsA("Frame"), "GUI.HUD.Inventory.hotBar must be a Frame")

	return hotbarFrame
end

local function getHiddenPosition(hotbarFrame: Frame, openPosition: UDim2): UDim2
	local hiddenOffset = math.max(hotbarFrame.AbsoluteSize.Y, hotbarFrame.Size.Y.Offset, MIN_HIDDEN_OFFSET)
		+ HIDDEN_VERTICAL_PADDING

	return UDim2.new(
		openPosition.X.Scale,
		openPosition.X.Offset,
		openPosition.Y.Scale,
		openPosition.Y.Offset + hiddenOffset
	)
end

local function clearActiveTween()
	local tweenCompletedConnection = state.tweenCompletedConnection
	if tweenCompletedConnection ~= nil then
		tweenCompletedConnection:Disconnect()
		state.tweenCompletedConnection = nil
	end

	state.activeTween = nil
end

local function cancelActiveTween()
	local activeTween = state.activeTween
	if activeTween ~= nil then
		activeTween:Cancel()
	end

	clearActiveTween()
end

local function playTransition(targetPosition: UDim2)
	local hotbarFrame = state.hotbarFrame
	if hotbarFrame == nil then
		return
	end

	cancelActiveTween()

	local tween = TweenService:Create(hotbarFrame, TWEEN_INFO, {
		Position = targetPosition,
	})

	state.activeTween = tween
	state.tweenCompletedConnection = tween.Completed:Connect(function()
		clearActiveTween()
	end)

	tween:Play()
end

local function setHidden(shouldHide: boolean)
	local hotbarFrame = state.hotbarFrame
	if hotbarFrame == nil or state.isHidden == shouldHide then
		return
	end

	if shouldHide then
		local openPosition = state.openPosition or hotbarFrame.Position
		state.openPosition = openPosition
		state.isHidden = true
		playTransition(getHiddenPosition(hotbarFrame, openPosition))
		return
	end

	state.isHidden = false
	playTransition(state.openPosition or hotbarFrame.Position)
end

local function refreshHiddenState()
	local openMenuFrameId = FrameManager.getOpenFrame(MENU_FRAME_GROUP)
	setHidden(openMenuFrameId ~= nil and openMenuFrameId ~= INVENTORY_FRAME_ID)
end

local function bindLayoutPositionTracking(hotbarFrame: Frame)
	local existingConnection = state.positionConnection
	if existingConnection ~= nil then
		existingConnection:Disconnect()
	end

	state.positionConnection = hotbarFrame:GetPropertyChangedSignal("Position"):Connect(function()
		if state.isApplyingControlledPosition or state.activeTween ~= nil then
			return
		end

		if not state.isHidden then
			state.openPosition = hotbarFrame.Position
			return
		end

		state.openPosition = hotbarFrame.Position
		state.isApplyingControlledPosition = true
		hotbarFrame.Position = getHiddenPosition(hotbarFrame, state.openPosition)
		state.isApplyingControlledPosition = false
	end)
end

local BottomNavController = {}

function BottomNavController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local hotbarFrame = getHotbarFrame()
	state.hotbarFrame = hotbarFrame
	state.openPosition = hotbarFrame.Position
	bindLayoutPositionTracking(hotbarFrame)

	FrameManager.observeFrameOpened(function(_frameId: string)
		refreshHiddenState()
	end)

	FrameManager.observeFrameClosed(function(_frameId: string)
		refreshHiddenState()
	end)

	refreshHiddenState()
end

return table.freeze(BottomNavController)

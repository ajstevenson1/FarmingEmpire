--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before starting pickup")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder

local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local HudTooltipModule = require(script.Parent.Parent.UI.HudTooltip)
local PlacedBuildingTargeting = require(script.Parent.PlacedBuildingTargeting)
local StructureActionMode = require(script.Parent.StructureActionMode)
local StructureSelectionViewModule = require(script.Parent.StructureSelectionView)

type StructureSelectionView = StructureSelectionViewModule.StructureSelectionView
type HudTooltip = HudTooltipModule.HudTooltip

type Widgets = {
	button: TextButton,
	stroke: UIStroke,
}

local PICKUP_MODE_ID = "Pickup"
local PICKUP_TOOLTIP_OWNER_ID = "Pickup"
local PICKUP_SELECTION_BOX_COLOR = Color3.fromRGB(112, 212, 123)
local PICKUP_SELECTION_BOX_NAME = "PickupSelectionBox"

local hasStarted = false
local widgets: Widgets? = nil
local pickupAllButton: TextButton? = nil
local selectionView: StructureSelectionView? = nil
local currentPickupTarget: BasePart? = nil
local hudTooltip: HudTooltip? = nil
local connections: { RBXScriptConnection } = {}
local disconnectModeObserver: (() -> ())? = nil

local ACTIVE_STROKE_COLOR = Color3.fromRGB(255, 255, 255)
local INACTIVE_STROKE_COLOR = Color3.fromRGB(0, 0, 0)
local DESKTOP_PICKUP_TOOLTIP_TEXT = "Click to pick up"
local GAMEPAD_PICKUP_TOOLTIP_TEXT = "Press right trigger to pick up"
local MOBILE_PICKUP_TOOLTIP_TEXT = "Tap to select"
local MOBILE_PICKUP_SELECTED_TOOLTIP_TEXT = "Tap again to pick up"
local PICKUP_CANCEL_KEYCODE = Enum.KeyCode.ButtonB
local PICKUP_CONFIRM_KEYCODE = Enum.KeyCode.ButtonR2

local function getRequestPickupRemote(): RemoteEvent
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local placementRemotesFolder = rootFolder:WaitForChild(RemoteNames.placementFolderName) :: Folder
	return placementRemotesFolder:WaitForChild(RemoteNames.requestPickupEventName) :: RemoteEvent
end

local function getRequestPickupAllRemote(): RemoteEvent
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local placementRemotesFolder = rootFolder:WaitForChild(RemoteNames.placementFolderName) :: Folder
	return placementRemotesFolder:WaitForChild(RemoteNames.requestPickupAllEventName) :: RemoteEvent
end

local function getSetSelectedSlotRemote(): RemoteEvent
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local inventoryRemotesFolder = rootFolder:WaitForChild(RemoteNames.inventoryFolderName) :: Folder
	return inventoryRemotesFolder:WaitForChild(RemoteNames.setSelectedSlotEventName) :: RemoteEvent
end

local function clearPickupTarget()
	currentPickupTarget = nil

	local currentSelectionView = selectionView
	if currentSelectionView ~= nil then
		currentSelectionView:hide()
	end
end

local function isMobilePickupInput(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.GamepadEnabled
end

local function isGamepadPickupInput(): boolean
	return UserInputService.GamepadEnabled and not isMobilePickupInput()
end

local function isPickupModeEnabled(): boolean
	return StructureActionMode.isModeActive(PICKUP_MODE_ID)
end

local function updatePickupTooltip()
	local tooltip = hudTooltip
	if tooltip == nil then
		return
	end

	if not isPickupModeEnabled() then
		tooltip:hide(PICKUP_TOOLTIP_OWNER_ID)
		return
	end

	if isMobilePickupInput() then
		tooltip:show(
			if currentPickupTarget == nil then MOBILE_PICKUP_TOOLTIP_TEXT else MOBILE_PICKUP_SELECTED_TOOLTIP_TEXT,
			false,
			PICKUP_TOOLTIP_OWNER_ID
		)
	elseif isGamepadPickupInput() then
		tooltip:show(GAMEPAD_PICKUP_TOOLTIP_TEXT, false, PICKUP_TOOLTIP_OWNER_ID)
	else
		tooltip:show(DESKTOP_PICKUP_TOOLTIP_TEXT, false, PICKUP_TOOLTIP_OWNER_ID)
	end
end

local function updatePickupSelection()
	local currentSelectionView = selectionView
	if currentSelectionView == nil then
		return
	end

	if not isPickupModeEnabled() or UserInputService:GetFocusedTextBox() ~= nil then
		clearPickupTarget()
		updatePickupTooltip()
		return
	end

	if isMobilePickupInput() then
		local pickupTarget = currentPickupTarget
		if pickupTarget ~= nil and pickupTarget.Parent ~= nil then
			currentSelectionView:show(pickupTarget)
		else
			clearPickupTarget()
		end
		updatePickupTooltip()
		return
	end

	local pickupTarget = PlacedBuildingTargeting.getCurrentTarget(localPlayer)
	if pickupTarget == nil then
		clearPickupTarget()
		updatePickupTooltip()
		return
	end

	currentPickupTarget = pickupTarget
	currentSelectionView:show(pickupTarget)
	updatePickupTooltip()
end

local function renderButton(buttonWidgets: Widgets)
	buttonWidgets.stroke.Color = if isPickupModeEnabled() then ACTIVE_STROKE_COLOR else INACTIVE_STROKE_COLOR
end

local function renderPickupAllButton()
	local button = pickupAllButton
	if button ~= nil then
		button.Visible = isPickupModeEnabled()
	end
end

local function handleModeChanged(_mode: StructureActionMode.StructureActionModeId)
	if not isPickupModeEnabled() then
		clearPickupTarget()
	end
	updatePickupTooltip()
	renderPickupAllButton()

	local currentWidgets = widgets
	if currentWidgets ~= nil then
		renderButton(currentWidgets)
	end
end

local function getGuiRoot(playerGui: PlayerGui): ScreenGui
	local rootGui = playerGui:WaitForChild("GUI")
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")
	return rootGui
end

local function findStroke(button: TextButton): UIStroke
	local designFrame = button:FindFirstChild("Design")
	assert(designFrame ~= nil, "GUI.HUD.Right.Pickup must contain a Design child")
	assert(designFrame:IsA("GuiObject"), "GUI.HUD.Right.Pickup.Design must be a GuiObject")

	local stroke = designFrame:FindFirstChild("Stroke")
	assert(stroke ~= nil, "GUI.HUD.Right.Pickup.Design must contain a Stroke child")
	assert(stroke:IsA("UIStroke"), "GUI.HUD.Right.Pickup.Design.Stroke must be a UIStroke")
	return stroke
end

local function getPickupButton(): Widgets
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = getGuiRoot(playerGui)

	local hud = rootGui:WaitForChild("HUD")
	assert(hud:IsA("Frame"), "GUI.HUD must be a Frame")

	local rightFrame = hud:WaitForChild("Right")
	assert(rightFrame:IsA("Frame"), "GUI.HUD.Right must be a Frame")

	local button = rightFrame:WaitForChild("Pickup")
	assert(button:IsA("TextButton"), "GUI.HUD.Right.Pickup must be a TextButton")
	local stroke = findStroke(button)

	local buttonWidgets = {
		button = button,
		stroke = stroke,
	}

	renderButton(buttonWidgets)

	return {
		button = button,
		stroke = stroke,
	}
end

local function getPickupAllButton(): TextButton
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = getGuiRoot(playerGui)

	local hud = rootGui:WaitForChild("HUD")
	assert(hud:IsA("Frame"), "GUI.HUD must be a Frame")

	local bottomRightFrame = hud:WaitForChild("BottomRight")
	assert(bottomRightFrame:IsA("Frame"), "GUI.HUD.BottomRight must be a Frame")

	local button = bottomRightFrame:WaitForChild("PickupAll")
	assert(button:IsA("TextButton"), "GUI.HUD.BottomRight.PickupAll must be a TextButton")
	button.Visible = isPickupModeEnabled()
	return button
end

local PickupController = {}

function PickupController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local pickupWidgets = getPickupButton()
	widgets = pickupWidgets
	local createdPickupAllButton = getPickupAllButton()
	pickupAllButton = createdPickupAllButton
	hudTooltip = HudTooltipModule.get()
	selectionView = StructureSelectionViewModule.new(PICKUP_SELECTION_BOX_NAME, PICKUP_SELECTION_BOX_COLOR)
	local requestPickupRemote = getRequestPickupRemote()
	local requestPickupAllRemote = getRequestPickupAllRemote()
	local setSelectedSlotRemote = getSetSelectedSlotRemote()
	disconnectModeObserver = StructureActionMode.observeModeChanged(handleModeChanged)

	table.insert(connections, pickupWidgets.button.Activated:Connect(function()
		local nextIsEnabled = not isPickupModeEnabled()
		StructureActionMode.setMode(if nextIsEnabled then PICKUP_MODE_ID else "None")
		if nextIsEnabled then
			setSelectedSlotRemote:FireServer(nil)
		end
		updatePickupTooltip()
	end))

	table.insert(connections, createdPickupAllButton.Activated:Connect(function()
		if not isPickupModeEnabled() then
			return
		end

		clearPickupTarget()
		requestPickupAllRemote:FireServer()
		updatePickupTooltip()
	end))

	table.insert(connections, RunService.RenderStepped:Connect(updatePickupSelection))

	table.insert(connections, UserInputService.InputBegan:Connect(function(inputObject: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if not isPickupModeEnabled() then
			return
		end

		if UserInputService:GetFocusedTextBox() ~= nil then
			return
		end

		if inputObject.KeyCode == PICKUP_CANCEL_KEYCODE then
			StructureActionMode.clearMode()
			return
		end

		local isConfirmInput = inputObject.UserInputType == Enum.UserInputType.MouseButton1
			or inputObject.KeyCode == PICKUP_CONFIRM_KEYCODE
		if not isConfirmInput then
			return
		end

		local pickupTarget = currentPickupTarget
		if pickupTarget == nil then
			return
		end

		requestPickupRemote:FireServer(pickupTarget)
		clearPickupTarget()
		updatePickupTooltip()
	end))

	table.insert(connections, UserInputService.TouchTap:Connect(function(touchPositions: { Vector2 }, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if not isPickupModeEnabled() or not isMobilePickupInput() then
			return
		end

		if UserInputService:GetFocusedTextBox() ~= nil then
			return
		end

		local tapPosition = touchPositions[1]
		if tapPosition == nil then
			return
		end

		local tappedTarget = PlacedBuildingTargeting.getCurrentTarget(localPlayer, tapPosition)
		if tappedTarget == nil then
			clearPickupTarget()
			updatePickupTooltip()
			return
		end

		if currentPickupTarget == tappedTarget then
			requestPickupRemote:FireServer(tappedTarget)
			clearPickupTarget()
			updatePickupTooltip()
			return
		end

		currentPickupTarget = tappedTarget
		local currentSelectionView = selectionView
		if currentSelectionView ~= nil then
			currentSelectionView:show(tappedTarget)
		end
		updatePickupTooltip()
	end))
end

function PickupController.isPickupModeEnabled(): boolean
	return isPickupModeEnabled()
end

function PickupController.disablePickupMode()
	if isPickupModeEnabled() then
		StructureActionMode.clearMode()
	end
end

function PickupController.destroy()
	local pickupWidgets = widgets
	if pickupWidgets == nil then
		return
	end

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)

	if disconnectModeObserver ~= nil then
		disconnectModeObserver()
		disconnectModeObserver = nil
	end

	PickupController.disablePickupMode()
	local currentPickupAllButton = pickupAllButton
	if currentPickupAllButton ~= nil then
		currentPickupAllButton.Visible = false
	end

	local tooltip = hudTooltip
	if tooltip ~= nil then
		tooltip:hide(PICKUP_TOOLTIP_OWNER_ID)
	end

	local currentSelectionView = selectionView
	if currentSelectionView ~= nil then
		currentSelectionView:destroy()
	end

	selectionView = nil
	pickupAllButton = nil
	widgets = nil
	hudTooltip = nil
	hasStarted = false
end

return table.freeze(PickupController)

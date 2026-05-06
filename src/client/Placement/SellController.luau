--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before starting sell")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder

local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local PlacedBuildingTargeting = require(script.Parent.PlacedBuildingTargeting)
local StructureActionMode = require(script.Parent.StructureActionMode)
local StructureSelectionViewModule = require(script.Parent.StructureSelectionView)

type StructureSelectionView = StructureSelectionViewModule.StructureSelectionView

type Widgets = {
	button: TextButton,
	stroke: UIStroke,
}

local SELL_MODE_ID = "Sell"
local SELL_SELECTION_BOX_COLOR = Color3.fromRGB(214, 72, 72)
local SELL_SELECTION_BOX_NAME = "SellSelectionBox"

local hasStarted = false
local widgets: Widgets? = nil
local selectionView: StructureSelectionView? = nil
local currentSellTarget: BasePart? = nil
local connections: { RBXScriptConnection } = {}
local disconnectModeObserver: (() -> ())? = nil

local ACTIVE_STROKE_COLOR = Color3.fromRGB(255, 255, 255)
local INACTIVE_STROKE_COLOR = Color3.fromRGB(0, 0, 0)

local function getRequestSellRemote(): RemoteEvent
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local placementRemotesFolder = rootFolder:WaitForChild(RemoteNames.placementFolderName) :: Folder
	return placementRemotesFolder:WaitForChild(RemoteNames.requestSellEventName) :: RemoteEvent
end

local function getSetSelectedSlotRemote(): RemoteEvent
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local inventoryRemotesFolder = rootFolder:WaitForChild(RemoteNames.inventoryFolderName) :: Folder
	return inventoryRemotesFolder:WaitForChild(RemoteNames.setSelectedSlotEventName) :: RemoteEvent
end

local function clearSellTarget()
	currentSellTarget = nil

	local currentSelectionView = selectionView
	if currentSelectionView ~= nil then
		currentSelectionView:hide()
	end
end

local function isSellModeEnabled(): boolean
	return StructureActionMode.isModeActive(SELL_MODE_ID)
end

local function updateSellSelection()
	local currentSelectionView = selectionView
	if currentSelectionView == nil then
		return
	end

	if not isSellModeEnabled() or UserInputService:GetFocusedTextBox() ~= nil then
		clearSellTarget()
		return
	end

	local sellTarget = PlacedBuildingTargeting.getCurrentTarget(localPlayer)
	if sellTarget == nil then
		clearSellTarget()
		return
	end

	currentSellTarget = sellTarget
	currentSelectionView:show(sellTarget)
end

local function renderButton(buttonWidgets: Widgets)
	buttonWidgets.stroke.Color = if isSellModeEnabled() then ACTIVE_STROKE_COLOR else INACTIVE_STROKE_COLOR
end

local function handleModeChanged(_mode: StructureActionMode.StructureActionModeId)
	if not isSellModeEnabled() then
		clearSellTarget()
	end

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
	assert(designFrame ~= nil, "GUI.HUD.Right.Sell must contain a Design child")
	assert(designFrame:IsA("GuiObject"), "GUI.HUD.Right.Sell.Design must be a GuiObject")

	local stroke = designFrame:FindFirstChild("Stroke")
	assert(stroke ~= nil, "GUI.HUD.Right.Sell.Design must contain a Stroke child")
	assert(stroke:IsA("UIStroke"), "GUI.HUD.Right.Sell.Design.Stroke must be a UIStroke")
	return stroke
end

local function getSellButton(): Widgets
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = getGuiRoot(playerGui)

	local hud = rootGui:WaitForChild("HUD")
	assert(hud:IsA("Frame"), "GUI.HUD must be a Frame")

	local rightFrame = hud:WaitForChild("Right")
	assert(rightFrame:IsA("Frame"), "GUI.HUD.Right must be a Frame")

	local button = rightFrame:WaitForChild("Sell")
	assert(button:IsA("TextButton"), "GUI.HUD.Right.Sell must be a TextButton")
	local stroke = findStroke(button)

	local buttonWidgets = {
		button = button,
		stroke = stroke,
	}

	renderButton(buttonWidgets)

	return buttonWidgets
end

local SellController = {}

function SellController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local sellWidgets = getSellButton()
	widgets = sellWidgets
	selectionView = StructureSelectionViewModule.new(SELL_SELECTION_BOX_NAME, SELL_SELECTION_BOX_COLOR)
	local requestSellRemote = getRequestSellRemote()
	local setSelectedSlotRemote = getSetSelectedSlotRemote()
	disconnectModeObserver = StructureActionMode.observeModeChanged(handleModeChanged)

	table.insert(connections, sellWidgets.button.Activated:Connect(function()
		local nextIsEnabled = not isSellModeEnabled()
		StructureActionMode.setMode(if nextIsEnabled then SELL_MODE_ID else "None")
		if nextIsEnabled then
			setSelectedSlotRemote:FireServer(nil)
		end
	end))

	table.insert(connections, RunService.RenderStepped:Connect(updateSellSelection))

	table.insert(connections, UserInputService.InputBegan:Connect(function(inputObject: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if not isSellModeEnabled() then
			return
		end

		if UserInputService:GetFocusedTextBox() ~= nil then
			return
		end

		if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		local sellTarget = currentSellTarget
		if sellTarget == nil then
			return
		end

		requestSellRemote:FireServer(sellTarget)
		clearSellTarget()
	end))
end

function SellController.isSellModeEnabled(): boolean
	return isSellModeEnabled()
end

function SellController.disableSellMode()
	if isSellModeEnabled() then
		StructureActionMode.clearMode()
	end
end

function SellController.destroy()
	local sellWidgets = widgets
	if sellWidgets == nil then
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

	SellController.disableSellMode()

	local currentSelectionView = selectionView
	if currentSelectionView ~= nil then
		currentSelectionView:destroy()
	end

	selectionView = nil
	widgets = nil
	hasStarted = false
end

return table.freeze(SellController)

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before starting sell")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local windmillsFolder = sharedFolder:WaitForChild("Windmills") :: Folder

local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local WindmillConfig = require(windmillsFolder:WaitForChild("WindmillConfig") :: ModuleScript)
local ClientInputProfile = require(script.Parent.Parent.Input.ClientInputProfile)
local HudTooltipModule = require(script.Parent.Parent.UI.HudTooltip)
local PlacedBuildingTargeting = require(script.Parent.PlacedBuildingTargeting)
local StructureActionMode = require(script.Parent.StructureActionMode)
local StructureSelectionViewModule = require(script.Parent.StructureSelectionView)

type StructureSelectionView = StructureSelectionViewModule.StructureSelectionView
type BuildingId = BuildingTypes.BuildingId
type HudTooltip = HudTooltipModule.HudTooltip

type Widgets = {
	button: TextButton,
	stroke: UIStroke,
}

local SELL_MODE_ID = "Sell"
local SELL_TOOLTIP_OWNER_ID = "Sell"
local SELL_SELECTION_BOX_COLOR = Color3.fromRGB(214, 72, 72)
local SELL_SELECTION_BOX_NAME = "SellSelectionBox"

local hasStarted = false
local widgets: Widgets? = nil
local selectionView: StructureSelectionView? = nil
local currentSellTarget: BasePart? = nil
local currentBlockedSellTarget: BasePart? = nil
local hudTooltip: HudTooltip? = nil
local connections: { RBXScriptConnection } = {}
local disconnectModeObserver: (() -> ())? = nil

local ACTIVE_STROKE_COLOR = Color3.fromRGB(255, 255, 255)
local INACTIVE_STROKE_COLOR = Color3.fromRGB(0, 0, 0)
local ITEM_ID_ATTRIBUTE = "ItemId"
local MONEY_RICH_TEXT_COLOR = "#40FF70"
local DESKTOP_SELL_TOOLTIP_TEXT = "Click to sell"
local GAMEPAD_SELL_TOOLTIP_TEXT = "Press right trigger to sell"
local MOBILE_SELL_TOOLTIP_TEXT = "Tap to select"
local CANNOT_SELL_WINDMILLS_TOOLTIP_TEXT = "Windmills can't be sold. Use pickup mode to move them."
local SELL_CANCEL_KEYCODE = Enum.KeyCode.ButtonB
local SELL_CONFIRM_KEYCODE = Enum.KeyCode.ButtonR2

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
	currentBlockedSellTarget = nil

	local currentSelectionView = selectionView
	if currentSelectionView ~= nil then
		currentSelectionView:hide()
	end
end

local function isSellModeEnabled(): boolean
	return StructureActionMode.isModeActive(SELL_MODE_ID)
end

local function escapeRichText(text: string): string
	local escapedText = string.gsub(text, "&", "&amp;")
	escapedText = string.gsub(escapedText, "<", "&lt;")
	escapedText = string.gsub(escapedText, ">", "&gt;")
	return escapedText
end

local function getBuildingIdFromTarget(target: BasePart): BuildingId?
	local rawBuildingId = target:GetAttribute(ITEM_ID_ATTRIBUTE)
	if type(rawBuildingId) ~= "string" or not BuildingCatalog.hasBuildingDefinition(rawBuildingId) then
		return nil
	end

	return rawBuildingId :: BuildingId
end

local function isBlockedSellTarget(target: BasePart): boolean
	local buildingId = getBuildingIdFromTarget(target)
	return buildingId ~= nil and WindmillConfig.isWindmillBuildingId(buildingId)
end

local function setBlockedSellTarget(blockedTarget: BasePart)
	currentSellTarget = nil
	currentBlockedSellTarget = blockedTarget

	local currentSelectionView = selectionView
	if currentSelectionView ~= nil then
		currentSelectionView:hide()
	end
end

local function getSellTargetTooltipText(sellTarget: BasePart): string?
	local buildingId = getBuildingIdFromTarget(sellTarget)
	if buildingId == nil then
		return nil
	end

	local buildingDefinition = BuildingCatalog.getBuildingDefinition(buildingId)
	if ClientInputProfile.usesGamepadControls() then
		return string.format(
			"Press right trigger to sell %s for <font color=\"%s\">+$%d</font>",
			escapeRichText(buildingDefinition.displayName),
			MONEY_RICH_TEXT_COLOR,
			buildingDefinition.sellPrice
		)
	end

	return string.format(
		"Sell %s for <font color=\"%s\">+$%d</font>",
		escapeRichText(buildingDefinition.displayName),
		MONEY_RICH_TEXT_COLOR,
		buildingDefinition.sellPrice
	)
end

local function updateSellTooltip()
	local tooltip = hudTooltip
	if tooltip == nil then
		return
	end

	if not isSellModeEnabled() then
		tooltip:hide(SELL_TOOLTIP_OWNER_ID)
		return
	end

	local blockedSellTarget = currentBlockedSellTarget
	if blockedSellTarget ~= nil and blockedSellTarget.Parent ~= nil then
		tooltip:show(CANNOT_SELL_WINDMILLS_TOOLTIP_TEXT, false, SELL_TOOLTIP_OWNER_ID)
		return
	end

	local sellTarget = currentSellTarget
	if sellTarget ~= nil then
		local targetTooltipText = getSellTargetTooltipText(sellTarget)
		if targetTooltipText ~= nil then
			tooltip:show(targetTooltipText, true, SELL_TOOLTIP_OWNER_ID)
			return
		end
	end

	if ClientInputProfile.usesTouchControls() then
		tooltip:show(MOBILE_SELL_TOOLTIP_TEXT, false, SELL_TOOLTIP_OWNER_ID)
	elseif ClientInputProfile.usesGamepadControls() then
		tooltip:show(GAMEPAD_SELL_TOOLTIP_TEXT, false, SELL_TOOLTIP_OWNER_ID)
	else
		tooltip:show(DESKTOP_SELL_TOOLTIP_TEXT, false, SELL_TOOLTIP_OWNER_ID)
	end
end

local function updateSellSelection()
	local currentSelectionView = selectionView
	if currentSelectionView == nil then
		return
	end

	if not isSellModeEnabled() or UserInputService:GetFocusedTextBox() ~= nil then
		clearSellTarget()
		updateSellTooltip()
		return
	end

	if ClientInputProfile.usesTouchControls() then
		local sellTarget = currentSellTarget
		local blockedSellTarget = currentBlockedSellTarget
		if sellTarget ~= nil and sellTarget.Parent ~= nil then
			currentSelectionView:show(sellTarget)
		elseif blockedSellTarget ~= nil and blockedSellTarget.Parent ~= nil then
			currentSelectionView:hide()
		else
			clearSellTarget()
		end
		updateSellTooltip()
		return
	end

	local sellTarget = PlacedBuildingTargeting.getCurrentTarget(localPlayer)
	if sellTarget == nil then
		clearSellTarget()
		updateSellTooltip()
		return
	end

	if isBlockedSellTarget(sellTarget) then
		setBlockedSellTarget(sellTarget)
		updateSellTooltip()
		return
	end

	currentSellTarget = sellTarget
	currentBlockedSellTarget = nil
	currentSelectionView:show(sellTarget)
	updateSellTooltip()
end

local function renderButton(buttonWidgets: Widgets)
	buttonWidgets.stroke.Color = if isSellModeEnabled() then ACTIVE_STROKE_COLOR else INACTIVE_STROKE_COLOR
end

local function handleModeChanged(_mode: StructureActionMode.StructureActionModeId)
	if not isSellModeEnabled() then
		clearSellTarget()
	end
	updateSellTooltip()

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
	hudTooltip = HudTooltipModule.get()
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
		updateSellTooltip()
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

		if inputObject.KeyCode == SELL_CANCEL_KEYCODE then
			StructureActionMode.clearMode()
			return
		end

		local isConfirmInput = inputObject.UserInputType == Enum.UserInputType.MouseButton1
			or inputObject.KeyCode == SELL_CONFIRM_KEYCODE
		if not isConfirmInput then
			return
		end

		local sellTarget = currentSellTarget
		if sellTarget == nil then
			return
		end

		requestSellRemote:FireServer(sellTarget)
		clearSellTarget()
		updateSellTooltip()
	end))

	table.insert(connections, UserInputService.TouchTap:Connect(function(touchPositions: { Vector2 }, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if not isSellModeEnabled() or not ClientInputProfile.usesTouchControls() then
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
			clearSellTarget()
			updateSellTooltip()
			return
		end

		if isBlockedSellTarget(tappedTarget) then
			setBlockedSellTarget(tappedTarget)
			updateSellTooltip()
			return
		end

		if currentSellTarget == tappedTarget then
			requestSellRemote:FireServer(tappedTarget)
			clearSellTarget()
			updateSellTooltip()
			return
		end

		currentSellTarget = tappedTarget
		currentBlockedSellTarget = nil
		local currentSelectionView = selectionView
		if currentSelectionView ~= nil then
			currentSelectionView:show(tappedTarget)
		end
		updateSellTooltip()
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
	local tooltip = hudTooltip
	if tooltip ~= nil then
		tooltip:hide(SELL_TOOLTIP_OWNER_ID)
	end

	local currentSelectionView = selectionView
	if currentSelectionView ~= nil then
		currentSelectionView:destroy()
	end

	selectionView = nil
	widgets = nil
	hudTooltip = nil
	hasStarted = false
end

return table.freeze(SellController)

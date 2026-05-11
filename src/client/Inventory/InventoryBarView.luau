--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local templatesFolder = ReplicatedStorage:WaitForChild("Templates") :: Folder

local HotbarConfig = require(inventoryFolder:WaitForChild("HotbarConfig") :: ModuleScript)
local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)

type InventoryEntry = InventoryTypes.InventoryEntry
type InventorySnapshot = InventoryTypes.InventorySnapshot
type ItemDefinition = InventoryTypes.ItemDefinition
type ItemId = InventoryTypes.ItemId
type GuiButtonLike = TextButton | ImageButton

type SlotWidgets = {
	slotIndex: number,
	itemId: ItemId?,
	isSelected: boolean,
	button: GuiButtonLike,
	stroke: UIStroke,
	slotNumberLabel: TextLabel,
	itemNameLabel: TextLabel,
	countLabel: TextLabel,
	iconLabel: ImageLabel,
}

type InventoryItemWidgets = {
	itemId: ItemId,
	button: GuiButtonLike,
	stroke: UIStroke,
}

type DragState = {
	itemId: ItemId,
	source: "Inventory" | "Hotbar",
}

export type InventoryBarView = {
	_rootGui: ScreenGui,
	_inventoryMenu: Frame,
	_inventoryWindow: GuiObject,
	_hotbarFrame: Frame,
	_hotbarGrid: UIGridLayout?,
	_openButton: GuiButtonLike,
	_inventoryContentFrame: GuiObject,
	_inventoryGrid: UIGridLayout?,
	_searchBox: TextBox,
	_tooltipLabel: TextLabel?,
	_hotbarSlots: { SlotWidgets },
	_inventoryItems: { InventoryItemWidgets },
	_dragGhostLabel: TextLabel,
	_isInventoryPanelOpen: boolean,
	_currentSnapshot: InventorySnapshot?,
	_dragState: DragState?,
	_activeInventoryItemId: ItemId?,
	_slotActivationSuppressUntil: number,
	_searchText: string,
	_renderedHotbarSlotCount: number,
	_connections: { RBXScriptConnection },
	_slotConnections: { RBXScriptConnection },
	_itemConnections: { RBXScriptConnection },
	_inventoryToggleRequestedCallbacks: { () -> () },
	_slotActivatedCallbacks: { (slotIndex: number) -> () },
	_hotbarAssignCallbacks: { (itemId: ItemId, slotIndex: number) -> () },
	_hotbarUnassignCallbacks: { (itemId: ItemId) -> () },
	getInventoryPanel: (self: InventoryBarView) -> Frame,
	connectInventoryToggleRequested: (self: InventoryBarView, callback: () -> ()) -> (),
	connectSlotActivated: (self: InventoryBarView, callback: (slotIndex: number) -> ()) -> (),
	connectHotbarAssignRequested: (self: InventoryBarView, callback: (itemId: ItemId, slotIndex: number) -> ()) -> (),
	connectHotbarUnassignRequested: (self: InventoryBarView, callback: (itemId: ItemId) -> ()) -> (),
	setInventoryPanelOpen: (self: InventoryBarView, isOpen: boolean) -> (),
	render: (self: InventoryBarView, snapshot: InventorySnapshot?) -> (),
	destroy: (self: InventoryBarView) -> (),
}

local SLOT_BACKGROUND_COLOR = Color3.fromRGB(0, 0, 0)
local DEFAULT_STROKE_COLOR = Color3.fromRGB(0, 0, 0)
local SELECTED_STROKE_COLOR = Color3.fromRGB(255, 255, 255)
local PANEL_COLOR = Color3.fromRGB(0, 0, 0)
local DETAIL_TEXT_COLOR = Color3.fromRGB(219, 205, 180)
local SCYTHE_ICON_IMAGE = "rbxassetid://86007084151897"
local MOBILE_VISIBLE_HOTBAR_SLOTS = 4
local DESKTOP_VISIBLE_HOTBAR_SLOTS = 10
local MOBILE_MIN_HOTBAR_SLOT_SIZE = 52
local MOBILE_MAX_HOTBAR_SLOT_SIZE = 64
local DESKTOP_MIN_HOTBAR_SLOT_SIZE = 68
local DESKTOP_MAX_HOTBAR_SLOT_SIZE = 92
local MOBILE_HOTBAR_BOTTOM_MARGIN = 20
local DESKTOP_HOTBAR_BOTTOM_MARGIN = 28
local MOBILE_HOTBAR_HORIZONTAL_FRACTION = 0.9
local DESKTOP_HOTBAR_HORIZONTAL_FRACTION = 0.82
local MOBILE_MIN_INVENTORY_GRID_CELL_SIZE = 32
local MOBILE_INVENTORY_GRID_CELL_SIZE = 45
local DESKTOP_INVENTORY_GRID_CELL_SIZE = 83
local MOBILE_INVENTORY_GRID_PADDING = 12
local DESKTOP_INVENTORY_GRID_PADDING = 12
local MOBILE_TOOLTIP_TEXT = "Tap an item, then tap a hotbar slot"
local MOBILE_ACTIVE_TOOLTIP_TEXT = "Tap a hotbar slot to assign"
local DESKTOP_TOOLTIP_TEXT = "Click and drag to assign"

local toolButtonTemplateInstance = templatesFolder:WaitForChild("ToolButton")
assert(
	toolButtonTemplateInstance:IsA("TextButton") or toolButtonTemplateInstance:IsA("ImageButton"),
	"ReplicatedStorage.Templates.ToolButton must be a TextButton or ImageButton"
)
local toolButtonTemplate = toolButtonTemplateInstance :: GuiButtonLike

local InventoryBarView = {}
InventoryBarView.__index = InventoryBarView

local function sortEntries(entries: { InventoryEntry }): { InventoryEntry }
	local sortedEntries = table.clone(entries)
	table.sort(sortedEntries, function(leftEntry, rightEntry)
		local leftDefinition = ItemCatalog.getItemDefinition(leftEntry.itemId)
		local rightDefinition = ItemCatalog.getItemDefinition(rightEntry.itemId)
		if leftDefinition.inventoryOrder ~= rightDefinition.inventoryOrder then
			return leftDefinition.inventoryOrder < rightDefinition.inventoryOrder
		end

		return leftDefinition.displayName < rightDefinition.displayName
	end)
	return sortedEntries
end

local function getDisplayLabelForSlot(slotIndex: number): string
	if slotIndex == HotbarConfig.lockedSlotIndex then
		return ""
	end

	return tostring(slotIndex - 1)
end

local function isMobileHotbarLayout(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.GamepadEnabled
end

local function getHotbarVisibleCapacity(): number
	return if isMobileHotbarLayout() then MOBILE_VISIBLE_HOTBAR_SLOTS else DESKTOP_VISIBLE_HOTBAR_SLOTS
end

local function isMousePrimaryInput(inputObject: InputObject): boolean
	return inputObject.UserInputType == Enum.UserInputType.MouseButton1
end

local function isPrimaryPointerReleaseInput(inputObject: InputObject): boolean
	return inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.Touch
end

local function isPointerMovementInput(inputObject: InputObject): boolean
	return inputObject.UserInputType == Enum.UserInputType.MouseMovement or inputObject.UserInputType == Enum.UserInputType.Touch
end

local function findRequiredChild(parent: Instance, childName: string, className: string): Instance
	local child = parent:FindFirstChild(childName)
	assert(child ~= nil, string.format("%s must contain a child named %s", parent:GetFullName(), childName))
	assert(child:IsA(className), string.format("%s.%s must be a %s", parent:GetFullName(), childName, className))
	return child
end

local function ensureStroke(button: GuiButtonLike): UIStroke
	for _, child in ipairs(button:GetChildren()) do
		if child:IsA("UIStroke") then
			return child
		end
	end

	local stroke = Instance.new("UIStroke")
	stroke.Color = DEFAULT_STROKE_COLOR
	stroke.Transparency = 0.15
	stroke.Parent = button
	return stroke
end

local function cloneToolButton(parent: Instance, name: string, layoutOrder: number): GuiButtonLike
	local button = toolButtonTemplate:Clone()
	button.Name = name
	button.LayoutOrder = layoutOrder
	button.Size = UDim2.fromScale(1, 1)
	button.Parent = parent
	return button
end

local function clearButtonsWithPrefix(parent: Instance, prefix: string)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("GuiObject") and string.sub(child.Name, 1, string.len(prefix)) == prefix then
			child:Destroy()
		end
	end
end

local function createSlot(slotIndex: number, itemId: ItemId?, entry: InventoryEntry?, isSelected: boolean, parent: Instance): SlotWidgets
	local button = cloneToolButton(parent, string.format("Slot%d", slotIndex), slotIndex)
	button.AutoButtonColor = false
	button.BackgroundColor3 = SLOT_BACKGROUND_COLOR
	button.BackgroundTransparency = 0.5
	if button:IsA("TextButton") then
		button.Text = ""
	end

	local stroke = ensureStroke(button)
	stroke.Color = if isSelected then SELECTED_STROKE_COLOR else DEFAULT_STROKE_COLOR
	stroke.Transparency = 0.15

	local slotNumberLabel = findRequiredChild(button, "toolNumber", "TextLabel") :: TextLabel
	local itemNameLabel = findRequiredChild(button, "toolName", "TextLabel") :: TextLabel
	local countLabel = findRequiredChild(button, "toolAmount", "TextLabel") :: TextLabel
	local iconLabel = findRequiredChild(button, "toolIcon", "ImageLabel") :: ImageLabel

	slotNumberLabel.Text = getDisplayLabelForSlot(slotIndex)
	iconLabel.Image = ""
	iconLabel.Visible = false

	if itemId ~= nil and entry ~= nil then
		local itemDefinition = ItemCatalog.getItemDefinition(itemId)
		itemNameLabel.Text = itemDefinition.displayName
		itemNameLabel.TextWrapped = true
		if slotIndex == HotbarConfig.lockedSlotIndex and itemId == "Scythe" then
			countLabel.Text = ""
			iconLabel.Image = SCYTHE_ICON_IMAGE
			iconLabel.Visible = true
		else
			countLabel.Text = string.format("x%d", entry.quantity)
		end
	else
		itemNameLabel.Text = ""
		countLabel.Text = ""
	end

	return {
		slotIndex = slotIndex,
		itemId = itemId,
		isSelected = isSelected,
		button = button,
		stroke = stroke,
		slotNumberLabel = slotNumberLabel,
		itemNameLabel = itemNameLabel,
		countLabel = countLabel,
		iconLabel = iconLabel,
	}
end

local function createInventoryItemButton(itemDefinition: ItemDefinition, entry: InventoryEntry, parent: Instance, layoutOrder: number): GuiButtonLike
	local button = cloneToolButton(parent, string.format("Item_%s", entry.itemId), layoutOrder)
	button.AutoButtonColor = false
	button.BackgroundColor3 = PANEL_COLOR
	button.BackgroundTransparency = 0.5
	if button:IsA("TextButton") then
		button.Text = ""
	end

	local stroke = ensureStroke(button)
	stroke.Color = DEFAULT_STROKE_COLOR
	stroke.Transparency = 0.55

	local titleLabel = findRequiredChild(button, "toolName", "TextLabel") :: TextLabel
	local detailLabel = findRequiredChild(button, "toolAmount", "TextLabel") :: TextLabel
	local slotNumberLabel = findRequiredChild(button, "toolNumber", "TextLabel") :: TextLabel
	local iconLabel = findRequiredChild(button, "toolIcon", "ImageLabel") :: ImageLabel

	titleLabel.Text = itemDefinition.displayName
	titleLabel.TextWrapped = true
	detailLabel.Text = string.format("x%d", entry.quantity)
	detailLabel.TextColor3 = DETAIL_TEXT_COLOR
	detailLabel.TextXAlignment = Enum.TextXAlignment.Left
	slotNumberLabel.Text = ""
	iconLabel.Image = ""
	iconLabel.Visible = false

	return button
end

local function getAssignableSlotIndexAtPosition(playerGui: PlayerGui, slots: { SlotWidgets }, x: number, y: number): number?
	local guiObjects = playerGui:GetGuiObjectsAtPosition(x, y)
	for _, guiObject in ipairs(guiObjects) do
		for _, slot in ipairs(slots) do
			if not HotbarConfig.isAssignableSlotIndex(slot.slotIndex) then
				continue
			end

			local current: Instance? = guiObject
			while current ~= nil do
				if current == slot.button then
					return slot.slotIndex
				end
				current = current.Parent
			end
		end
	end

	return nil
end

local function isDroppedOnInventoryWindow(playerGui: PlayerGui, inventoryWindow: GuiObject, x: number, y: number): boolean
	local guiObjects = playerGui:GetGuiObjectsAtPosition(x, y)
	for _, guiObject in ipairs(guiObjects) do
		local current: Instance? = guiObject
		while current ~= nil do
			if current == inventoryWindow then
				return true
			end
			current = current.Parent
		end
	end

	return false
end

local updateInventorySelectionFeedback: (InventoryBarView) -> ()

local function beginDragState(self: InventoryBarView, itemId: ItemId, source: "Inventory" | "Hotbar", screenPosition: Vector2)
	local itemDefinition = ItemCatalog.getItemDefinition(itemId)
	self._dragState = {
		itemId = itemId,
		source = source,
	}
	self._dragGhostLabel.Text = itemDefinition.displayName
	self._dragGhostLabel.Position = UDim2.fromOffset(screenPosition.X, screenPosition.Y)
	self._dragGhostLabel.Visible = true
	updateInventorySelectionFeedback(self)
end

local function clearDragState(self: InventoryBarView)
	self._dragState = nil
	self._dragGhostLabel.Visible = false
	updateInventorySelectionFeedback(self)
end

local function fireHotbarAssignRequested(self: InventoryBarView, itemId: ItemId, slotIndex: number)
	for _, callback in ipairs(self._hotbarAssignCallbacks) do
		callback(itemId, slotIndex)
	end
end

local function fireHotbarUnassignRequested(self: InventoryBarView, itemId: ItemId)
	for _, callback in ipairs(self._hotbarUnassignCallbacks) do
		callback(itemId)
	end
end

local function updateTooltipText(tooltipLabel: TextLabel?, activeInventoryItemId: ItemId?)
	if tooltipLabel == nil then
		return
	end

	if isMobileHotbarLayout() then
		tooltipLabel.Text = if activeInventoryItemId ~= nil then MOBILE_ACTIVE_TOOLTIP_TEXT else MOBILE_TOOLTIP_TEXT
	else
		tooltipLabel.Text = DESKTOP_TOOLTIP_TEXT
	end
end

updateInventorySelectionFeedback = function(self: InventoryBarView)
	local dragState = self._dragState
	for _, slot in ipairs(self._hotbarSlots) do
		local isHeldSlot = dragState ~= nil and dragState.source == "Hotbar" and slot.itemId == dragState.itemId
		slot.stroke.Color = if isHeldSlot or slot.isSelected then SELECTED_STROKE_COLOR else DEFAULT_STROKE_COLOR
		slot.stroke.Transparency = if isHeldSlot then 0 else 0.15
	end

	for _, item in ipairs(self._inventoryItems) do
		local isDraggedItem = dragState ~= nil and dragState.source == "Inventory" and item.itemId == dragState.itemId
		local isActiveItem = self._activeInventoryItemId == item.itemId
		item.stroke.Color = if isDraggedItem or isActiveItem then SELECTED_STROKE_COLOR else DEFAULT_STROKE_COLOR
		item.stroke.Transparency = if isDraggedItem or isActiveItem then 0 else 0.55
	end

	updateTooltipText(self._tooltipLabel, self._activeInventoryItemId)
end

local function setActiveInventoryItem(self: InventoryBarView, itemId: ItemId?)
	self._activeInventoryItemId = itemId
	updateInventorySelectionFeedback(self)
end

local function getViewportSize(rootGui: ScreenGui, fallbackGui: GuiObject): Vector2
	local currentCamera = Workspace.CurrentCamera
	if currentCamera ~= nil then
		local viewportSize = currentCamera.ViewportSize
		if viewportSize.X > 0 and viewportSize.Y > 0 then
			return viewportSize
		end
	end

	local absoluteSize = rootGui.AbsoluteSize
	if absoluteSize.X > 0 and absoluteSize.Y > 0 then
		return absoluteSize
	end

	return fallbackGui.AbsoluteSize
end

local function updateHotbarLayout(rootGui: ScreenGui, hotbarFrame: Frame, hotbarGrid: UIGridLayout?, renderedSlotCount: number)
	if hotbarGrid == nil then
		return
	end

	local visibleCapacity = getHotbarVisibleCapacity()
	local isMobile = isMobileHotbarLayout()
	local viewportSize = getViewportSize(rootGui, hotbarFrame)
	local padding = if isMobile then 6 else 10
	local targetVisibleSlots = math.max(math.min(renderedSlotCount, visibleCapacity), 1)
	local horizontalFraction = if isMobile then MOBILE_HOTBAR_HORIZONTAL_FRACTION else DESKTOP_HOTBAR_HORIZONTAL_FRACTION
	local widthLimitedSlotSize = math.floor(
		(viewportSize.X * horizontalFraction - padding * math.max(visibleCapacity - 1, 0)) / visibleCapacity
	)
	local heightLimitedSlotSize = math.floor(viewportSize.Y * (if isMobile then 0.09 else 0.1))
	local minSlotSize = if isMobile then MOBILE_MIN_HOTBAR_SLOT_SIZE else DESKTOP_MIN_HOTBAR_SLOT_SIZE
	local maxSlotSize = if isMobile then MOBILE_MAX_HOTBAR_SLOT_SIZE else DESKTOP_MAX_HOTBAR_SLOT_SIZE
	local slotSize = math.clamp(math.min(widthLimitedSlotSize, heightLimitedSlotSize), minSlotSize, maxSlotSize)
	local frameWidth = slotSize * targetVisibleSlots + padding * math.max(targetVisibleSlots - 1, 0)
	local bottomMargin = if isMobile then MOBILE_HOTBAR_BOTTOM_MARGIN else DESKTOP_HOTBAR_BOTTOM_MARGIN

	hotbarGrid.CellPadding = UDim2.fromOffset(padding, padding)
	hotbarGrid.CellSize = UDim2.fromOffset(slotSize, slotSize)
	hotbarFrame.AnchorPoint = Vector2.new(0.5, 1)
	hotbarFrame.Position = UDim2.new(0.5, 0, 1, -bottomMargin)
	hotbarFrame.Size = UDim2.fromOffset(frameWidth, slotSize)
end

local function updateInventoryGridLayout(rootGui: ScreenGui, inventoryContentFrame: GuiObject, inventoryGrid: UIGridLayout?)
	if inventoryGrid == nil then
		return
	end

	local isMobile = isMobileHotbarLayout()
	local viewportSize = getViewportSize(rootGui, inventoryContentFrame)
	local targetCellSize = if isMobile then MOBILE_INVENTORY_GRID_CELL_SIZE else DESKTOP_INVENTORY_GRID_CELL_SIZE
	local cellSize = if isMobile
		then math.clamp(math.floor(viewportSize.X * 0.12), MOBILE_MIN_INVENTORY_GRID_CELL_SIZE, targetCellSize)
		else targetCellSize
	local padding = if isMobile then MOBILE_INVENTORY_GRID_PADDING else DESKTOP_INVENTORY_GRID_PADDING

	inventoryGrid.CellPadding = UDim2.fromOffset(padding, padding)
	inventoryGrid.CellSize = UDim2.fromOffset(cellSize, cellSize)
end

local function getRootGui(playerGui: PlayerGui): ScreenGui
	local rootGui = playerGui:WaitForChild("GUI")
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")
	return rootGui
end

function InventoryBarView.new(): InventoryBarView
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before creating the inventory UI")
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = getRootGui(playerGui)

	local hud = rootGui:WaitForChild("HUD")
	assert(hud:IsA("Frame"), "GUI.HUD must be a Frame")

	local topLeft = hud:WaitForChild("TopLeft")
	assert(topLeft:IsA("Frame"), "GUI.HUD.TopLeft must be a Frame")
	local openButtonInstance = topLeft:WaitForChild("Inventory")
	assert(
		openButtonInstance:IsA("TextButton") or openButtonInstance:IsA("ImageButton"),
		"GUI.HUD.TopLeft.Inventory must be a TextButton or ImageButton"
	)
	local openButton = openButtonInstance :: GuiButtonLike

	local inventoryHud = hud:WaitForChild("Inventory")
	assert(inventoryHud:IsA("Frame"), "GUI.HUD.Inventory must be a Frame")
	local hotbarFrame = inventoryHud:WaitForChild("hotBar")
	assert(hotbarFrame:IsA("Frame"), "GUI.HUD.Inventory.hotBar must be a Frame")
	local hotbarGridInstance = hotbarFrame:FindFirstChild("Grid")
	local hotbarGrid: UIGridLayout? = nil
	if hotbarGridInstance ~= nil then
		assert(hotbarGridInstance:IsA("UIGridLayout"), "GUI.HUD.Inventory.hotBar.Grid must be a UIGridLayout")
		hotbarGrid = hotbarGridInstance
		hotbarGrid.SortOrder = Enum.SortOrder.LayoutOrder
	end

	local frames = rootGui:WaitForChild("Frames")
	assert(frames:IsA("Frame"), "GUI.Frames must be a Frame")
	local inventoryMenu = frames:WaitForChild("InventoryMenu")
	assert(inventoryMenu:IsA("Frame"), "GUI.Frames.InventoryMenu must be a Frame")
	local window = inventoryMenu:WaitForChild("Window")
	assert(window:IsA("GuiObject"), "GUI.Frames.InventoryMenu.Window must be a GuiObject")
	local inventoryContentFrame = window:WaitForChild("Frame")
	assert(inventoryContentFrame:IsA("GuiObject"), "GUI.Frames.InventoryMenu.Window.Frame must be a GuiObject")
	local inventoryGridInstance = inventoryContentFrame:FindFirstChild("Grid")
	local inventoryGrid: UIGridLayout? = nil
	if inventoryGridInstance ~= nil then
		assert(inventoryGridInstance:IsA("UIGridLayout"), "GUI.Frames.InventoryMenu.Window.Frame.Grid must be a UIGridLayout")
		inventoryGrid = inventoryGridInstance
		inventoryGrid.SortOrder = Enum.SortOrder.LayoutOrder
	end

	local searchBox = window:WaitForChild("SearchBox")
	assert(searchBox:IsA("TextBox"), "GUI.Frames.InventoryMenu.Window.SearchBox must be a TextBox")
	local tooltipInstance = inventoryMenu:FindFirstChild("Tooltip")
	local tooltipLabel: TextLabel? = nil
	if tooltipInstance ~= nil then
		assert(tooltipInstance:IsA("TextLabel"), "GUI.Frames.InventoryMenu.Tooltip must be a TextLabel")
		tooltipLabel = tooltipInstance
	end

	clearButtonsWithPrefix(hotbarFrame, "Slot")
	clearButtonsWithPrefix(inventoryContentFrame, "Item")

	local dragGhostLabel = Instance.new("TextLabel")
	dragGhostLabel.Name = "InventoryDragGhost"
	dragGhostLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	dragGhostLabel.BackgroundColor3 = Color3.fromRGB(63, 56, 45)
	dragGhostLabel.BackgroundTransparency = 0.15
	dragGhostLabel.BorderSizePixel = 0
	dragGhostLabel.Size = UDim2.fromOffset(140, 34)
	dragGhostLabel.Text = ""
	dragGhostLabel.TextColor3 = Color3.fromRGB(244, 234, 213)
	dragGhostLabel.TextSize = 13
	dragGhostLabel.Font = Enum.Font.GothamBold
	dragGhostLabel.Visible = false
	dragGhostLabel.ZIndex = 100
	dragGhostLabel.Parent = rootGui

	local dragCorner = Instance.new("UICorner")
	dragCorner.CornerRadius = UDim.new(0, 10)
	dragCorner.Parent = dragGhostLabel

	local self = setmetatable({
		_rootGui = rootGui,
		_inventoryMenu = inventoryMenu,
		_inventoryWindow = window,
		_hotbarFrame = hotbarFrame,
		_hotbarGrid = hotbarGrid,
		_openButton = openButton,
		_inventoryContentFrame = inventoryContentFrame,
		_inventoryGrid = inventoryGrid,
		_searchBox = searchBox,
		_tooltipLabel = tooltipLabel,
		_hotbarSlots = {},
		_inventoryItems = {},
		_dragGhostLabel = dragGhostLabel,
		_isInventoryPanelOpen = false,
		_currentSnapshot = nil,
		_dragState = nil,
		_activeInventoryItemId = nil,
		_slotActivationSuppressUntil = 0,
		_searchText = searchBox.Text,
		_renderedHotbarSlotCount = 1,
		_connections = {},
		_slotConnections = {},
		_itemConnections = {},
		_inventoryToggleRequestedCallbacks = {},
		_slotActivatedCallbacks = {},
		_hotbarAssignCallbacks = {},
		_hotbarUnassignCallbacks = {},
	}, InventoryBarView) :: InventoryBarView

	table.insert(self._connections, openButton.Activated:Connect(function()
		for _, callback in ipairs(self._inventoryToggleRequestedCallbacks) do
			callback()
		end
	end))

	table.insert(self._connections, searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		self._searchText = searchBox.Text
		self:render(self._currentSnapshot)
	end))

	table.insert(self._connections, UserInputService.InputChanged:Connect(function(inputObject: InputObject)
		if not isPointerMovementInput(inputObject) then
			return
		end

		if self._dragState == nil then
			return
		end

		self._dragGhostLabel.Position = UDim2.fromOffset(inputObject.Position.X, inputObject.Position.Y)
	end))

	local currentCamera = Workspace.CurrentCamera
	if currentCamera ~= nil then
		table.insert(self._connections, currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			updateHotbarLayout(self._rootGui, self._hotbarFrame, self._hotbarGrid, self._renderedHotbarSlotCount)
			updateInventoryGridLayout(self._rootGui, self._inventoryContentFrame, self._inventoryGrid)
			updateTooltipText(self._tooltipLabel, self._activeInventoryItemId)
		end))
	end

	table.insert(self._connections, UserInputService.InputEnded:Connect(function(inputObject: InputObject)
		if not isPrimaryPointerReleaseInput(inputObject) then
			return
		end

		local dragState = self._dragState
		if dragState == nil then
			return
		end

		clearDragState(self)

		local slotIndex = getAssignableSlotIndexAtPosition(playerGui, self._hotbarSlots, inputObject.Position.X, inputObject.Position.Y)
		if dragState.source == "Inventory" then
			if slotIndex == nil then
				return
			end

			if inputObject.UserInputType == Enum.UserInputType.Touch then
				self._slotActivationSuppressUntil = os.clock() + 0.25
			end
			fireHotbarAssignRequested(self, dragState.itemId, slotIndex)
			return
		end

		if slotIndex ~= nil then
			if inputObject.UserInputType == Enum.UserInputType.Touch then
				self._slotActivationSuppressUntil = os.clock() + 0.25
			end
			fireHotbarAssignRequested(self, dragState.itemId, slotIndex)
			return
		end

		if isDroppedOnInventoryWindow(playerGui, self._inventoryWindow, inputObject.Position.X, inputObject.Position.Y) then
			fireHotbarUnassignRequested(self, dragState.itemId)
		end
	end))

	updateHotbarLayout(rootGui, hotbarFrame, hotbarGrid, 1)
	updateInventoryGridLayout(rootGui, inventoryContentFrame, inventoryGrid)
	updateTooltipText(tooltipLabel, nil)

	return self
end

function InventoryBarView:getInventoryPanel(): Frame
	return self._inventoryMenu
end

function InventoryBarView:connectInventoryToggleRequested(callback: () -> ())
	table.insert(self._inventoryToggleRequestedCallbacks, callback)
end

function InventoryBarView:connectSlotActivated(callback: (slotIndex: number) -> ())
	table.insert(self._slotActivatedCallbacks, callback)
end

function InventoryBarView:connectHotbarAssignRequested(callback: (itemId: ItemId, slotIndex: number) -> ())
	table.insert(self._hotbarAssignCallbacks, callback)
end

function InventoryBarView:connectHotbarUnassignRequested(callback: (itemId: ItemId) -> ())
	table.insert(self._hotbarUnassignCallbacks, callback)
end

function InventoryBarView:setInventoryPanelOpen(isOpen: boolean)
	self._isInventoryPanelOpen = isOpen

	if not isOpen then
		clearDragState(self)
		setActiveInventoryItem(self, nil)
		self._slotActivationSuppressUntil = 0
	end

	self:render(self._currentSnapshot)
end

function InventoryBarView:render(snapshot: InventorySnapshot?)
	self._currentSnapshot = snapshot

	for _, connection in ipairs(self._slotConnections) do
		connection:Disconnect()
	end
	table.clear(self._slotConnections)
	for _, slot in ipairs(self._hotbarSlots) do
		slot.button:Destroy()
	end
	self._hotbarSlots = {}

	for _, connection in ipairs(self._itemConnections) do
		connection:Disconnect()
	end
	table.clear(self._itemConnections)
	for _, item in ipairs(self._inventoryItems) do
		item.button:Destroy()
	end
	self._inventoryItems = {}
	updateInventoryGridLayout(self._rootGui, self._inventoryContentFrame, self._inventoryGrid)

	if snapshot == nil then
		self._renderedHotbarSlotCount = 1
		updateHotbarLayout(self._rootGui, self._hotbarFrame, self._hotbarGrid, self._renderedHotbarSlotCount)
		return
	end

	local entriesByItemId: { [ItemId]: InventoryEntry } = {}
	for _, entry in ipairs(snapshot.entries) do
		entriesByItemId[entry.itemId] = entry
	end

	local assignedItemIds: { [ItemId]: boolean } = {}
	local visibleHotbarSlotIndices = { HotbarConfig.lockedSlotIndex }
	local nextEmptyAssignableSlotIndex: number? = nil

	for slotIndex = HotbarConfig.firstAssignableSlotIndex, HotbarConfig.lastSlotIndex do
		local itemId = snapshot.hotbarSlots[slotIndex]
		if itemId ~= nil then
			table.insert(visibleHotbarSlotIndices, slotIndex)
		elseif nextEmptyAssignableSlotIndex == nil then
			nextEmptyAssignableSlotIndex = slotIndex
		end
	end

	if self._isInventoryPanelOpen and nextEmptyAssignableSlotIndex ~= nil then
		table.insert(visibleHotbarSlotIndices, nextEmptyAssignableSlotIndex)
	end

	local visibleCapacity = getHotbarVisibleCapacity()
	while #visibleHotbarSlotIndices > visibleCapacity do
		table.remove(visibleHotbarSlotIndices)
	end

	for _, slotIndex in ipairs(visibleHotbarSlotIndices) do
		local visibleItemId = snapshot.hotbarSlots[slotIndex]
		if visibleItemId ~= nil then
			assignedItemIds[visibleItemId] = true
		end
	end

	self._renderedHotbarSlotCount = #visibleHotbarSlotIndices
	updateHotbarLayout(self._rootGui, self._hotbarFrame, self._hotbarGrid, self._renderedHotbarSlotCount)

	for _, slotIndex in ipairs(visibleHotbarSlotIndices) do
		local itemId = snapshot.hotbarSlots[slotIndex]
		local entry = if itemId ~= nil then entriesByItemId[itemId] else nil
		local isSelected = snapshot.selectedSlotIndex == slotIndex
		local slotWidgets = createSlot(slotIndex, itemId, entry, isSelected, self._hotbarFrame)
		table.insert(self._hotbarSlots, slotWidgets)

		if HotbarConfig.isAssignableSlotIndex(slotIndex) then
			table.insert(self._slotConnections, slotWidgets.button.Activated:Connect(function()
				if os.clock() <= self._slotActivationSuppressUntil then
					self._slotActivationSuppressUntil = 0
					return
				end

				if self._isInventoryPanelOpen and isMobileHotbarLayout() then
					local activeInventoryItemId = self._activeInventoryItemId
					if activeInventoryItemId == nil then
						return
					end

					setActiveInventoryItem(self, nil)
					fireHotbarAssignRequested(self, activeInventoryItemId, slotIndex)
					return
				end

				local dragState = self._dragState
				if self._isInventoryPanelOpen and dragState ~= nil then
					clearDragState(self)
					fireHotbarAssignRequested(self, dragState.itemId, slotIndex)
					return
				end

				if itemId ~= nil then
					for _, callback in ipairs(self._slotActivatedCallbacks) do
						callback(slotIndex)
					end
				end
			end))
		elseif itemId ~= nil then
			table.insert(self._slotConnections, slotWidgets.button.Activated:Connect(function()
				for _, callback in ipairs(self._slotActivatedCallbacks) do
					callback(slotIndex)
				end
			end))
		end

		if itemId ~= nil then
			if self._isInventoryPanelOpen and HotbarConfig.isAssignableSlotIndex(slotIndex) then
				table.insert(self._slotConnections, slotWidgets.button.InputBegan:Connect(function(inputObject: InputObject)
					if not isMousePrimaryInput(inputObject) then
						return
					end

					beginDragState(self, itemId, "Hotbar", Vector2.new(inputObject.Position.X, inputObject.Position.Y))
				end))
			end
		end
	end

	local searchText = string.lower(self._searchText)
	for layoutOrder, entry in ipairs(sortEntries(snapshot.entries)) do
		if assignedItemIds[entry.itemId] == true then
			continue
		end

		local itemDefinition = ItemCatalog.getItemDefinition(entry.itemId)
		if searchText ~= "" and string.find(string.lower(itemDefinition.displayName), searchText, 1, true) == nil then
			continue
		end

		local itemButton = createInventoryItemButton(itemDefinition, entry, self._inventoryContentFrame, layoutOrder)
		table.insert(self._inventoryItems, {
			itemId = entry.itemId,
			button = itemButton,
			stroke = ensureStroke(itemButton),
		})

		if entry.itemId ~= "Scythe" then
			table.insert(self._itemConnections, itemButton.Activated:Connect(function()
				if not self._isInventoryPanelOpen or not isMobileHotbarLayout() then
					return
				end

				local activeInventoryItemId = if self._activeInventoryItemId == entry.itemId then nil else entry.itemId
				setActiveInventoryItem(self, activeInventoryItemId)
			end))

			table.insert(self._itemConnections, itemButton.InputBegan:Connect(function(inputObject: InputObject)
				if not self._isInventoryPanelOpen or not isMousePrimaryInput(inputObject) then
					return
				end

				beginDragState(self, entry.itemId, "Inventory", Vector2.new(inputObject.Position.X, inputObject.Position.Y))
			end))
		end
	end

	updateInventorySelectionFeedback(self)
end

function InventoryBarView:destroy()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	for _, connection in ipairs(self._slotConnections) do
		connection:Disconnect()
	end
	for _, connection in ipairs(self._itemConnections) do
		connection:Disconnect()
	end
	for _, slot in ipairs(self._hotbarSlots) do
		slot.button:Destroy()
	end
	for _, item in ipairs(self._inventoryItems) do
		item.button:Destroy()
	end
	self._dragGhostLabel:Destroy()
end

return InventoryBarView

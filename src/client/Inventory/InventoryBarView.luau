--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

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
	_openButton: GuiButtonLike,
	_inventoryContentFrame: GuiObject,
	_searchBox: TextBox,
	_hotbarSlots: { SlotWidgets },
	_inventoryItems: { InventoryItemWidgets },
	_dragGhostLabel: TextLabel,
	_isInventoryPanelOpen: boolean,
	_currentSnapshot: InventorySnapshot?,
	_dragState: DragState?,
	_searchText: string,
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

local EMPTY_SLOT_COLOR = Color3.fromRGB(47, 47, 47)
local FILLED_SLOT_COLOR = Color3.fromRGB(122, 92, 53)
local SELECTED_SLOT_COLOR = Color3.fromRGB(163, 131, 78)
local DEFAULT_STROKE_COLOR = Color3.fromRGB(220, 199, 158)
local SELECTED_STROKE_COLOR = Color3.fromRGB(255, 240, 201)
local PANEL_COLOR = Color3.fromRGB(26, 23, 18)
local DETAIL_TEXT_COLOR = Color3.fromRGB(219, 205, 180)

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

local function getInventoryToggleButtonText(isOpen: boolean): string
	return if isOpen then "Close Inventory" else "Open Inventory"
end

local function getOpenButtonInfoLabel(button: GuiButtonLike): TextLabel?
	local infoInstance = button:FindFirstChild("info")
	if infoInstance ~= nil and infoInstance:IsA("TextLabel") then
		return infoInstance
	end

	return nil
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
	stroke.Thickness = 1
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
	button.BackgroundColor3 = if itemId == nil then EMPTY_SLOT_COLOR else (if isSelected then SELECTED_SLOT_COLOR else FILLED_SLOT_COLOR)
	if button:IsA("TextButton") then
		button.Text = ""
	end

	local stroke = ensureStroke(button)
	stroke.Color = if isSelected then SELECTED_STROKE_COLOR else DEFAULT_STROKE_COLOR
	stroke.Thickness = if isSelected then 2 else 1
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
		countLabel.Text = string.format("x%d", entry.quantity)
	else
		itemNameLabel.Text = ""
		countLabel.Text = ""
	end

	return {
		slotIndex = slotIndex,
		itemId = itemId,
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
	if button:IsA("TextButton") then
		button.Text = ""
	end

	local stroke = ensureStroke(button)
	stroke.Color = DEFAULT_STROKE_COLOR
	stroke.Thickness = 1
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
	local inventoryHud = hud:WaitForChild("Inventory")
	assert(inventoryHud:IsA("Frame"), "GUI.HUD.Inventory must be a Frame")
	local hotbarFrame = inventoryHud:WaitForChild("hotBar")
	assert(hotbarFrame:IsA("Frame"), "GUI.HUD.Inventory.hotBar must be a Frame")
	local hotbarGrid = hotbarFrame:FindFirstChild("Grid")
	if hotbarGrid ~= nil and hotbarGrid:IsA("UIGridStyleLayout") then
		hotbarGrid.SortOrder = Enum.SortOrder.LayoutOrder
	end

	local openButtonInstance = inventoryHud:WaitForChild("openButton")
	assert(
		openButtonInstance:IsA("TextButton") or openButtonInstance:IsA("ImageButton"),
		"GUI.HUD.Inventory.openButton must be a TextButton or ImageButton"
	)
	local openButton = openButtonInstance :: GuiButtonLike

	local frames = rootGui:WaitForChild("Frames")
	assert(frames:IsA("Frame"), "GUI.Frames must be a Frame")
	local inventoryMenu = frames:WaitForChild("InventoryMenu")
	assert(inventoryMenu:IsA("Frame"), "GUI.Frames.InventoryMenu must be a Frame")
	local window = inventoryMenu:WaitForChild("Window")
	assert(window:IsA("GuiObject"), "GUI.Frames.InventoryMenu.Window must be a GuiObject")
	local inventoryContentFrame = window:WaitForChild("Frame")
	assert(inventoryContentFrame:IsA("GuiObject"), "GUI.Frames.InventoryMenu.Window.Frame must be a GuiObject")
	local inventoryGrid = inventoryContentFrame:FindFirstChild("Grid")
	if inventoryGrid ~= nil and inventoryGrid:IsA("UIGridStyleLayout") then
		inventoryGrid.SortOrder = Enum.SortOrder.LayoutOrder
	end

	local searchBox = window:WaitForChild("SearchBox")
	assert(searchBox:IsA("TextBox"), "GUI.Frames.InventoryMenu.Window.SearchBox must be a TextBox")

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
		_openButton = openButton,
		_inventoryContentFrame = inventoryContentFrame,
		_searchBox = searchBox,
		_hotbarSlots = {},
		_inventoryItems = {},
		_dragGhostLabel = dragGhostLabel,
		_isInventoryPanelOpen = false,
		_currentSnapshot = nil,
		_dragState = nil,
		_searchText = searchBox.Text,
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
		if inputObject.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end

		if self._dragState == nil then
			return
		end

		self._dragGhostLabel.Position = UDim2.fromOffset(inputObject.Position.X, inputObject.Position.Y)
	end))

	table.insert(self._connections, UserInputService.InputEnded:Connect(function(inputObject: InputObject)
		if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		local dragState = self._dragState
		if dragState == nil then
			return
		end

		self._dragState = nil
		self._dragGhostLabel.Visible = false

		local slotIndex = getAssignableSlotIndexAtPosition(playerGui, self._hotbarSlots, inputObject.Position.X, inputObject.Position.Y)
		if dragState.source == "Inventory" then
			if slotIndex == nil then
				return
			end

			for _, callback in ipairs(self._hotbarAssignCallbacks) do
				callback(dragState.itemId, slotIndex)
			end
			return
		end

		if slotIndex ~= nil then
			for _, callback in ipairs(self._hotbarAssignCallbacks) do
				callback(dragState.itemId, slotIndex)
			end
			return
		end

		if isDroppedOnInventoryWindow(playerGui, self._inventoryWindow, inputObject.Position.X, inputObject.Position.Y) then
			for _, callback in ipairs(self._hotbarUnassignCallbacks) do
				callback(dragState.itemId)
			end
		end
	end))

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

	if self._openButton:IsA("TextButton") then
		self._openButton.Text = getInventoryToggleButtonText(isOpen)
	end

	local infoLabel = getOpenButtonInfoLabel(self._openButton)
	if infoLabel ~= nil then
		infoLabel.Text = getInventoryToggleButtonText(isOpen)
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

	if snapshot == nil then
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
			assignedItemIds[itemId] = true
			table.insert(visibleHotbarSlotIndices, slotIndex)
		elseif nextEmptyAssignableSlotIndex == nil then
			nextEmptyAssignableSlotIndex = slotIndex
		end
	end

	if self._isInventoryPanelOpen and nextEmptyAssignableSlotIndex ~= nil then
		table.insert(visibleHotbarSlotIndices, nextEmptyAssignableSlotIndex)
	end

	for _, slotIndex in ipairs(visibleHotbarSlotIndices) do
		local itemId = snapshot.hotbarSlots[slotIndex]
		local entry = if itemId ~= nil then entriesByItemId[itemId] else nil
		local isSelected = snapshot.selectedSlotIndex == slotIndex
		local slotWidgets = createSlot(slotIndex, itemId, entry, isSelected, self._hotbarFrame)
		table.insert(self._hotbarSlots, slotWidgets)

		if itemId ~= nil then
			table.insert(self._slotConnections, slotWidgets.button.Activated:Connect(function()
				for _, callback in ipairs(self._slotActivatedCallbacks) do
					callback(slotIndex)
				end
			end))

			if self._isInventoryPanelOpen and HotbarConfig.isAssignableSlotIndex(slotIndex) then
				table.insert(self._slotConnections, slotWidgets.button.InputBegan:Connect(function(inputObject: InputObject)
					if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 then
						return
					end

					local itemDefinition = ItemCatalog.getItemDefinition(itemId)
					self._dragState = {
						itemId = itemId,
						source = "Hotbar",
					}
					self._dragGhostLabel.Text = itemDefinition.displayName
					self._dragGhostLabel.Position = UDim2.fromOffset(inputObject.Position.X, inputObject.Position.Y)
					self._dragGhostLabel.Visible = true
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
		})

		if entry.itemId ~= "Scythe" then
			table.insert(self._itemConnections, itemButton.InputBegan:Connect(function(inputObject: InputObject)
				if not self._isInventoryPanelOpen or inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 then
					return
				end

				self._dragState = {
					itemId = entry.itemId,
					source = "Inventory",
				}
				self._dragGhostLabel.Text = itemDefinition.displayName
				self._dragGhostLabel.Position = UDim2.fromOffset(inputObject.Position.X, inputObject.Position.Y)
				self._dragGhostLabel.Visible = true
			end))
		end
	end
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

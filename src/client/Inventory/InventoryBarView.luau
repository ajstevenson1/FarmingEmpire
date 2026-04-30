--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder

local HotbarConfig = require(inventoryFolder:WaitForChild("HotbarConfig") :: ModuleScript)
local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)

type InventoryEntry = InventoryTypes.InventoryEntry
type InventorySnapshot = InventoryTypes.InventorySnapshot
type ItemDefinition = InventoryTypes.ItemDefinition
type ItemId = InventoryTypes.ItemId

type SortMode = "Name" | "Quantity" | "Category"

type SlotWidgets = {
	slotIndex: number,
	button: TextButton,
	stroke: UIStroke,
	slotNumberLabel: TextLabel,
	itemNameLabel: TextLabel,
	countLabel: TextLabel,
	clearButton: TextButton,
}

type InventoryRowWidgets = {
	button: TextButton,
}

type DragState = {
	itemId: ItemId,
}

export type InventoryBarView = {
	_screenGui: ScreenGui,
	_hotbarSlots: { SlotWidgets },
	_inventoryRows: { InventoryRowWidgets },
	_inventoryButton: TextButton,
	_inventoryPanel: Frame,
	_inventoryListFrame: ScrollingFrame,
	_sortButton: TextButton,
	_dragGhostLabel: TextLabel,
	_sortMode: SortMode,
	_isPanelOpen: boolean,
	_currentSnapshot: InventorySnapshot?,
	_dragState: DragState?,
	_connections: { RBXScriptConnection },
	_rowConnections: { RBXScriptConnection },
	_slotActivatedCallbacks: { (slotIndex: number) -> () },
	_hotbarAssignCallbacks: { (itemId: ItemId, slotIndex: number) -> () },
	_hotbarClearCallbacks: { (slotIndex: number) -> () },
	connectSlotActivated: (self: InventoryBarView, callback: (slotIndex: number) -> ()) -> (),
	connectHotbarAssignRequested: (self: InventoryBarView, callback: (itemId: ItemId, slotIndex: number) -> ()) -> (),
	connectHotbarClearRequested: (self: InventoryBarView, callback: (slotIndex: number) -> ()) -> (),
	render: (self: InventoryBarView, snapshot: InventorySnapshot?) -> (),
	destroy: (self: InventoryBarView) -> (),
}

local EMPTY_SLOT_COLOR = Color3.fromRGB(47, 47, 47)
local FILLED_SLOT_COLOR = Color3.fromRGB(122, 92, 53)
local SELECTED_SLOT_COLOR = Color3.fromRGB(163, 131, 78)
local DEFAULT_STROKE_COLOR = Color3.fromRGB(220, 199, 158)
local SELECTED_STROKE_COLOR = Color3.fromRGB(255, 240, 201)
local PANEL_COLOR = Color3.fromRGB(26, 23, 18)
local PANEL_SURFACE_COLOR = Color3.fromRGB(38, 33, 26)
local PANEL_TEXT_COLOR = Color3.fromRGB(244, 234, 213)

local InventoryBarView = {}
InventoryBarView.__index = InventoryBarView

local function sortEntries(entries: { InventoryEntry }, sortMode: SortMode): { InventoryEntry }
	local sortedEntries = table.clone(entries)
	table.sort(sortedEntries, function(leftEntry, rightEntry)
		local leftDefinition: ItemDefinition = ItemCatalog.getItemDefinition(leftEntry.itemId)
		local rightDefinition: ItemDefinition = ItemCatalog.getItemDefinition(rightEntry.itemId)

		if sortMode == "Quantity" and leftEntry.quantity ~= rightEntry.quantity then
			return leftEntry.quantity > rightEntry.quantity
		end

		if sortMode == "Category" and leftDefinition.kind ~= rightDefinition.kind then
			return leftDefinition.kind < rightDefinition.kind
		end

		return leftDefinition.displayName < rightDefinition.displayName
	end)

	return sortedEntries
end

local function getSortButtonText(sortMode: SortMode): string
	return string.format("Sort: %s", sortMode)
end

local function createLabel(parent: Instance, name: string, size: UDim2, position: UDim2, textSize: number, text: string, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = font
	label.Text = text
	label.TextColor3 = PANEL_TEXT_COLOR
	label.TextSize = textSize
	label.Parent = parent
	return label
end

local function getDisplayLabelForSlot(slotIndex: number): string
	if slotIndex == HotbarConfig.lockedSlotIndex then
		return ""
	end

	return tostring(slotIndex - 1)
end

local function createSlot(slotIndex: number, parent: Instance): SlotWidgets
	local button = Instance.new("TextButton")
	button.Name = string.format("Slot%d", slotIndex)
	button.LayoutOrder = slotIndex
	button.AutoButtonColor = false
	button.BackgroundColor3 = EMPTY_SLOT_COLOR
	button.BorderSizePixel = 0
	button.Size = UDim2.fromOffset(72, 72)
	button.Text = ""
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = DEFAULT_STROKE_COLOR
	stroke.Thickness = 1
	stroke.Transparency = 0.15
	stroke.Parent = button

	local slotNumberLabel = createLabel(
		button,
		"SlotNumber",
		UDim2.fromOffset(18, 16),
		UDim2.fromOffset(8, 6),
		12,
		getDisplayLabelForSlot(slotIndex),
		Enum.Font.GothamBold
	)
	slotNumberLabel.TextXAlignment = Enum.TextXAlignment.Left

	local itemNameLabel = createLabel(
		button,
		"ItemName",
		UDim2.new(1, -16, 1, -38),
		UDim2.fromOffset(8, 22),
		12,
		"",
		Enum.Font.GothamSemibold
	)
	itemNameLabel.TextWrapped = true

	local countLabel = createLabel(
		button,
		"Count",
		UDim2.fromOffset(40, 16),
		UDim2.new(1, -48, 1, -22),
		12,
		"",
		Enum.Font.GothamBold
	)
	countLabel.TextXAlignment = Enum.TextXAlignment.Right

	local clearButton = Instance.new("TextButton")
	clearButton.Name = "ClearButton"
	clearButton.AnchorPoint = Vector2.new(1, 0)
	clearButton.AutoButtonColor = false
	clearButton.BackgroundColor3 = Color3.fromRGB(121, 68, 68)
	clearButton.BorderSizePixel = 0
	clearButton.Position = UDim2.new(1, -4, 0, 4)
	clearButton.Size = UDim2.fromOffset(16, 16)
	clearButton.Text = "x"
	clearButton.TextColor3 = Color3.fromRGB(255, 240, 240)
	clearButton.TextSize = 10
	clearButton.Font = Enum.Font.GothamBold
	clearButton.Visible = false
	clearButton.Parent = button

	local clearCorner = Instance.new("UICorner")
	clearCorner.CornerRadius = UDim.new(1, 0)
	clearCorner.Parent = clearButton

	return {
		slotIndex = slotIndex,
		button = button,
		stroke = stroke,
		slotNumberLabel = slotNumberLabel,
		itemNameLabel = itemNameLabel,
		countLabel = countLabel,
		clearButton = clearButton,
	}
end

function InventoryBarView.new(): InventoryBarView
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before creating the inventory UI")
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TempInventoryBarGui"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 50
	screenGui.Parent = playerGui

	local inventoryButton = Instance.new("TextButton")
	inventoryButton.Name = "InventoryToggleButton"
	inventoryButton.AutoButtonColor = false
	inventoryButton.BackgroundColor3 = PANEL_COLOR
	inventoryButton.BorderSizePixel = 0
	inventoryButton.Position = UDim2.fromOffset(16, 16)
	inventoryButton.Size = UDim2.fromOffset(182, 42)
	inventoryButton.Text = "Open Inventory"
	inventoryButton.TextColor3 = PANEL_TEXT_COLOR
	inventoryButton.TextSize = 14
	inventoryButton.Font = Enum.Font.GothamBold
	inventoryButton.Parent = screenGui

	local inventoryButtonCorner = Instance.new("UICorner")
	inventoryButtonCorner.CornerRadius = UDim.new(0, 10)
	inventoryButtonCorner.Parent = inventoryButton

	local inventoryButtonStroke = Instance.new("UIStroke")
	inventoryButtonStroke.Color = DEFAULT_STROKE_COLOR
	inventoryButtonStroke.Transparency = 0.2
	inventoryButtonStroke.Parent = inventoryButton

	local inventoryPanel = Instance.new("Frame")
	inventoryPanel.Name = "InventoryPanel"
	inventoryPanel.BackgroundColor3 = PANEL_COLOR
	inventoryPanel.BorderSizePixel = 0
	inventoryPanel.Position = UDim2.fromOffset(16, 68)
	inventoryPanel.Size = UDim2.fromOffset(340, 430)
	inventoryPanel.Visible = false
	inventoryPanel.Parent = screenGui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 14)
	panelCorner.Parent = inventoryPanel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = DEFAULT_STROKE_COLOR
	panelStroke.Transparency = 0.1
	panelStroke.Parent = inventoryPanel

	local panelPadding = Instance.new("UIPadding")
	panelPadding.PaddingBottom = UDim.new(0, 12)
	panelPadding.PaddingLeft = UDim.new(0, 12)
	panelPadding.PaddingRight = UDim.new(0, 12)
	panelPadding.PaddingTop = UDim.new(0, 12)
	panelPadding.Parent = inventoryPanel

	createLabel(
		inventoryPanel,
		"PanelTitle",
		UDim2.new(1, -120, 0, 24),
		UDim2.fromOffset(0, 0),
		16,
		"TEMP INVENTORY UI",
		Enum.Font.GothamBold
	)

	local sortButton = Instance.new("TextButton")
	sortButton.Name = "SortButton"
	sortButton.AnchorPoint = Vector2.new(1, 0)
	sortButton.AutoButtonColor = false
	sortButton.BackgroundColor3 = PANEL_SURFACE_COLOR
	sortButton.BorderSizePixel = 0
	sortButton.Position = UDim2.new(1, 0, 0, 0)
	sortButton.Size = UDim2.fromOffset(116, 28)
	sortButton.Text = getSortButtonText("Name")
	sortButton.TextColor3 = PANEL_TEXT_COLOR
	sortButton.TextSize = 12
	sortButton.Font = Enum.Font.GothamSemibold
	sortButton.Parent = inventoryPanel

	local sortCorner = Instance.new("UICorner")
	sortCorner.CornerRadius = UDim.new(0, 10)
	sortCorner.Parent = sortButton

	createLabel(
		inventoryPanel,
		"PanelSubtitle",
		UDim2.new(1, 0, 0, 18),
		UDim2.fromOffset(0, 32),
		12,
		"Drag items from this list into hotbar slots 1-9. The scythe stays in the first slot.",
		Enum.Font.GothamSemibold
	)

	local inventoryListFrame = Instance.new("ScrollingFrame")
	inventoryListFrame.Name = "InventoryList"
	inventoryListFrame.Active = true
	inventoryListFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
	inventoryListFrame.BackgroundColor3 = PANEL_SURFACE_COLOR
	inventoryListFrame.BorderSizePixel = 0
	inventoryListFrame.CanvasSize = UDim2.fromOffset(0, 0)
	inventoryListFrame.Position = UDim2.fromOffset(0, 62)
	inventoryListFrame.Size = UDim2.new(1, 0, 1, -62)
	inventoryListFrame.ScrollBarImageColor3 = DEFAULT_STROKE_COLOR
	inventoryListFrame.ScrollBarThickness = 6
	inventoryListFrame.Parent = inventoryPanel

	local listCorner = Instance.new("UICorner")
	listCorner.CornerRadius = UDim.new(0, 10)
	listCorner.Parent = inventoryListFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.Parent = inventoryListFrame

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingBottom = UDim.new(0, 8)
	listPadding.PaddingLeft = UDim.new(0, 8)
	listPadding.PaddingRight = UDim.new(0, 8)
	listPadding.PaddingTop = UDim.new(0, 8)
	listPadding.Parent = inventoryListFrame

	local rootFrame = Instance.new("Frame")
	rootFrame.Name = "Root"
	rootFrame.AnchorPoint = Vector2.new(0.5, 1)
	rootFrame.BackgroundTransparency = 1
	rootFrame.Position = UDim2.fromScale(0.5, 0.97)
	rootFrame.Size = UDim2.fromOffset(838, 110)
	rootFrame.Parent = screenGui

	createLabel(
		rootFrame,
		"PlaceholderLabel",
		UDim2.new(1, 0, 0, 24),
		UDim2.fromOffset(0, 0),
		14,
		"TEMP INVENTORY UI - CODE GENERATED, REPLACE LATER",
		Enum.Font.GothamBold
	)

	local barFrame = Instance.new("Frame")
	barFrame.Name = "Bar"
	barFrame.AnchorPoint = Vector2.new(0.5, 1)
	barFrame.BackgroundColor3 = Color3.fromRGB(23, 23, 23)
	barFrame.BackgroundTransparency = 0.2
	barFrame.BorderSizePixel = 0
	barFrame.Position = UDim2.new(0.5, 0, 1, 0)
	barFrame.Size = UDim2.fromOffset(818, 78)
	barFrame.Parent = rootFrame

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 14)
	barCorner.Parent = barFrame

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = DEFAULT_STROKE_COLOR
	barStroke.Thickness = 1
	barStroke.Transparency = 0.35
	barStroke.Parent = barFrame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 3)
	padding.PaddingBottom = UDim.new(0, 3)
	padding.Parent = barFrame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = barFrame

	local hotbarSlots: { SlotWidgets } = {}
	for slotIndex = HotbarConfig.lockedSlotIndex, HotbarConfig.lastSlotIndex do
		table.insert(hotbarSlots, createSlot(slotIndex, barFrame))
	end

	local dragGhostLabel = Instance.new("TextLabel")
	dragGhostLabel.Name = "DragGhost"
	dragGhostLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	dragGhostLabel.BackgroundColor3 = Color3.fromRGB(63, 56, 45)
	dragGhostLabel.BackgroundTransparency = 0.15
	dragGhostLabel.BorderSizePixel = 0
	dragGhostLabel.Size = UDim2.fromOffset(140, 34)
	dragGhostLabel.Text = ""
	dragGhostLabel.TextColor3 = PANEL_TEXT_COLOR
	dragGhostLabel.TextSize = 13
	dragGhostLabel.Font = Enum.Font.GothamBold
	dragGhostLabel.Visible = false
	dragGhostLabel.ZIndex = 100
	dragGhostLabel.Parent = screenGui

	local dragCorner = Instance.new("UICorner")
	dragCorner.CornerRadius = UDim.new(0, 10)
	dragCorner.Parent = dragGhostLabel

	local self = setmetatable({
		_screenGui = screenGui,
		_hotbarSlots = hotbarSlots,
		_inventoryRows = {},
		_inventoryButton = inventoryButton,
		_inventoryPanel = inventoryPanel,
		_inventoryListFrame = inventoryListFrame,
		_sortButton = sortButton,
		_dragGhostLabel = dragGhostLabel,
		_sortMode = "Name" :: SortMode,
		_isPanelOpen = false,
		_currentSnapshot = nil,
		_dragState = nil,
		_connections = {},
		_rowConnections = {},
		_slotActivatedCallbacks = {},
		_hotbarAssignCallbacks = {},
		_hotbarClearCallbacks = {},
	}, InventoryBarView) :: InventoryBarView

	table.insert(self._connections, inventoryButton.Activated:Connect(function()
		self._isPanelOpen = not self._isPanelOpen
		self._inventoryPanel.Visible = self._isPanelOpen
		self._inventoryButton.Text = if self._isPanelOpen then "Close Inventory" else "Open Inventory"
		self:render(self._currentSnapshot)
	end))

	table.insert(self._connections, sortButton.Activated:Connect(function()
		if self._sortMode == "Name" then
			self._sortMode = "Quantity"
		elseif self._sortMode == "Quantity" then
			self._sortMode = "Category"
		else
			self._sortMode = "Name"
		end

		self._sortButton.Text = getSortButtonText(self._sortMode)
		self:render(self._currentSnapshot)
	end))

	for _, slot in ipairs(self._hotbarSlots) do
		table.insert(self._connections, slot.button.Activated:Connect(function()
			for _, callback in ipairs(self._slotActivatedCallbacks) do
				callback(slot.slotIndex)
			end
		end))

		table.insert(self._connections, slot.clearButton.Activated:Connect(function()
			for _, callback in ipairs(self._hotbarClearCallbacks) do
				callback(slot.slotIndex)
			end
		end))
	end

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

		local dropPosition = UserInputService:GetMouseLocation()
		for _, slot in ipairs(self._hotbarSlots) do
			if not HotbarConfig.isAssignableSlotIndex(slot.slotIndex) then
				continue
			end

			local buttonPosition = slot.button.AbsolutePosition
			local buttonSize = slot.button.AbsoluteSize
			local isInsideX = dropPosition.X >= buttonPosition.X and dropPosition.X <= buttonPosition.X + buttonSize.X
			local isInsideY = dropPosition.Y >= buttonPosition.Y and dropPosition.Y <= buttonPosition.Y + buttonSize.Y
			if isInsideX and isInsideY then
				for _, callback in ipairs(self._hotbarAssignCallbacks) do
					callback(dragState.itemId, slot.slotIndex)
				end
				break
			end
		end
	end))

	return self
end

function InventoryBarView:connectSlotActivated(callback: (slotIndex: number) -> ())
	table.insert(self._slotActivatedCallbacks, callback)
end

function InventoryBarView:connectHotbarAssignRequested(callback: (itemId: ItemId, slotIndex: number) -> ())
	table.insert(self._hotbarAssignCallbacks, callback)
end

function InventoryBarView:connectHotbarClearRequested(callback: (slotIndex: number) -> ())
	table.insert(self._hotbarClearCallbacks, callback)
end

function InventoryBarView:render(snapshot: InventorySnapshot?)
	self._currentSnapshot = snapshot

	if snapshot == nil then
		for _, slot in ipairs(self._hotbarSlots) do
			slot.button.BackgroundColor3 = EMPTY_SLOT_COLOR
			slot.stroke.Color = DEFAULT_STROKE_COLOR
			slot.stroke.Thickness = 1
			slot.itemNameLabel.Text = ""
			slot.countLabel.Text = ""
			slot.clearButton.Visible = false
		end

		for _, row in ipairs(self._inventoryRows) do
			row.button:Destroy()
		end
		self._inventoryRows = {}
		for _, connection in ipairs(self._rowConnections) do
			connection:Disconnect()
		end
		table.clear(self._rowConnections)
		self._inventoryListFrame.CanvasSize = UDim2.fromOffset(0, 0)
		return
	end

	local entriesByItemId: { [ItemId]: InventoryEntry } = {}
	for _, entry in ipairs(snapshot.entries) do
		entriesByItemId[entry.itemId] = entry
	end

	for _, slot in ipairs(self._hotbarSlots) do
		local itemId = snapshot.hotbarSlots[slot.slotIndex]
		local entry = if itemId ~= nil then entriesByItemId[itemId] else nil
		local isSelected = snapshot.selectedSlotIndex == slot.slotIndex

		if itemId ~= nil and entry ~= nil then
			local itemDefinition = ItemCatalog.getItemDefinition(itemId)
			slot.button.BackgroundColor3 = if isSelected then SELECTED_SLOT_COLOR else FILLED_SLOT_COLOR
			slot.stroke.Color = if isSelected then SELECTED_STROKE_COLOR else DEFAULT_STROKE_COLOR
			slot.stroke.Thickness = if isSelected then 2 else 1
			slot.itemNameLabel.Text = itemDefinition.displayName
			slot.countLabel.Text = string.format("x%d", entry.quantity)
			slot.clearButton.Visible = self._isPanelOpen and HotbarConfig.isAssignableSlotIndex(slot.slotIndex)
		else
			slot.button.BackgroundColor3 = EMPTY_SLOT_COLOR
			slot.stroke.Color = if isSelected then SELECTED_STROKE_COLOR else DEFAULT_STROKE_COLOR
			slot.stroke.Thickness = if isSelected then 2 else 1
			slot.itemNameLabel.Text = ""
			slot.countLabel.Text = ""
			slot.clearButton.Visible = false
		end
	end

	for _, row in ipairs(self._inventoryRows) do
		row.button:Destroy()
	end
	self._inventoryRows = {}
	for _, connection in ipairs(self._rowConnections) do
		connection:Disconnect()
	end
	table.clear(self._rowConnections)

	local sortedEntries = sortEntries(snapshot.entries, self._sortMode)
	local contentHeight = 0

	for _, entry in ipairs(sortedEntries) do
		local itemDefinition = ItemCatalog.getItemDefinition(entry.itemId)
		local rowButton = Instance.new("TextButton")
		rowButton.Name = string.format("%sRow", entry.itemId)
		rowButton.AutoButtonColor = false
		rowButton.BackgroundColor3 = PANEL_COLOR
		rowButton.BorderSizePixel = 0
		rowButton.Size = UDim2.new(1, -4, 0, 62)
		rowButton.Text = ""
		rowButton.Parent = self._inventoryListFrame

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 10)
		rowCorner.Parent = rowButton

		local rowStroke = Instance.new("UIStroke")
		rowStroke.Color = DEFAULT_STROKE_COLOR
		rowStroke.Transparency = 0.55
		rowStroke.Parent = rowButton

		local titleLabel = createLabel(
			rowButton,
			"Title",
			UDim2.new(1, -16, 0, 20),
			UDim2.fromOffset(8, 8),
			14,
			itemDefinition.displayName,
			Enum.Font.GothamBold
		)
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left

		local detailText = string.format("%s  |  x%d", itemDefinition.kind, entry.quantity)
		if entry.itemId == "Scythe" then
			detailText = detailText .. "  |  Locked to first slot"
		else
			for slotIndex = HotbarConfig.firstAssignableSlotIndex, HotbarConfig.lastSlotIndex do
				if snapshot.hotbarSlots[slotIndex] == entry.itemId then
					detailText = detailText .. string.format("  |  In slot %d", slotIndex - 1)
					break
				end
			end
		end

		local detailLabel = createLabel(
			rowButton,
			"Detail",
			UDim2.new(1, -16, 0, 18),
			UDim2.fromOffset(8, 34),
			12,
			detailText,
			Enum.Font.GothamSemibold
		)
		detailLabel.TextColor3 = Color3.fromRGB(219, 205, 180)
		detailLabel.TextXAlignment = Enum.TextXAlignment.Left

		if entry.itemId ~= "Scythe" then
			table.insert(self._rowConnections, rowButton.InputBegan:Connect(function(inputObject: InputObject)
				if not self._isPanelOpen or inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 then
					return
				end

				self._dragState = {
					itemId = entry.itemId,
				}

				self._dragGhostLabel.Text = itemDefinition.displayName
				self._dragGhostLabel.Position = UDim2.fromOffset(inputObject.Position.X, inputObject.Position.Y)
				self._dragGhostLabel.Visible = true
			end))
		end

		table.insert(self._inventoryRows, {
			button = rowButton,
		})

		contentHeight += 70
	end

	self._inventoryListFrame.CanvasSize = UDim2.fromOffset(0, math.max(contentHeight, self._inventoryListFrame.AbsoluteSize.Y))
end

function InventoryBarView:destroy()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	for _, connection in ipairs(self._rowConnections) do
		connection:Disconnect()
	end

	self._screenGui:Destroy()
end

return InventoryBarView

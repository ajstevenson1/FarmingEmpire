--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder

local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)

type InventorySnapshot = InventoryTypes.InventorySnapshot

type SlotWidgets = {
	button: TextButton,
	stroke: UIStroke,
	slotNumberLabel: TextLabel,
	itemNameLabel: TextLabel,
	countLabel: TextLabel,
}

export type InventoryBarView = {
	_screenGui: ScreenGui,
	_slots: { SlotWidgets },
	connectSlotActivated: (self: InventoryBarView, callback: (slotIndex: number) -> ()) -> (),
	render: (self: InventoryBarView, snapshot: InventorySnapshot) -> (),
	destroy: (self: InventoryBarView) -> (),
}

local HOTBAR_SLOT_COUNT = 9
local EMPTY_SLOT_COLOR = Color3.fromRGB(47, 47, 47)
local FILLED_SLOT_COLOR = Color3.fromRGB(122, 92, 53)
local SELECTED_SLOT_COLOR = Color3.fromRGB(163, 131, 78)
local DEFAULT_STROKE_COLOR = Color3.fromRGB(220, 199, 158)
local SELECTED_STROKE_COLOR = Color3.fromRGB(255, 240, 201)

local InventoryBarView = {}
InventoryBarView.__index = InventoryBarView

local function createSlot(index: number, parent: Instance): SlotWidgets
	local button = Instance.new("TextButton")
	button.Name = string.format("Slot%d", index)
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
	stroke.Color = Color3.fromRGB(220, 199, 158)
	stroke.Thickness = 1
	stroke.Transparency = 0.15
	stroke.Parent = button

	local slotNumberLabel = Instance.new("TextLabel")
	slotNumberLabel.Name = "SlotNumber"
	slotNumberLabel.BackgroundTransparency = 1
	slotNumberLabel.Position = UDim2.fromOffset(8, 6)
	slotNumberLabel.Size = UDim2.fromOffset(18, 16)
	slotNumberLabel.Font = Enum.Font.GothamBold
	slotNumberLabel.Text = tostring(index)
	slotNumberLabel.TextColor3 = Color3.fromRGB(240, 231, 214)
	slotNumberLabel.TextSize = 12
	slotNumberLabel.TextXAlignment = Enum.TextXAlignment.Left
	slotNumberLabel.Parent = button

	local itemNameLabel = Instance.new("TextLabel")
	itemNameLabel.Name = "ItemName"
	itemNameLabel.BackgroundTransparency = 1
	itemNameLabel.Position = UDim2.fromOffset(8, 22)
	itemNameLabel.Size = UDim2.new(1, -16, 1, -38)
	itemNameLabel.Font = Enum.Font.GothamSemibold
	itemNameLabel.Text = ""
	itemNameLabel.TextColor3 = Color3.fromRGB(255, 248, 236)
	itemNameLabel.TextSize = 12
	itemNameLabel.TextWrapped = true
	itemNameLabel.Parent = button

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "Count"
	countLabel.AnchorPoint = Vector2.new(1, 1)
	countLabel.BackgroundTransparency = 1
	countLabel.Position = UDim2.new(1, -8, 1, -6)
	countLabel.Size = UDim2.fromOffset(40, 16)
	countLabel.Font = Enum.Font.GothamBold
	countLabel.Text = ""
	countLabel.TextColor3 = Color3.fromRGB(255, 248, 236)
	countLabel.TextSize = 12
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.Parent = button

	return {
		button = button,
		stroke = stroke,
		slotNumberLabel = slotNumberLabel,
		itemNameLabel = itemNameLabel,
		countLabel = countLabel,
	}
end

function InventoryBarView.new(): InventoryBarView
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before creating the inventory bar")
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TempInventoryBarGui"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 50
	screenGui.Parent = playerGui

	local rootFrame = Instance.new("Frame")
	rootFrame.Name = "Root"
	rootFrame.AnchorPoint = Vector2.new(0.5, 1)
	rootFrame.BackgroundTransparency = 1
	rootFrame.Position = UDim2.fromScale(0.5, 0.97)
	rootFrame.Size = UDim2.fromOffset(760, 110)
	rootFrame.Parent = screenGui

	local placeholderLabel = Instance.new("TextLabel")
	placeholderLabel.Name = "PlaceholderLabel"
	placeholderLabel.BackgroundTransparency = 1
	placeholderLabel.Size = UDim2.new(1, 0, 0, 24)
	placeholderLabel.Font = Enum.Font.GothamBold
	placeholderLabel.Text = "TEMP INVENTORY UI - CODE GENERATED, REPLACE LATER"
	placeholderLabel.TextColor3 = Color3.fromRGB(239, 224, 190)
	placeholderLabel.TextSize = 14
	placeholderLabel.Parent = rootFrame

	local barFrame = Instance.new("Frame")
	barFrame.Name = "Bar"
	barFrame.AnchorPoint = Vector2.new(0.5, 1)
	barFrame.BackgroundColor3 = Color3.fromRGB(23, 23, 23)
	barFrame.BackgroundTransparency = 0.2
	barFrame.BorderSizePixel = 0
	barFrame.Position = UDim2.new(0.5, 0, 1, 0)
	barFrame.Size = UDim2.fromOffset(740, 78)
	barFrame.Parent = rootFrame

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 14)
	barCorner.Parent = barFrame

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = Color3.fromRGB(239, 224, 190)
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
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = barFrame

	local slots: { SlotWidgets } = {}
	for index = 1, HOTBAR_SLOT_COUNT do
		table.insert(slots, createSlot(index, barFrame))
	end

	local self = setmetatable({
		_screenGui = screenGui,
		_slots = slots,
	}, InventoryBarView) :: InventoryBarView

	return self
end

function InventoryBarView:connectSlotActivated(callback: (slotIndex: number) -> ())
	for slotIndex, slot in ipairs(self._slots) do
		slot.button.Activated:Connect(function()
			callback(slotIndex)
		end)
	end
end

function InventoryBarView:render(snapshot: InventorySnapshot)
	for index, slot in ipairs(self._slots) do
		local entry = snapshot.entries[index]
		local isSelected = entry ~= nil and snapshot.equippedItemId == entry.itemId

		if entry ~= nil then
			local itemDefinition = ItemCatalog.getItemDefinition(entry.itemId)
			slot.button.BackgroundColor3 = if isSelected then SELECTED_SLOT_COLOR else FILLED_SLOT_COLOR
			slot.stroke.Color = if isSelected then SELECTED_STROKE_COLOR else DEFAULT_STROKE_COLOR
			slot.stroke.Thickness = if isSelected then 2 else 1
			slot.itemNameLabel.Text = itemDefinition.displayName
			slot.countLabel.Text = string.format("x%d", entry.quantity)
		else
			slot.button.BackgroundColor3 = EMPTY_SLOT_COLOR
			slot.stroke.Color = DEFAULT_STROKE_COLOR
			slot.stroke.Thickness = 1
			slot.itemNameLabel.Text = ""
			slot.countLabel.Text = ""
		end
	end
end

function InventoryBarView:destroy()
	self._screenGui:Destroy()
end

return InventoryBarView

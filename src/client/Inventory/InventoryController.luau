--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder

local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local HotbarConfig = require(inventoryFolder:WaitForChild("HotbarConfig") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local InventoryBarView = require(script.Parent.InventoryBarView)
local FrameManager = require(script.Parent.Parent.UI.FrameManager)

type InventorySnapshot = InventoryTypes.InventorySnapshot
type ItemId = InventoryTypes.ItemId
type InventoryBarViewInstance = InventoryBarView.InventoryBarView

local hasStarted = false
local latestSnapshot: InventorySnapshot? = nil
local snapshotChangedListeners: { (InventorySnapshot) -> () } = {}
local INVENTORY_FRAME_ID = "InventoryMenu"
local MENU_FRAME_GROUP = "Menu"
local INVENTORY_TOGGLE_KEYCODE = Enum.KeyCode.Backquote

local HOTBAR_KEYCODES: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 2,
	[Enum.KeyCode.Two] = 3,
	[Enum.KeyCode.Three] = 4,
	[Enum.KeyCode.Four] = 5,
	[Enum.KeyCode.Five] = 6,
	[Enum.KeyCode.Six] = 7,
	[Enum.KeyCode.Seven] = 8,
	[Enum.KeyCode.Eight] = 9,
	[Enum.KeyCode.Nine] = 10,
}

local function disableDefaultBackpack()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
end

local function getInventoryRemotes(): (RemoteEvent, RemoteFunction, RemoteEvent, RemoteEvent, RemoteEvent)
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local remotesFolder = rootFolder:WaitForChild(RemoteNames.inventoryFolderName) :: Folder

	local inventoryUpdated = remotesFolder:WaitForChild(RemoteNames.inventoryUpdatedEventName) :: RemoteEvent
	local getInventorySnapshot = remotesFolder:WaitForChild(RemoteNames.getInventorySnapshotFunctionName) :: RemoteFunction
	local setSelectedSlot = remotesFolder:WaitForChild(RemoteNames.setSelectedSlotEventName) :: RemoteEvent
	local assignHotbarSlot = remotesFolder:WaitForChild(RemoteNames.assignHotbarSlotEventName) :: RemoteEvent
	local unassignHotbarItem = remotesFolder:WaitForChild(RemoteNames.unassignHotbarItemEventName) :: RemoteEvent

	return inventoryUpdated, getInventorySnapshot, setSelectedSlot, assignHotbarSlot, unassignHotbarItem
end

local function publishSnapshot(snapshot: InventorySnapshot, view: InventoryBarViewInstance)
	latestSnapshot = snapshot
	view:render(snapshot)

	for _, listener in ipairs(snapshotChangedListeners) do
		listener(snapshot)
	end
end

local function requestSlotSelection(snapshot: InventorySnapshot, slotIndex: number, setSelectedSlot: RemoteEvent)
	if not HotbarConfig.isSlotIndexInRange(slotIndex) then
		return
	end

	if snapshot.hotbarSlots[slotIndex] == nil then
		return
	end

	local nextSelectedSlotIndex: number? = slotIndex
	if snapshot.selectedSlotIndex == slotIndex then
		nextSelectedSlotIndex = nil
	end

	setSelectedSlot:FireServer(nextSelectedSlotIndex)
end

local function getClosedInventoryPanelPosition(panel: Frame): UDim2
	local openPosition = panel.Position
	local panelHeight = math.max(panel.AbsoluteSize.Y, panel.Size.Y.Offset, 64)
	local verticalPadding = 48
	return UDim2.new(
		openPosition.X.Scale,
		openPosition.X.Offset,
		1,
		panelHeight + verticalPadding
	)
end

local InventoryController = {}

function InventoryController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	disableDefaultBackpack()

	local view = InventoryBarView.new()
	local inventoryPanel = view:getInventoryPanel()
	FrameManager.registerFrame({
		id = INVENTORY_FRAME_ID,
		frame = inventoryPanel,
		group = MENU_FRAME_GROUP,
		defaultOpen = false,
		closedPosition = getClosedInventoryPanelPosition(inventoryPanel),
	})

	local inventoryUpdated, getInventorySnapshot, setSelectedSlot, assignHotbarSlot, unassignHotbarItem = getInventoryRemotes()
	local initialSnapshot = getInventorySnapshot:InvokeServer() :: InventorySnapshot

	FrameManager.observeFrameState(INVENTORY_FRAME_ID, function(isOpen: boolean)
		view:setInventoryPanelOpen(isOpen)
	end)

	publishSnapshot(initialSnapshot, view)

	view:connectInventoryToggleRequested(function()
		FrameManager.toggle(INVENTORY_FRAME_ID)
	end)

	view:connectSlotActivated(function(slotIndex: number)
		local currentSnapshot = latestSnapshot
		if currentSnapshot == nil then
			return
		end

		requestSlotSelection(currentSnapshot, slotIndex, setSelectedSlot)
	end)

	view:connectHotbarAssignRequested(function(itemId: ItemId, slotIndex: number)
		assignHotbarSlot:FireServer(slotIndex, itemId)
	end)

	view:connectHotbarUnassignRequested(function(itemId: ItemId)
		unassignHotbarItem:FireServer(itemId)
	end)

	inventoryUpdated.OnClientEvent:Connect(function(snapshot: InventorySnapshot)
		publishSnapshot(snapshot, view)
	end)

	UserInputService.InputBegan:Connect(function(inputObject: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if UserInputService:GetFocusedTextBox() ~= nil then
			return
		end

		if inputObject.KeyCode == INVENTORY_TOGGLE_KEYCODE then
			FrameManager.toggle(INVENTORY_FRAME_ID)
			return
		end

		local slotIndex = HOTBAR_KEYCODES[inputObject.KeyCode]
		if slotIndex == nil then
			return
		end

		local currentSnapshot = latestSnapshot
		if currentSnapshot == nil then
			return
		end

		requestSlotSelection(currentSnapshot, slotIndex, setSelectedSlot)
	end)
end

function InventoryController.getLatestSnapshot(): InventorySnapshot?
	return latestSnapshot
end

function InventoryController.observeSnapshotChanged(listener: (InventorySnapshot) -> ())
	table.insert(snapshotChangedListeners, listener)

	local snapshot = latestSnapshot
	if snapshot ~= nil then
		listener(snapshot)
	end
end

return table.freeze(InventoryController)

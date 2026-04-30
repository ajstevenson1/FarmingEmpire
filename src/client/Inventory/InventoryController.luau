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

type InventorySnapshot = InventoryTypes.InventorySnapshot
type ItemId = InventoryTypes.ItemId
type InventoryBarViewInstance = InventoryBarView.InventoryBarView

local hasStarted = false
local latestSnapshot: InventorySnapshot? = nil
local snapshotChangedListeners: { (InventorySnapshot) -> () } = {}

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
	local clearHotbarSlot = remotesFolder:WaitForChild(RemoteNames.clearHotbarSlotEventName) :: RemoteEvent

	return inventoryUpdated, getInventorySnapshot, setSelectedSlot, assignHotbarSlot, clearHotbarSlot
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

local InventoryController = {}

function InventoryController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	disableDefaultBackpack()

	local view = InventoryBarView.new()
	local inventoryUpdated, getInventorySnapshot, setSelectedSlot, assignHotbarSlot, clearHotbarSlot = getInventoryRemotes()
	local initialSnapshot = getInventorySnapshot:InvokeServer() :: InventorySnapshot

	publishSnapshot(initialSnapshot, view)

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

	view:connectHotbarClearRequested(function(slotIndex: number)
		clearHotbarSlot:FireServer(slotIndex)
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

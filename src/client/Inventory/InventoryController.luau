--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder

local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local InventoryBarView = require(script.Parent.InventoryBarView)

type ItemId = InventoryTypes.ItemId
type InventoryEntry = InventoryTypes.InventoryEntry
type InventorySnapshot = InventoryTypes.InventorySnapshot
type InventoryBarViewInstance = InventoryBarView.InventoryBarView

local hasStarted = false
local latestSnapshot: InventorySnapshot? = nil
local snapshotChangedListeners: { (InventorySnapshot) -> () } = {}

local HOTBAR_KEYCODES: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}

local function disableDefaultBackpack()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
end

local function getInventoryRemotes(): (RemoteEvent, RemoteFunction, RemoteEvent)
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local inventoryFolder = rootFolder:WaitForChild(RemoteNames.inventoryFolderName) :: Folder
	local inventoryUpdated = inventoryFolder:WaitForChild(RemoteNames.inventoryUpdatedEventName) :: RemoteEvent
	local getInventorySnapshot = inventoryFolder:WaitForChild(RemoteNames.getInventorySnapshotFunctionName) :: RemoteFunction
	local setEquippedItem = inventoryFolder:WaitForChild(RemoteNames.setEquippedItemEventName) :: RemoteEvent

	return inventoryUpdated, getInventorySnapshot, setEquippedItem
end

local function getSlotEntry(snapshot: InventorySnapshot, slotIndex: number): InventoryEntry?
	return snapshot.entries[slotIndex]
end

local function requestSlotEquip(snapshot: InventorySnapshot, slotIndex: number, setEquippedItem: RemoteEvent)
	local entry = getSlotEntry(snapshot, slotIndex)
	if entry == nil then
		return
	end

	local nextEquippedItemId: ItemId? = entry.itemId
	if snapshot.equippedItemId == entry.itemId then
		nextEquippedItemId = nil
	end

	setEquippedItem:FireServer(nextEquippedItemId)
end

local function publishSnapshot(snapshot: InventorySnapshot, view: InventoryBarViewInstance): ()
	latestSnapshot = snapshot
	view:render(snapshot)

	for _, listener in ipairs(snapshotChangedListeners) do
		listener(snapshot)
	end
end

local InventoryController = {}

function InventoryController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	disableDefaultBackpack()

	local view = InventoryBarView.new()
	local inventoryUpdated, getInventorySnapshot, setEquippedItem = getInventoryRemotes()
	local initialSnapshot = getInventorySnapshot:InvokeServer() :: InventorySnapshot

	publishSnapshot(initialSnapshot, view)
	view:connectSlotActivated(function(slotIndex: number)
		local currentSnapshot = latestSnapshot
		if currentSnapshot == nil then
			return
		end

		requestSlotEquip(currentSnapshot, slotIndex, setEquippedItem)
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

		requestSlotEquip(currentSnapshot, slotIndex, setEquippedItem)
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

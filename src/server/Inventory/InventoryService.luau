--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder

local HotbarConfig = require(inventoryFolder:WaitForChild("HotbarConfig") :: ModuleScript)
local InventoryUtils = require(inventoryFolder:WaitForChild("InventoryUtils") :: ModuleScript)
local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local StartingHotbarConfig = require(inventoryFolder:WaitForChild("StartingHotbarConfig") :: ModuleScript)
local StartingInventoryConfig = require(inventoryFolder:WaitForChild("StartingInventoryConfig") :: ModuleScript)
local Remotes = require(script.Parent.Parent.Networking.Remotes)

type HotbarSlots = InventoryTypes.HotbarSlots
type InventoryEntry = InventoryTypes.InventoryEntry
type InventorySnapshot = InventoryTypes.InventorySnapshot
type ItemDefinition = InventoryTypes.ItemDefinition
type ItemId = InventoryTypes.ItemId

type PlayerInventoryState = {
	quantitiesByItemId: { [ItemId]: number },
	hotbarSlots: HotbarSlots,
	selectedSlotIndex: number?,
}

local InventoryService = {}
local playerInventories: { [Player]: PlayerInventoryState } = {}
local selectedItemChangedListeners: { (Player, ItemId?) -> () } = {}
local hasStarted = false

local function createInventoryState(): PlayerInventoryState
	return {
		quantitiesByItemId = {},
		hotbarSlots = {
			[HotbarConfig.lockedSlotIndex] = "Scythe",
		},
		selectedSlotIndex = HotbarConfig.defaultSelectedSlotIndex,
	}
end

local function getItemQuantity(state: PlayerInventoryState, itemId: ItemId): number
	return state.quantitiesByItemId[itemId] or 0
end

local function addItem(state: PlayerInventoryState, itemId: ItemId, quantity: number)
	if quantity <= 0 then
		return
	end

	local currentQuantity = getItemQuantity(state, itemId)
	state.quantitiesByItemId[itemId] = currentQuantity + quantity
end

local function playerHasItem(state: PlayerInventoryState, itemId: ItemId): boolean
	return getItemQuantity(state, itemId) > 0
end

local function findAssignedSlotIndex(state: PlayerInventoryState, itemId: ItemId): number?
	for slotIndex = HotbarConfig.firstAssignableSlotIndex, HotbarConfig.lastSlotIndex do
		if state.hotbarSlots[slotIndex] == itemId then
			return slotIndex
		end
	end

	return nil
end

local function sanitizeState(state: PlayerInventoryState)
	if getItemQuantity(state, "Scythe") <= 0 then
		state.quantitiesByItemId.Scythe = 1
	end

	state.hotbarSlots[HotbarConfig.lockedSlotIndex] = "Scythe"

	local seenAssignedItems: { [ItemId]: boolean } = {
		Scythe = true,
	}

	for slotIndex = HotbarConfig.firstAssignableSlotIndex, HotbarConfig.lastSlotIndex do
		local itemId = state.hotbarSlots[slotIndex]
		if itemId ~= nil then
			local isInvalidAssignment = itemId == "Scythe"
				or not playerHasItem(state, itemId)
				or seenAssignedItems[itemId] == true

			if isInvalidAssignment then
				state.hotbarSlots[slotIndex] = nil
			else
				seenAssignedItems[itemId] = true
			end
		end
	end

	local selectedSlotIndex = state.selectedSlotIndex
	if selectedSlotIndex == nil then
		return
	end

	if not HotbarConfig.isSlotIndexInRange(selectedSlotIndex) then
		state.selectedSlotIndex = nil
		return
	end

	if state.hotbarSlots[selectedSlotIndex] == nil then
		state.selectedSlotIndex = nil
	end
end

local function removeItem(state: PlayerInventoryState, itemId: ItemId, quantity: number): boolean
	if itemId == "Scythe" then
		return false
	end

	local currentQuantity = getItemQuantity(state, itemId)
	if quantity <= 0 or currentQuantity < quantity then
		return false
	end

	local nextQuantity = currentQuantity - quantity
	if nextQuantity > 0 then
		state.quantitiesByItemId[itemId] = nextQuantity
	else
		state.quantitiesByItemId[itemId] = nil
	end

	sanitizeState(state)
	return true
end

local function applyStartingInventory(state: PlayerInventoryState)
	for _, entry in ipairs(StartingInventoryConfig) do
		addItem(state, entry.itemId, entry.quantity)
	end
end

local function applyStartingHotbar(state: PlayerInventoryState)
	for slotIndex, itemIdValue in pairs(StartingHotbarConfig) do
		if type(slotIndex) == "number"
			and HotbarConfig.isAssignableSlotIndex(slotIndex)
			and type(itemIdValue) == "string"
			and ItemCatalog.hasItemDefinition(itemIdValue)
		then
			local itemId = itemIdValue :: ItemId
			if playerHasItem(state, itemId) then
				state.hotbarSlots[slotIndex] = itemId
			end
		end
	end

	sanitizeState(state)
end

local function getSortedEntries(state: PlayerInventoryState): { InventoryEntry }
	local entries: { InventoryEntry } = {}

	for itemId, quantity in pairs(state.quantitiesByItemId) do
		if quantity > 0 then
			table.insert(entries, {
				itemId = itemId,
				quantity = quantity,
			})
		end
	end

	table.sort(entries, function(leftEntry, rightEntry)
		local leftDefinition: ItemDefinition = ItemCatalog.getItemDefinition(leftEntry.itemId)
		local rightDefinition: ItemDefinition = ItemCatalog.getItemDefinition(rightEntry.itemId)

		if leftDefinition.inventoryOrder == rightDefinition.inventoryOrder then
			return leftDefinition.displayName < rightDefinition.displayName
		end

		return leftDefinition.inventoryOrder < rightDefinition.inventoryOrder
	end)

	return entries
end

local function buildSnapshot(state: PlayerInventoryState): InventorySnapshot
	sanitizeState(state)

	return {
		entries = getSortedEntries(state),
		hotbarSlots = InventoryUtils.cloneHotbarSlots(state.hotbarSlots),
		selectedSlotIndex = state.selectedSlotIndex,
	}
end

local function getPlayerInventoryState(player: Player): PlayerInventoryState
	local existingState = playerInventories[player]
	if existingState ~= nil then
		return existingState
	end

	local newState = createInventoryState()
	applyStartingInventory(newState)
	applyStartingHotbar(newState)
	playerInventories[player] = newState

	return newState
end

local function pushInventoryUpdate(player: Player)
	local inventoryRemotes = Remotes.getInventoryRemotes()
	local inventoryState = getPlayerInventoryState(player)
	inventoryRemotes.inventoryUpdated:FireClient(player, buildSnapshot(inventoryState))
end

local function notifySelectedItemChanged(player: Player, previousItemId: ItemId?, nextItemId: ItemId?)
	if previousItemId == nextItemId then
		return
	end

	for _, listener in ipairs(selectedItemChangedListeners) do
		listener(player, nextItemId)
	end
end

local function setSelectedSlot(player: Player, requestedSlotIndex: number?)
	local inventoryState = getPlayerInventoryState(player)
	sanitizeState(inventoryState)
	local previousItemId = InventoryService.getEquippedItemId(player)

	if requestedSlotIndex == nil then
		inventoryState.selectedSlotIndex = nil
		notifySelectedItemChanged(player, previousItemId, nil)
		pushInventoryUpdate(player)
		return
	end

	if not HotbarConfig.isSlotIndexInRange(requestedSlotIndex) then
		pushInventoryUpdate(player)
		return
	end

	if inventoryState.hotbarSlots[requestedSlotIndex] == nil then
		pushInventoryUpdate(player)
		return
	end

	if inventoryState.selectedSlotIndex == requestedSlotIndex then
		inventoryState.selectedSlotIndex = nil
	else
		inventoryState.selectedSlotIndex = requestedSlotIndex
	end

	notifySelectedItemChanged(player, previousItemId, InventoryService.getEquippedItemId(player))
	pushInventoryUpdate(player)
end

local function assignItemToHotbarSlot(player: Player, requestedSlotIndex: number, requestedItemId: ItemId)
	local inventoryState = getPlayerInventoryState(player)
	sanitizeState(inventoryState)

	if not HotbarConfig.isAssignableSlotIndex(requestedSlotIndex) then
		pushInventoryUpdate(player)
		return
	end

	if requestedItemId == "Scythe" or not playerHasItem(inventoryState, requestedItemId) then
		pushInventoryUpdate(player)
		return
	end

	local sourceSlotIndex = findAssignedSlotIndex(inventoryState, requestedItemId)
	local targetItemId = inventoryState.hotbarSlots[requestedSlotIndex]

	if sourceSlotIndex == requestedSlotIndex then
		pushInventoryUpdate(player)
		return
	end

	inventoryState.hotbarSlots[requestedSlotIndex] = requestedItemId

	if sourceSlotIndex ~= nil then
		inventoryState.hotbarSlots[sourceSlotIndex] = targetItemId
	end

	sanitizeState(inventoryState)
	pushInventoryUpdate(player)
end

local function clearHotbarSlot(player: Player, requestedSlotIndex: number)
	local inventoryState = getPlayerInventoryState(player)
	if not HotbarConfig.isAssignableSlotIndex(requestedSlotIndex) then
		pushInventoryUpdate(player)
		return
	end

	local previousItemId = InventoryService.getEquippedItemId(player)
	inventoryState.hotbarSlots[requestedSlotIndex] = nil
	if inventoryState.selectedSlotIndex == requestedSlotIndex then
		inventoryState.selectedSlotIndex = nil
	end

	sanitizeState(inventoryState)
	notifySelectedItemChanged(player, previousItemId, InventoryService.getEquippedItemId(player))
	pushInventoryUpdate(player)
end

local function initializePlayer(player: Player)
	local inventoryState = createInventoryState()
	applyStartingInventory(inventoryState)
	applyStartingHotbar(inventoryState)
	playerInventories[player] = inventoryState
	pushInventoryUpdate(player)
end

local function cleanupPlayer(player: Player)
	playerInventories[player] = nil
end

function InventoryService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local inventoryRemotes = Remotes.getInventoryRemotes()
	inventoryRemotes.getInventorySnapshot.OnServerInvoke = function(player: Player): InventorySnapshot
		return buildSnapshot(getPlayerInventoryState(player))
	end

	inventoryRemotes.setSelectedSlot.OnServerEvent:Connect(function(player: Player, requestedSlotIndex: unknown)
		if requestedSlotIndex == nil then
			setSelectedSlot(player, nil)
			return
		end

		if type(requestedSlotIndex) ~= "number" then
			pushInventoryUpdate(player)
			return
		end

		setSelectedSlot(player, requestedSlotIndex)
	end)

	inventoryRemotes.assignHotbarSlot.OnServerEvent:Connect(function(player: Player, requestedSlotIndex: unknown, requestedItemId: unknown)
		if type(requestedSlotIndex) ~= "number" or type(requestedItemId) ~= "string" then
			pushInventoryUpdate(player)
			return
		end

		if not ItemCatalog.hasItemDefinition(requestedItemId) then
			pushInventoryUpdate(player)
			return
		end

		assignItemToHotbarSlot(player, requestedSlotIndex, requestedItemId :: ItemId)
	end)

	inventoryRemotes.clearHotbarSlot.OnServerEvent:Connect(function(player: Player, requestedSlotIndex: unknown)
		if type(requestedSlotIndex) ~= "number" then
			pushInventoryUpdate(player)
			return
		end

		clearHotbarSlot(player, requestedSlotIndex)
	end)

	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(cleanupPlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		initializePlayer(player)
	end
end

function InventoryService.getEquippedItemId(player: Player): ItemId?
	local inventoryState = getPlayerInventoryState(player)
	sanitizeState(inventoryState)

	local selectedSlotIndex = inventoryState.selectedSlotIndex
	if selectedSlotIndex == nil then
		return nil
	end

	return inventoryState.hotbarSlots[selectedSlotIndex]
end

function InventoryService.tryConsumeItem(player: Player, itemId: ItemId, quantity: number): boolean
	local inventoryState = getPlayerInventoryState(player)
	local previousItemId = InventoryService.getEquippedItemId(player)
	local didConsume = removeItem(inventoryState, itemId, quantity)
	if didConsume then
		notifySelectedItemChanged(player, previousItemId, InventoryService.getEquippedItemId(player))
		pushInventoryUpdate(player)
	end

	return didConsume
end

function InventoryService.observeEquippedItemChanged(listener: (Player, ItemId?) -> ())
	table.insert(selectedItemChangedListeners, listener)
end

return table.freeze(InventoryService)

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
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)
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

type HotbarSlotData = {
	slotIndex: number,
	itemId: ItemId,
}

type PlayerInventoryData = {
	entries: { InventoryEntry },
	hotbarSlots: { HotbarSlotData },
	selectedSlotIndex: number?,
}

local InventoryService = {}
local playerInventories: { [Player]: PlayerInventoryState } = {}
local selectedItemChangedListeners: { (Player, ItemId?) -> () } = {}
local hasStarted = false
local MAX_ASSIGNABLE_SLOTS = HotbarConfig.lastSlotIndex - HotbarConfig.firstAssignableSlotIndex + 1

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

local function getSelectedItemIdFromState(state: PlayerInventoryState): ItemId?
	local selectedSlotIndex = state.selectedSlotIndex
	if selectedSlotIndex == nil then
		return nil
	end

	return state.hotbarSlots[selectedSlotIndex]
end

local function getAssignedHotbarItems(state: PlayerInventoryState): { ItemId }
	local assignedItems: { ItemId } = {}
	local seenAssignedItems: { [ItemId]: boolean } = {
		Scythe = true,
	}

	for slotIndex = HotbarConfig.firstAssignableSlotIndex, HotbarConfig.lastSlotIndex do
		local itemId = state.hotbarSlots[slotIndex]
		if itemId == nil then
			continue
		end

		if itemId == "Scythe" or not playerHasItem(state, itemId) or seenAssignedItems[itemId] == true then
			continue
		end

		seenAssignedItems[itemId] = true
		table.insert(assignedItems, itemId)
	end

	return assignedItems
end

local function applyAssignedHotbarItems(state: PlayerInventoryState, assignedItems: { ItemId }, selectedItemId: ItemId?)
	state.hotbarSlots[HotbarConfig.lockedSlotIndex] = "Scythe"

	for slotIndex = HotbarConfig.firstAssignableSlotIndex, HotbarConfig.lastSlotIndex do
		state.hotbarSlots[slotIndex] = nil
	end

	for index, itemId in ipairs(assignedItems) do
		if index > MAX_ASSIGNABLE_SLOTS then
			break
		end

		state.hotbarSlots[HotbarConfig.firstAssignableSlotIndex + index - 1] = itemId
	end

	if selectedItemId == "Scythe" then
		state.selectedSlotIndex = HotbarConfig.lockedSlotIndex
		return
	end

	if selectedItemId ~= nil then
		for slotIndex = HotbarConfig.firstAssignableSlotIndex, HotbarConfig.lastSlotIndex do
			if state.hotbarSlots[slotIndex] == selectedItemId then
				state.selectedSlotIndex = slotIndex
				return
			end
		end
	end

	state.selectedSlotIndex = nil
end

local function sanitizeState(state: PlayerInventoryState)
	if getItemQuantity(state, "Scythe") <= 0 then
		state.quantitiesByItemId.Scythe = 1
	end

	local selectedItemId = getSelectedItemIdFromState(state)
	applyAssignedHotbarItems(state, getAssignedHotbarItems(state), selectedItemId)
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

local function applySavedInventory(state: PlayerInventoryState, inventoryData: PlayerInventoryData)
	for _, entry in ipairs(inventoryData.entries) do
		addItem(state, entry.itemId, entry.quantity)
	end

	for _, hotbarSlot in ipairs(inventoryData.hotbarSlots) do
		if HotbarConfig.isAssignableSlotIndex(hotbarSlot.slotIndex)
			and hotbarSlot.itemId ~= "Scythe"
			and playerHasItem(state, hotbarSlot.itemId)
		then
			state.hotbarSlots[hotbarSlot.slotIndex] = hotbarSlot.itemId
		end
	end

	state.selectedSlotIndex = inventoryData.selectedSlotIndex
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

local function buildInventoryData(state: PlayerInventoryState): PlayerInventoryData
	sanitizeState(state)

	local hotbarSlots: { HotbarSlotData } = {}
	for slotIndex = HotbarConfig.firstAssignableSlotIndex, HotbarConfig.lastSlotIndex do
		local itemId = state.hotbarSlots[slotIndex]
		if itemId ~= nil then
			table.insert(hotbarSlots, {
				slotIndex = slotIndex,
				itemId = itemId,
			})
		end
	end

	return {
		entries = getSortedEntries(state),
		hotbarSlots = hotbarSlots,
		selectedSlotIndex = state.selectedSlotIndex,
	}
end

local function buildSnapshot(state: PlayerInventoryState): InventorySnapshot
	sanitizeState(state)

	return {
		entries = getSortedEntries(state),
		hotbarSlots = InventoryUtils.cloneHotbarSlots(state.hotbarSlots),
		selectedSlotIndex = state.selectedSlotIndex,
	}
end

local function syncInventoryStateToPlayerData(player: Player, state: PlayerInventoryState)
	PlayerDataService.setInventory(player, buildInventoryData(state))
end

local function createInventoryStateForPlayer(player: Player): PlayerInventoryState
	local newState = createInventoryState()
	local savedInventory = PlayerDataService.getInventory(player)

	if savedInventory ~= nil then
		applySavedInventory(newState, savedInventory)
	else
		applyStartingInventory(newState)
		applyStartingHotbar(newState)
	end

	return newState
end

local function getPlayerInventoryState(player: Player): PlayerInventoryState
	local existingState = playerInventories[player]
	if existingState ~= nil then
		return existingState
	end

	local newState = createInventoryStateForPlayer(player)
	playerInventories[player] = newState
	syncInventoryStateToPlayerData(player, newState)

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
		syncInventoryStateToPlayerData(player, inventoryState)
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
	syncInventoryStateToPlayerData(player, inventoryState)
	pushInventoryUpdate(player)
end

local function assignItemToHotbarSlot(player: Player, requestedSlotIndex: number, requestedItemId: ItemId)
	local inventoryState = getPlayerInventoryState(player)
	sanitizeState(inventoryState)
	local previousItemId = InventoryService.getEquippedItemId(player)

	if not HotbarConfig.isAssignableSlotIndex(requestedSlotIndex) then
		pushInventoryUpdate(player)
		return
	end

	if requestedItemId == "Scythe" or not playerHasItem(inventoryState, requestedItemId) then
		pushInventoryUpdate(player)
		return
	end

	local assignedItems = getAssignedHotbarItems(inventoryState)
	local existingIndex: number? = nil
	for index, itemId in ipairs(assignedItems) do
		if itemId == requestedItemId then
			existingIndex = index
			table.remove(assignedItems, index)
			break
		end
	end

	local insertIndex = requestedSlotIndex - HotbarConfig.firstAssignableSlotIndex + 1
	insertIndex = math.clamp(insertIndex, 1, #assignedItems + 1)

	if existingIndex == nil and #assignedItems >= MAX_ASSIGNABLE_SLOTS then
		table.remove(assignedItems, math.min(insertIndex, #assignedItems))
	end

	table.insert(assignedItems, insertIndex, requestedItemId)
	while #assignedItems > MAX_ASSIGNABLE_SLOTS do
		table.remove(assignedItems)
	end

	applyAssignedHotbarItems(inventoryState, assignedItems, previousItemId)
	syncInventoryStateToPlayerData(player, inventoryState)
	notifySelectedItemChanged(player, previousItemId, InventoryService.getEquippedItemId(player))
	pushInventoryUpdate(player)
end

local function unassignHotbarItem(player: Player, requestedItemId: ItemId)
	local inventoryState = getPlayerInventoryState(player)
	sanitizeState(inventoryState)
	local previousItemId = InventoryService.getEquippedItemId(player)

	if requestedItemId == "Scythe" then
		pushInventoryUpdate(player)
		return
	end

	local assignedItems = getAssignedHotbarItems(inventoryState)
	local didRemove = false
	for index, itemId in ipairs(assignedItems) do
		if itemId == requestedItemId then
			table.remove(assignedItems, index)
			didRemove = true
			break
		end
	end

	if not didRemove then
		pushInventoryUpdate(player)
		return
	end

	local nextSelectedItemId = if previousItemId == requestedItemId then nil else previousItemId
	applyAssignedHotbarItems(inventoryState, assignedItems, nextSelectedItemId)
	notifySelectedItemChanged(player, previousItemId, InventoryService.getEquippedItemId(player))
	syncInventoryStateToPlayerData(player, inventoryState)
	pushInventoryUpdate(player)
end

local function initializePlayer(player: Player)
	local inventoryState = createInventoryStateForPlayer(player)
	playerInventories[player] = inventoryState
	syncInventoryStateToPlayerData(player, inventoryState)
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

	inventoryRemotes.unassignHotbarItem.OnServerEvent:Connect(function(player: Player, requestedItemId: unknown)
		if type(requestedItemId) ~= "string" then
			pushInventoryUpdate(player)
			return
		end

		if not ItemCatalog.hasItemDefinition(requestedItemId) then
			pushInventoryUpdate(player)
			return
		end

		unassignHotbarItem(player, requestedItemId :: ItemId)
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
		syncInventoryStateToPlayerData(player, inventoryState)
		notifySelectedItemChanged(player, previousItemId, InventoryService.getEquippedItemId(player))
		pushInventoryUpdate(player)
	end

	return didConsume
end

function InventoryService.addItem(player: Player, itemId: ItemId, quantity: number)
	local inventoryState = getPlayerInventoryState(player)
	addItem(inventoryState, itemId, quantity)
	sanitizeState(inventoryState)
	syncInventoryStateToPlayerData(player, inventoryState)
	pushInventoryUpdate(player)
end

function InventoryService.observeEquippedItemChanged(listener: (Player, ItemId?) -> ())
	table.insert(selectedItemChangedListeners, listener)
end

return table.freeze(InventoryService)

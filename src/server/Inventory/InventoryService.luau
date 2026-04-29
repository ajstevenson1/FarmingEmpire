--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder

local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local StartingInventoryConfig = require(inventoryFolder:WaitForChild("StartingInventoryConfig") :: ModuleScript)
local Remotes = require(script.Parent.Parent.Networking.Remotes)

type ItemId = InventoryTypes.ItemId
type InventoryEntry = InventoryTypes.InventoryEntry
type InventorySnapshot = InventoryTypes.InventorySnapshot

type PlayerInventoryState = {
	quantitiesByItemId: { [ItemId]: number },
	equippedItemId: ItemId?,
}

local playerInventories: { [Player]: PlayerInventoryState } = {}
local hasStarted = false

local function createInventoryState(): PlayerInventoryState
	return {
		quantitiesByItemId = {},
		equippedItemId = nil,
	}
end

local function addItem(state: PlayerInventoryState, itemId: ItemId, quantity: number)
	local currentQuantity = state.quantitiesByItemId[itemId] or 0
	state.quantitiesByItemId[itemId] = currentQuantity + quantity
end

local function getItemQuantity(state: PlayerInventoryState, itemId: ItemId): number
	return state.quantitiesByItemId[itemId] or 0
end

local function playerHasItem(state: PlayerInventoryState, itemId: ItemId): boolean
	return getItemQuantity(state, itemId) > 0
end

local function sanitizeEquippedItem(state: PlayerInventoryState)
	local equippedItemId = state.equippedItemId
	if equippedItemId == nil then
		return
	end

	if not playerHasItem(state, equippedItemId) then
		state.equippedItemId = nil
	end
end

local function removeItem(state: PlayerInventoryState, itemId: ItemId, quantity: number): boolean
	local currentQuantity = getItemQuantity(state, itemId)
	if currentQuantity < quantity then
		return false
	end

	state.quantitiesByItemId[itemId] = currentQuantity - quantity
	sanitizeEquippedItem(state)

	return true
end

local function applyStartingInventory(state: PlayerInventoryState)
	for _, entry in ipairs(StartingInventoryConfig) do
		addItem(state, entry.itemId, entry.quantity)
	end
end

local function buildSnapshot(state: PlayerInventoryState): InventorySnapshot
	sanitizeEquippedItem(state)

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
		local leftDefinition = ItemCatalog.getItemDefinition(leftEntry.itemId)
		local rightDefinition = ItemCatalog.getItemDefinition(rightEntry.itemId)

		if leftDefinition.hotbarOrder == rightDefinition.hotbarOrder then
			return leftDefinition.displayName < rightDefinition.displayName
		end

		return leftDefinition.hotbarOrder < rightDefinition.hotbarOrder
	end)

	return {
		entries = entries,
		equippedItemId = state.equippedItemId,
	}
end

local function getPlayerInventoryState(player: Player): PlayerInventoryState
	local existingState = playerInventories[player]
	if existingState ~= nil then
		return existingState
	end

	local newState = createInventoryState()
	applyStartingInventory(newState)
	playerInventories[player] = newState

	return newState
end

local function pushInventoryUpdate(player: Player)
	local inventoryRemotes = Remotes.getInventoryRemotes()
	local inventoryState = getPlayerInventoryState(player)
	local snapshot = buildSnapshot(inventoryState)

	inventoryRemotes.inventoryUpdated:FireClient(player, snapshot)
end

local function setEquippedItem(player: Player, itemId: ItemId?)
	local inventoryState = getPlayerInventoryState(player)

	if itemId == nil then
		inventoryState.equippedItemId = nil
		pushInventoryUpdate(player)
		return
	end

	if not playerHasItem(inventoryState, itemId) then
		pushInventoryUpdate(player)
		return
	end

	if inventoryState.equippedItemId == itemId then
		inventoryState.equippedItemId = nil
	else
		inventoryState.equippedItemId = itemId
	end

	pushInventoryUpdate(player)
end

local function initializePlayer(player: Player)
	local inventoryState = createInventoryState()
	applyStartingInventory(inventoryState)
	playerInventories[player] = inventoryState
	pushInventoryUpdate(player)
end

local function cleanupPlayer(player: Player)
	playerInventories[player] = nil
end

local InventoryService = {}

function InventoryService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local inventoryRemotes = Remotes.getInventoryRemotes()
	inventoryRemotes.getInventorySnapshot.OnServerInvoke = function(player: Player): InventorySnapshot
		local inventoryState = getPlayerInventoryState(player)
		return buildSnapshot(inventoryState)
	end
	inventoryRemotes.setEquippedItem.OnServerEvent:Connect(function(player: Player, requestedItemId: unknown)
		if requestedItemId == nil then
			setEquippedItem(player, nil)
			return
		end

		if type(requestedItemId) ~= "string" then
			pushInventoryUpdate(player)
			return
		end

		if not ItemCatalog.hasItemDefinition(requestedItemId) then
			pushInventoryUpdate(player)
			return
		end

		setEquippedItem(player, requestedItemId :: ItemId)
	end)

	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(cleanupPlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		initializePlayer(player)
	end
end

function InventoryService.getEquippedItemId(player: Player): ItemId?
	local inventoryState = getPlayerInventoryState(player)
	sanitizeEquippedItem(inventoryState)
	return inventoryState.equippedItemId
end

function InventoryService.tryConsumeItem(player: Player, itemId: ItemId, quantity: number): boolean
	local inventoryState = getPlayerInventoryState(player)
	local didConsume = removeItem(inventoryState, itemId, quantity)
	if didConsume then
		pushInventoryUpdate(player)
	end

	return didConsume
end

return table.freeze(InventoryService)

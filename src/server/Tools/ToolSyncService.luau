--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local toolsFolder = ReplicatedStorage:WaitForChild("Tools") :: Folder

local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local InventoryService = require(script.Parent.Parent.Inventory.InventoryService)

type ItemDefinition = InventoryTypes.ItemDefinition
type ItemId = InventoryTypes.ItemId

local SYSTEM_TOOL_ITEM_ID_ATTRIBUTE = "SystemToolItemId"
local hasStarted = false

local function getSystemToolInstances(container: Instance?, itemId: ItemId): { Tool }
	if container == nil then
		return {}
	end

	local tools: { Tool } = {}
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute(SYSTEM_TOOL_ITEM_ID_ATTRIBUTE) == itemId then
			table.insert(tools, child)
		end
	end

	return tools
end

local function destroySystemToolInstances(player: Player, itemId: ItemId)
	for _, tool in ipairs(getSystemToolInstances(player:FindFirstChildOfClass("Backpack"), itemId)) do
		tool:Destroy()
	end

	local character = player.Character
	if character ~= nil then
		for _, tool in ipairs(getSystemToolInstances(character, itemId)) do
			tool:Destroy()
		end
	end
end

local function getToolTemplate(itemDefinition: ItemDefinition): Tool?
	local toolAssetName = itemDefinition.toolAssetName
	if toolAssetName == nil then
		return nil
	end

	local candidate = toolsFolder:FindFirstChild(toolAssetName)
	if candidate == nil then
		warn(string.format("[ToolSyncService] Missing tool asset Tools/%s", toolAssetName))
		return nil
	end

	if not candidate:IsA("Tool") then
		warn(string.format("[ToolSyncService] Tools/%s exists but is not a Tool", toolAssetName))
		return nil
	end

	return candidate
end

local function equipSystemTool(player: Player, itemId: ItemId)
	local itemDefinition = ItemCatalog.getItemDefinition(itemId)
	if itemDefinition.kind ~= "Tool" then
		return
	end

	local toolTemplate = getToolTemplate(itemDefinition)
	if toolTemplate == nil then
		return
	end

	destroySystemToolInstances(player, itemId)

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack == nil then
		backpack = player:WaitForChild("Backpack") :: Backpack
	end

	local toolClone = toolTemplate:Clone()
	toolClone:SetAttribute(SYSTEM_TOOL_ITEM_ID_ATTRIBUTE, itemId)
	toolClone.Parent = backpack

	local character = player.Character
	if character == nil then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end

	humanoid:EquipTool(toolClone)
end

local function syncPlayerToolState(player: Player)
	local equippedItemId = InventoryService.getEquippedItemId(player)
	destroySystemToolInstances(player, "Scythe")

	if equippedItemId ~= "Scythe" then
		return
	end

	equipSystemTool(player, "Scythe")
end

local ToolSyncService = {}

function ToolSyncService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	InventoryService.observeEquippedItemChanged(function(player: Player, _itemId: ItemId?)
		syncPlayerToolState(player)
	end)

	local function connectPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			syncPlayerToolState(player)
		end)

		syncPlayerToolState(player)
	end

	Players.PlayerAdded:Connect(connectPlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		connectPlayer(player)
	end
end

return table.freeze(ToolSyncService)

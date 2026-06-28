--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local limitedItemsFolder = sharedFolder:WaitForChild("LimitedItems") :: Folder
local notificationsFolder = sharedFolder:WaitForChild("Notifications") :: Folder

local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local LimitedItemCatalog = require(limitedItemsFolder:WaitForChild("LimitedItemCatalog") :: ModuleScript)
local NotificationConfig = require(notificationsFolder:WaitForChild("NotificationConfig") :: ModuleScript)
local InventoryService = require(script.Parent.Parent.Inventory.InventoryService)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)
local LimitedItemStockService = require(script.Parent.Parent.LimitedItems.LimitedItemStockService)
local Remotes = require(script.Parent.Parent.Networking.Remotes)

local LimitedItemPurchaseService = {}

local function sendPurchaseNotification(player: Player, displayName: string)
	Remotes.getNotificationRemotes().notificationReceived:FireClient(player, {
		id = HttpService:GenerateGUID(false),
		kind = "Toast",
		text = string.format("Successfully purchased %s!", displayName),
		effect = "Instant",
		durationSeconds = NotificationConfig.toastDurationSeconds,
		variant = "Success",
	})
end

function LimitedItemPurchaseService.grantDeveloperProductPurchase(
	player: Player,
	developerProductId: number,
	purchaseId: string
): boolean?
	local definition = LimitedItemCatalog.getDefinitionByDeveloperProductId(developerProductId)
	if definition == nil then
		return nil
	end

	if purchaseId == "" then
		warn("[LimitedItemPurchaseService] Limited item receipt was missing PurchaseId.")
		return false
	end

	local claimResult = LimitedItemStockService.claimPurchase(player, definition.itemId, purchaseId)
	if not claimResult.success then
		warn(string.format(
			"[LimitedItemPurchaseService] Failed to claim %s for %s: %s",
			definition.itemId,
			player.Name,
			claimResult.status
		))
		return false
	end

	PlayerDataService.markDeveloperProductPurchaseProcessed(player, purchaseId)
	InventoryService.addItem(player, definition.itemId, 1)
	sendPurchaseNotification(player, ItemCatalog.getItemDefinition(definition.itemId).displayName)
	Remotes.getLimitedItemRemotes().limitedItemsSnapshotUpdated:FireAllClients(LimitedItemStockService.getSnapshot(true))
	return true
end

return table.freeze(LimitedItemPurchaseService)

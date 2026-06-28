--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)
local RobuxSpentLeaderboardService = require(script.Parent.Parent.Leaderboards.RobuxSpentLeaderboardService)
local LimitedItemPurchaseService = require(script.Parent.LimitedItemPurchaseService)
local RobuxStoreService = require(script.Parent.RobuxStoreService)
local ShopService = require(script.Parent.Parent.Shops.ShopService)

type ReceiptInfo = {
	PlayerId: number,
	ProductId: number,
	PurchaseId: string,
	CurrencySpent: number?,
}

local hasStarted = false
local ShopDeveloperProductReceiptService = {}

local function recordRobuxSpent(player: Player, receiptInfo: ReceiptInfo)
	local currencySpent = receiptInfo.CurrencySpent
	if currencySpent == nil or currencySpent <= 0 then
		return
	end

	local success, result = pcall(function()
		RobuxSpentLeaderboardService.recordRobuxSpent(player, currencySpent)
	end)
	if not success then
		warn(string.format("[ShopDeveloperProductReceiptService] Failed to record Robux spent: %s", tostring(result)))
	end
end

local function processReceipt(receiptInfo: ReceiptInfo): Enum.ProductPurchaseDecision
	local purchaseId = receiptInfo.PurchaseId
	if purchaseId == "" then
		warn("[ShopDeveloperProductReceiptService] Receipt was missing PurchaseId.")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if PlayerDataService.hasProcessedDeveloperProductPurchase(player, purchaseId) then
		if PlayerDataService.saveNow(player) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local limitedItemGrantResult = LimitedItemPurchaseService.grantDeveloperProductPurchase(
		player,
		receiptInfo.ProductId,
		purchaseId
	)
	local didGrantLimitedItem = limitedItemGrantResult == true
	if limitedItemGrantResult == false then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	elseif not didGrantLimitedItem then
		if not RobuxStoreService.grantDeveloperProductPurchase(player, receiptInfo.ProductId)
			and not ShopService.grantDeveloperProductPurchase(player, receiptInfo.ProductId)
		then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end

	PlayerDataService.markDeveloperProductPurchaseProcessed(player, purchaseId)
	if not PlayerDataService.saveNow(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	recordRobuxSpent(player, receiptInfo)
	if not didGrantLimitedItem then
		ShopService.notifyDeveloperProductPurchaseCompleted(player, receiptInfo.ProductId)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopDeveloperProductReceiptService.start()
	if hasStarted then
		return
	end

	hasStarted = true
	MarketplaceService.ProcessReceipt = processReceipt
end

return table.freeze(ShopDeveloperProductReceiptService)

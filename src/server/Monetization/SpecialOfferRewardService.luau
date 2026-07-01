--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local monetizationFolder = sharedFolder:WaitForChild("Monetization") :: Folder

local GamePassConfig = require(monetizationFolder:WaitForChild("GamePassConfig") :: ModuleScript)
local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local SpecialOfferConfig = require(monetizationFolder:WaitForChild("SpecialOfferConfig") :: ModuleScript)
local GamePassOwnershipService = require(script.Parent.GamePassOwnershipService)
local InventoryService = require(script.Parent.Parent.Inventory.InventoryService)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)

type ItemId = InventoryTypes.ItemId
type SpecialOfferDefinition = SpecialOfferConfig.SpecialOfferDefinition

local hasStarted = false
local activeGrantPlayers: { [Player]: boolean } = {}

local function areRewardItemsValid(offerDefinition: SpecialOfferDefinition): boolean
	for _, rewardItem in ipairs(offerDefinition.rewardItems) do
		if rewardItem.quantity <= 0 or rewardItem.quantity ~= math.floor(rewardItem.quantity) then
			warn(string.format("[SpecialOfferRewardService] Invalid reward quantity for %s.", rewardItem.itemId))
			return false
		end

		if not ItemCatalog.hasItemDefinition(rewardItem.itemId) then
			warn(string.format("[SpecialOfferRewardService] Unknown reward item %s.", rewardItem.itemId))
			return false
		end
	end

	return true
end

local function grantRewardItems(player: Player, offerDefinition: SpecialOfferDefinition)
	for _, rewardItem in ipairs(offerDefinition.rewardItems) do
		InventoryService.addItem(player, rewardItem.itemId :: ItemId, rewardItem.quantity)
	end
end

local function tryGrantSpecialOffer(player: Player, skipOwnershipCheck: boolean): boolean
	if player.Parent ~= Players then
		return false
	end

	local offerDefinition = SpecialOfferConfig.getDefinition()
	if PlayerDataService.hasClaimedOneTimeReward(player, offerDefinition.oneTimeRewardId) then
		return false
	end

	local gamePassDefinition = GamePassConfig.getSpecialOfferDefinition()
	if not skipOwnershipCheck and not GamePassOwnershipService.playerOwnsGamePass(player, gamePassDefinition.gamePassId) then
		return false
	end

	if activeGrantPlayers[player] == true then
		return false
	end

	activeGrantPlayers[player] = true
	local success, didGrant = pcall(function(): boolean
		if PlayerDataService.hasClaimedOneTimeReward(player, offerDefinition.oneTimeRewardId) then
			return false
		end

		if not areRewardItemsValid(offerDefinition) then
			return false
		end

		grantRewardItems(player, offerDefinition)
		local didMarkClaimed = PlayerDataService.markOneTimeRewardClaimed(player, offerDefinition.oneTimeRewardId)
		if didMarkClaimed and not PlayerDataService.saveNow(player) then
			warn(string.format("[SpecialOfferRewardService] Failed to save Special Offer reward for %s.", player.Name))
		end

		return didMarkClaimed
	end)

	activeGrantPlayers[player] = nil
	if not success then
		warn(string.format("[SpecialOfferRewardService] Failed to grant Special Offer reward for %s: %s", player.Name, tostring(didGrant)))
		return false
	end

	return didGrant
end

local function handlePlayerAdded(player: Player)
	task.spawn(function()
		tryGrantSpecialOffer(player, false)
	end)
end

local SpecialOfferRewardService = {}

function SpecialOfferRewardService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	Players.PlayerAdded:Connect(handlePlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		activeGrantPlayers[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
		local gamePassDefinition = GamePassConfig.getSpecialOfferDefinition()
		if gamePassId == gamePassDefinition.gamePassId and wasPurchased then
			tryGrantSpecialOffer(player, true)
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		handlePlayerAdded(player)
	end
end

return table.freeze(SpecialOfferRewardService)

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local playtimeRewardsFolder = sharedFolder:WaitForChild("PlaytimeRewards") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local PlaytimeRewardsTypes = require(playtimeRewardsFolder:WaitForChild("PlaytimeRewardsTypes") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)

type DailyRewardDefinition = PlaytimeRewardsTypes.DailyRewardDefinition
type ItemId = InventoryTypes.ItemId
type ResourceId = ResourceTypes.ResourceId

local DAILY_REWARD_COOLDOWN_SECONDS = 24 * 60 * 60
local LOW_CASH_IMAGE_ASSET_ID = "rbxassetid://135766925654117"
local HIGH_CASH_IMAGE_ASSET_ID = "rbxassetid://129889147058281"
local APPLE_IMAGE_ASSET_ID = "rbxassetid://139993068118457"
local CIDER_IMAGE_ASSET_ID = "rbxassetid://89438227381661"

local function cash(amount: number, imageAssetId: string): PlaytimeRewardsTypes.CashRewardEntry
	return table.freeze({
		kind = "Cash",
		amount = amount,
		imageAssetId = imageAssetId,
	})
end

local function resource(resourceId: ResourceId, amount: number, imageAssetId: string?): PlaytimeRewardsTypes.ResourceRewardEntry
	return table.freeze({
		kind = "Resource",
		resourceId = resourceId,
		amount = amount,
		imageAssetId = imageAssetId or "",
	})
end

local function item(itemId: ItemId, amount: number): PlaytimeRewardsTypes.ItemRewardEntry
	return table.freeze({
		kind = "Item",
		itemId = itemId,
		amount = amount,
		imageAssetId = ItemCatalog.getItemDefinition(itemId).imageAssetId,
	})
end

local rewardDefinitions: { DailyRewardDefinition } = table.freeze({
	table.freeze({
		rewardIndex = 1,
		displayName = "Day 1",
		rewards = table.freeze({ cash(500, LOW_CASH_IMAGE_ASSET_ID) }),
	}),
	table.freeze({
		rewardIndex = 2,
		displayName = "Day 2",
		rewards = table.freeze({ resource("Apple", 5000, APPLE_IMAGE_ASSET_ID) }),
	}),
	table.freeze({
		rewardIndex = 3,
		displayName = "Day 3",
		rewards = table.freeze({ item("SapphireTree", 1) }),
	}),
	table.freeze({
		rewardIndex = 4,
		displayName = "Day 4",
		rewards = table.freeze({ resource("Cider", 10000, CIDER_IMAGE_ASSET_ID) }),
	}),
	table.freeze({
		rewardIndex = 5,
		displayName = "Day 5",
		rewards = table.freeze({ item("AdvancedCiderMill", 1) }),
	}),
	table.freeze({
		rewardIndex = 6,
		displayName = "Day 6",
		rewards = table.freeze({ item("DiamondTree", 1) }),
	}),
	table.freeze({
		rewardIndex = 7,
		displayName = "Day 7",
		rewards = table.freeze({ cash(10000000, HIGH_CASH_IMAGE_ASSET_ID) }),
	}),
})

local rewardDefinitionsByRewardIndex: { [number]: DailyRewardDefinition } = {}
for _, definition in ipairs(rewardDefinitions) do
	rewardDefinitionsByRewardIndex[definition.rewardIndex] = definition
end

local DailyRewardsConfig = {}

function DailyRewardsConfig.getCooldownSeconds(): number
	return DAILY_REWARD_COOLDOWN_SECONDS
end

function DailyRewardsConfig.getCycleLength(): number
	return #rewardDefinitions
end

function DailyRewardsConfig.getRewardDefinitions(): { DailyRewardDefinition }
	return rewardDefinitions
end

function DailyRewardsConfig.getRewardDefinition(rewardIndex: number): DailyRewardDefinition
	local definition = rewardDefinitionsByRewardIndex[rewardIndex]
	assert(definition ~= nil, string.format("Daily reward %d is not configured", rewardIndex))
	return definition
end

function DailyRewardsConfig.isRewardIndexInRange(rewardIndex: number): boolean
	return rewardIndex >= 1 and rewardIndex <= #rewardDefinitions and rewardIndex == math.floor(rewardIndex)
end

function DailyRewardsConfig.sanitizeRewardIndex(rewardIndex: unknown): number
	if type(rewardIndex) ~= "number" or not DailyRewardsConfig.isRewardIndexInRange(rewardIndex) then
		return 1
	end

	return rewardIndex
end

function DailyRewardsConfig.getNextRewardIndex(rewardIndex: number): number
	local sanitizedRewardIndex = DailyRewardsConfig.sanitizeRewardIndex(rewardIndex)
	if sanitizedRewardIndex >= #rewardDefinitions then
		return 1
	end

	return sanitizedRewardIndex + 1
end

return table.freeze(DailyRewardsConfig)

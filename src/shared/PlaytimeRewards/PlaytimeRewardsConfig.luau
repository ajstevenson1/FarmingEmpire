--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local playtimeRewardsFolder = sharedFolder:WaitForChild("PlaytimeRewards") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local PlaytimeRewardsTypes = require(playtimeRewardsFolder:WaitForChild("PlaytimeRewardsTypes") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)

type ItemId = InventoryTypes.ItemId
type PlaytimeRewardDefinition = PlaytimeRewardsTypes.PlaytimeRewardDefinition
type ResourceId = ResourceTypes.ResourceId

local function cash(amount: number): PlaytimeRewardsTypes.CashRewardEntry
	return table.freeze({
		kind = "Cash",
		amount = amount,
		imageAssetId = "",
	})
end

local function resource(resourceId: ResourceId, amount: number): PlaytimeRewardsTypes.ResourceRewardEntry
	return table.freeze({
		kind = "Resource",
		resourceId = resourceId,
		amount = amount,
		imageAssetId = "",
	})
end

local function item(itemId: ItemId, amount: number): PlaytimeRewardsTypes.ItemRewardEntry
	return table.freeze({
		kind = "Item",
		itemId = itemId,
		amount = amount,
		imageAssetId = "",
	})
end

local rewardDefinitions: { PlaytimeRewardDefinition } = table.freeze({
	table.freeze({
		rewardIndex = 1,
		displayName = "Reward 1",
		requiredPlaytimeSeconds = 5 * 60,
		rewards = table.freeze({ cash(100) }),
	}),
	table.freeze({
		rewardIndex = 2,
		displayName = "Reward 2",
		requiredPlaytimeSeconds = 10 * 60,
		rewards = table.freeze({ resource("Apple", 25) }),
	}),
	table.freeze({
		rewardIndex = 3,
		displayName = "Reward 3",
		requiredPlaytimeSeconds = 15 * 60,
		rewards = table.freeze({ item("OakTree", 1) }),
	}),
	table.freeze({
		rewardIndex = 4,
		displayName = "Reward 4",
		requiredPlaytimeSeconds = 20 * 60,
		rewards = table.freeze({ cash(150) }),
	}),
	table.freeze({
		rewardIndex = 5,
		displayName = "Reward 5",
		requiredPlaytimeSeconds = 30 * 60,
		rewards = table.freeze({ resource("Cider", 20) }),
	}),
	table.freeze({
		rewardIndex = 6,
		displayName = "Reward 6",
		requiredPlaytimeSeconds = 45 * 60,
		rewards = table.freeze({ item("OakTree", 2) }),
	}),
	table.freeze({
		rewardIndex = 7,
		displayName = "Reward 7",
		requiredPlaytimeSeconds = 60 * 60,
		rewards = table.freeze({ item("BirchTree", 1), cash(300) }),
	}),
	table.freeze({
		rewardIndex = 8,
		displayName = "Reward 8",
		requiredPlaytimeSeconds = 75 * 60,
		rewards = table.freeze({ resource("Apple", 75) }),
	}),
	table.freeze({
		rewardIndex = 9,
		displayName = "Reward 9",
		requiredPlaytimeSeconds = 90 * 60,
		rewards = table.freeze({ cash(500) }),
	}),
	table.freeze({
		rewardIndex = 10,
		displayName = "Reward 10",
		requiredPlaytimeSeconds = 120 * 60,
		rewards = table.freeze({ resource("Cider", 50) }),
	}),
	table.freeze({
		rewardIndex = 11,
		displayName = "Reward 11",
		requiredPlaytimeSeconds = 150 * 60,
		rewards = table.freeze({ item("BirchTree", 2) }),
	}),
	table.freeze({
		rewardIndex = 12,
		displayName = "Reward 12",
		requiredPlaytimeSeconds = 180 * 60,
		rewards = table.freeze({ item("BirchTree", 3), cash(1000) }),
	}),
})

local rewardDefinitionsByRewardIndex: { [number]: PlaytimeRewardDefinition } = {}
for _, definition in ipairs(rewardDefinitions) do
	rewardDefinitionsByRewardIndex[definition.rewardIndex] = definition
end

local PlaytimeRewardsConfig = {}

function PlaytimeRewardsConfig.getCycleLength(): number
	return #rewardDefinitions
end

function PlaytimeRewardsConfig.getRewardDefinitions(): { PlaytimeRewardDefinition }
	return rewardDefinitions
end

function PlaytimeRewardsConfig.getRewardDefinition(rewardIndex: number): PlaytimeRewardDefinition
	local definition = rewardDefinitionsByRewardIndex[rewardIndex]
	assert(definition ~= nil, string.format("Playtime reward %d is not configured", rewardIndex))
	return definition
end

function PlaytimeRewardsConfig.isRewardIndexInRange(rewardIndex: number): boolean
	return rewardIndex >= 1 and rewardIndex <= #rewardDefinitions and rewardIndex == math.floor(rewardIndex)
end

function PlaytimeRewardsConfig.sanitizeRewardIndex(rewardIndex: unknown): number
	if type(rewardIndex) ~= "number" or not PlaytimeRewardsConfig.isRewardIndexInRange(rewardIndex) then
		return 1
	end

	return rewardIndex
end

function PlaytimeRewardsConfig.getNextRewardIndex(rewardIndex: number): number
	local sanitizedRewardIndex = PlaytimeRewardsConfig.sanitizeRewardIndex(rewardIndex)
	if sanitizedRewardIndex >= #rewardDefinitions then
		return 1
	end

	return sanitizedRewardIndex + 1
end

return table.freeze(PlaytimeRewardsConfig)

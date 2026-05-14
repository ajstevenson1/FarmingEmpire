--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local playtimeRewardsFolder = sharedFolder:WaitForChild("PlaytimeRewards") :: Folder

local PlaytimeRewardsTypes = require(playtimeRewardsFolder:WaitForChild("PlaytimeRewardsTypes") :: ModuleScript)

type PlaytimeRewardDefinition = PlaytimeRewardsTypes.PlaytimeRewardDefinition

local rewardDefinitions: { PlaytimeRewardDefinition } = table.freeze({
	table.freeze({
		rewardIndex = 1,
		displayName = "Reward 1",
		requiredPlaytimeSeconds = 0,
		rewards = table.freeze({
			table.freeze({
				kind = "Cash",
				amount = 100,
			}),
		}),
	}),
	table.freeze({
		rewardIndex = 2,
		displayName = "Reward 2",
		requiredPlaytimeSeconds = 10 * 60,
		rewards = table.freeze({
			table.freeze({
				kind = "Resource",
				resourceId = "Apple",
				amount = 25,
			}),
		}),
	}),
	table.freeze({
		rewardIndex = 3,
		displayName = "Reward 3",
		requiredPlaytimeSeconds = 20 * 60,
		rewards = table.freeze({
			table.freeze({
				kind = "Item",
				itemId = "OakTree",
				amount = 1,
			}),
		}),
	}),
	table.freeze({
		rewardIndex = 4,
		displayName = "Reward 4",
		requiredPlaytimeSeconds = 30 * 60,
		rewards = table.freeze({
			table.freeze({
				kind = "Cash",
				amount = 150,
			}),
		}),
	}),
	table.freeze({
		rewardIndex = 5,
		displayName = "Reward 5",
		requiredPlaytimeSeconds = 40 * 60,
		rewards = table.freeze({
			table.freeze({
				kind = "Resource",
				resourceId = "Cider",
				amount = 20,
			}),
		}),
	}),
	table.freeze({
		rewardIndex = 6,
		displayName = "Reward 6",
		requiredPlaytimeSeconds = 50 * 60,
		rewards = table.freeze({
			table.freeze({
				kind = "Item",
				itemId = "OakTree",
				amount = 2,
			}),
		}),
	}),
	table.freeze({
		rewardIndex = 7,
		displayName = "Reward 7",
		requiredPlaytimeSeconds = 60 * 60,
		rewards = table.freeze({
			table.freeze({
				kind = "Item",
				itemId = "BirchTree",
				amount = 1,
			}),
			table.freeze({
				kind = "Cash",
				amount = 300,
			}),
		}),
	}),
})

local rewardDefinitionsByRewardIndex: { [number]: PlaytimeRewardDefinition } = {
	[1] = rewardDefinitions[1],
	[2] = rewardDefinitions[2],
	[3] = rewardDefinitions[3],
	[4] = rewardDefinitions[4],
	[5] = rewardDefinitions[5],
	[6] = rewardDefinitions[6],
	[7] = rewardDefinitions[7],
}

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

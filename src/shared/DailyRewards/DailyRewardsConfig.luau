--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local dailyRewardsFolder = sharedFolder:WaitForChild("DailyRewards") :: Folder

local DailyRewardsTypes = require(dailyRewardsFolder:WaitForChild("DailyRewardsTypes") :: ModuleScript)

type DailyRewardDefinition = DailyRewardsTypes.DailyRewardDefinition

local rewardDefinitions: { DailyRewardDefinition } = table.freeze({
	table.freeze({
		dayIndex = 1,
		displayName = "Day 1",
		rewards = table.freeze({
			table.freeze({
				kind = "Cash",
				amount = 100,
			}),
		}),
	}),
	table.freeze({
		dayIndex = 2,
		displayName = "Day 2",
		rewards = table.freeze({
			table.freeze({
				kind = "Resource",
				resourceId = "Apple",
				amount = 25,
			}),
		}),
	}),
	table.freeze({
		dayIndex = 3,
		displayName = "Day 3",
		rewards = table.freeze({
			table.freeze({
				kind = "Item",
				itemId = "BasicTree",
				amount = 1,
			}),
		}),
	}),
	table.freeze({
		dayIndex = 4,
		displayName = "Day 4",
		rewards = table.freeze({
			table.freeze({
				kind = "Cash",
				amount = 150,
			}),
		}),
	}),
	table.freeze({
		dayIndex = 5,
		displayName = "Day 5",
		rewards = table.freeze({
			table.freeze({
				kind = "Resource",
				resourceId = "Cider",
				amount = 20,
			}),
		}),
	}),
	table.freeze({
		dayIndex = 6,
		displayName = "Day 6",
		rewards = table.freeze({
			table.freeze({
				kind = "Item",
				itemId = "BasicTree",
				amount = 2,
			}),
		}),
	}),
	table.freeze({
		dayIndex = 7,
		displayName = "Day 7",
		rewards = table.freeze({
			table.freeze({
				kind = "Item",
				itemId = "RubyAppleTree",
				amount = 1,
			}),
			table.freeze({
				kind = "Cash",
				amount = 300,
			}),
		}),
	}),
})

local rewardDefinitionsByDayIndex: { [number]: DailyRewardDefinition } = {
	[1] = rewardDefinitions[1],
	[2] = rewardDefinitions[2],
	[3] = rewardDefinitions[3],
	[4] = rewardDefinitions[4],
	[5] = rewardDefinitions[5],
	[6] = rewardDefinitions[6],
	[7] = rewardDefinitions[7],
}

local DailyRewardsConfig = {}

DailyRewardsConfig.periodDurationSeconds = 24 * 60 * 60

function DailyRewardsConfig.getCycleLength(): number
	return #rewardDefinitions
end

function DailyRewardsConfig.getRewardDefinitions(): { DailyRewardDefinition }
	return rewardDefinitions
end

function DailyRewardsConfig.getRewardDefinition(dayIndex: number): DailyRewardDefinition
	local definition = rewardDefinitionsByDayIndex[dayIndex]
	assert(definition ~= nil, string.format("Daily reward day %d is not configured", dayIndex))
	return definition
end

function DailyRewardsConfig.isDayIndexInRange(dayIndex: number): boolean
	return dayIndex >= 1 and dayIndex <= #rewardDefinitions and dayIndex == math.floor(dayIndex)
end

function DailyRewardsConfig.sanitizeDayIndex(dayIndex: unknown): number
	if type(dayIndex) ~= "number" or not DailyRewardsConfig.isDayIndexInRange(dayIndex) then
		return 1
	end

	return dayIndex
end

function DailyRewardsConfig.getNextDayIndex(dayIndex: number): number
	local sanitizedDayIndex = DailyRewardsConfig.sanitizeDayIndex(dayIndex)
	if sanitizedDayIndex >= #rewardDefinitions then
		return 1
	end

	return sanitizedDayIndex + 1
end

function DailyRewardsConfig.getPeriodIdAtTime(unixTimestamp: number): number
	if unixTimestamp ~= unixTimestamp or unixTimestamp == math.huge or unixTimestamp == -math.huge then
		return 0
	end

	return math.max(0, math.floor(unixTimestamp / DailyRewardsConfig.periodDurationSeconds))
end

function DailyRewardsConfig.getNextPeriodStartTime(periodId: number): number
	local sanitizedPeriodId = math.max(0, math.floor(periodId))
	return (sanitizedPeriodId + 1) * DailyRewardsConfig.periodDurationSeconds
end

return table.freeze(DailyRewardsConfig)

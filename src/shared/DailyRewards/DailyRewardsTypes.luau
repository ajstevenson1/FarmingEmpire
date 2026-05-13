--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)

type ItemId = InventoryTypes.ItemId
type ResourceId = ResourceTypes.ResourceId

export type PlayerDailyRewardsData = {
	lastClaimPeriodId: number?,
	nextDayIndex: number,
	totalClaims: number,
}

export type CashRewardEntry = {
	kind: "Cash",
	amount: number,
}

export type ResourceRewardEntry = {
	kind: "Resource",
	resourceId: ResourceId,
	amount: number,
}

export type ItemRewardEntry = {
	kind: "Item",
	itemId: ItemId,
	amount: number,
}

export type DailyRewardEntry = CashRewardEntry | ResourceRewardEntry | ItemRewardEntry

export type DailyRewardDefinition = {
	dayIndex: number,
	displayName: string,
	rewards: { DailyRewardEntry },
}

export type DailyRewardDayState = "Claimed" | "Claimable" | "Locked"

export type DailyRewardDaySnapshot = {
	dayIndex: number,
	displayName: string,
	rewards: { DailyRewardEntry },
	state: DailyRewardDayState,
}

export type DailyRewardsSnapshot = {
	canClaim: boolean,
	claimableDayIndex: number?,
	claimedTodayDayIndex: number?,
	currentPeriodId: number,
	cycleLength: number,
	days: { DailyRewardDaySnapshot },
	lastClaimPeriodId: number?,
	nextClaimTime: number,
	secondsUntilNextClaim: number,
	totalClaims: number,
}

export type DailyRewardsClaimStatus = "Claimed" | "AlreadyClaimed"

export type DailyRewardsClaimResult = {
	success: boolean,
	status: DailyRewardsClaimStatus,
	snapshot: DailyRewardsSnapshot,
	claimedDayIndex: number?,
	grantedRewards: { DailyRewardEntry }?,
}

return {}

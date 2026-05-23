--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)

type ItemId = InventoryTypes.ItemId
type ResourceId = ResourceTypes.ResourceId

export type PlayerPlaytimeRewardsData = {
	accumulatedPlaytimeSeconds: number,
	claimedRewardIndexes: { [number]: boolean },
	totalClaims: number,
}

export type PlayerDailyRewardsData = {
	claimedRewardIndexes: { [number]: boolean },
	lastClaimUnixTime: number,
	nextRewardIndex: number,
	totalClaims: number,
}

export type CashRewardEntry = {
	kind: "Cash",
	amount: number,
	imageAssetId: string?,
}

export type ResourceRewardEntry = {
	kind: "Resource",
	resourceId: ResourceId,
	amount: number,
	imageAssetId: string?,
}

export type ItemRewardEntry = {
	kind: "Item",
	itemId: ItemId,
	amount: number,
	imageAssetId: string?,
}

export type PlaytimeRewardEntry = CashRewardEntry | ResourceRewardEntry | ItemRewardEntry

export type PlaytimeRewardDefinition = {
	rewardIndex: number,
	displayName: string,
	requiredPlaytimeSeconds: number,
	rewards: { PlaytimeRewardEntry },
}

export type PlaytimeRewardState = "Claimed" | "Claimable" | "Locked"

export type PlaytimeRewardSnapshot = {
	rewardIndex: number,
	displayName: string,
	requiredPlaytimeSeconds: number,
	rewards: { PlaytimeRewardEntry },
	secondsRemaining: number,
	state: PlaytimeRewardState,
}

export type PlaytimeRewardsSnapshot = {
	canClaim: boolean,
	claimableRewardIndex: number?,
	currentPlaytimeSeconds: number,
	cycleLength: number,
	rewardSnapshots: { PlaytimeRewardSnapshot },
	nextRewardSecondsRemaining: number?,
	snapshotServerTime: number,
	totalClaims: number,
}

export type DailyRewardDefinition = {
	rewardIndex: number,
	displayName: string,
	rewards: { PlaytimeRewardEntry },
}

export type DailyRewardSnapshot = {
	rewardIndex: number,
	displayName: string,
	rewards: { PlaytimeRewardEntry },
	secondsRemaining: number,
	state: PlaytimeRewardState,
}

export type DailyRewardsSnapshot = {
	canClaim: boolean,
	claimableRewardIndex: number?,
	cycleLength: number,
	nextRewardSecondsRemaining: number?,
	rewardSnapshots: { DailyRewardSnapshot },
	snapshotServerTime: number,
	totalClaims: number,
}

export type RewardsSnapshot = {
	playtime: PlaytimeRewardsSnapshot,
	daily: DailyRewardsSnapshot,
}

export type RewardCategory = "Playtime" | "Daily"

export type PlaytimeRewardsClaimStatus = "Claimed" | "AlreadyClaimed"

export type PlaytimeRewardsClaimResult = {
	success: boolean,
	status: PlaytimeRewardsClaimStatus,
	snapshot: RewardsSnapshot,
	category: RewardCategory?,
	claimedRewardIndex: number?,
	grantedRewards: { PlaytimeRewardEntry }?,
}

return {}

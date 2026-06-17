--!strict

export type RobuxStoreCategoryId = "CashPacks"

export type RobuxStoreProductId =
	"Cash25K"
	| "Cash150K"
	| "Cash800K"
	| "Cash10M"

export type RobuxStoreRewardType = "Cash"

export type RobuxStoreProductDefinition = {
	id: RobuxStoreProductId,
	categoryId: RobuxStoreCategoryId,
	displayName: string,
	rewardType: RobuxStoreRewardType,
	rewardAmount: number,
	developerProductId: number,
	sortOrder: number,
	isBestValue: boolean,
}

return {}

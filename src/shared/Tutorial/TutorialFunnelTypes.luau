--!strict

local TutorialFunnelTypes = {}

export type TutorialCompletionSource =
	"TapContinue"
	| "AutoContinue"
	| "Proximity"
	| "ShopOpened"
	| "ShopPurchase"
	| "BuildingPlaced"
	| "ItemEquipped"
	| "ResourceAdded"
	| "CiderSold"
	| "AlreadySatisfied"

export type TutorialFunnelStepData = {
	stepId: number,
	reachedAtUnix: number,
	completedAtUnix: number?,
	completionSource: TutorialCompletionSource?,
}

export type TutorialFunnelData = {
	version: number,
	startedAtUnix: number,
	completedAtUnix: number?,
	skippedAtUnix: number?,
	skippedAtStepId: number?,
	steps: { TutorialFunnelStepData },
}

return table.freeze(TutorialFunnelTypes)

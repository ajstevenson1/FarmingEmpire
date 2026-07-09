--!strict

export type TutorialStepId = number
export type TutorialVariant = "ShopV1" | "StarterKitV2"

export type TutorialTarget =
	"None"
	| "ShopTeleportButton"
	| "PlotTeleportButton"
	| "SellTeleportButton"
	| "OakTreeBuyButton"
	| "CiderMillBuyButton"
	| "CiderSellButton"
	| "OakTreeHotbar"
	| "CiderMillHotbar"
	| "ScytheHotbar"

export type TutorialBeamTarget = "None" | "OakTree" | "CiderMill" | "TreesShop" | "MillsShop" | "SellStand"

export type TutorialStepDefinition = {
	id: TutorialStepId,
	text: string,
	analyticsName: string,
	analyticsStepId: number?,
	tapToContinue: boolean,
	spotlightTarget: TutorialTarget,
	beamTarget: TutorialBeamTarget,
	autoDismissSeconds: number?,
	autoContinueDelaySeconds: number?,
}

export type TutorialData = {
	stepIndex: number,
	completed: boolean,
	variant: TutorialVariant?,
	starterKitGranted: boolean,
}

export type TutorialStepPayload = {
	step: TutorialStepDefinition?,
	data: TutorialData,
}

return {}

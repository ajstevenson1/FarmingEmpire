--!strict

export type TutorialStepId = number

export type TutorialTarget =
	"None"
	| "ShopTeleportButton"
	| "PlotTeleportButton"
	| "SellTeleportButton"
	| "OakTreeBuyButton"
	| "CiderMillBuyButton"
	| "CiderSellButton"
	| "OakTreeHotbar"
	| "ScytheHotbar"

export type TutorialBeamTarget = "None" | "OakTree" | "CiderMill" | "TreesShop" | "MillsShop" | "SellStand"

export type TutorialStepDefinition = {
	id: TutorialStepId,
	text: string,
	analyticsName: string,
	tapToContinue: boolean,
	spotlightTarget: TutorialTarget,
	beamTarget: TutorialBeamTarget,
	autoDismissSeconds: number?,
	autoContinueDelaySeconds: number?,
}

export type TutorialData = {
	stepIndex: number,
	completed: boolean,
}

export type TutorialStepPayload = {
	step: TutorialStepDefinition?,
	data: TutorialData,
}

return {}

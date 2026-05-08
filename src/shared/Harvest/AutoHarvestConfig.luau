--!strict

export type AutoHarvestConfig = {
	approachDistanceStuds: number,
	serverHarvestDistanceStuds: number,
	harvestIntervalSeconds: number,
	targetScanIntervalSeconds: number,
	moveTimeoutSeconds: number,
	noTargetRetrySeconds: number,
	recentlyVisitedSeconds: number,
	minRouteTravelDistanceStuds: number,
	recentClusterRadiusStuds: number,
	maxAutoHarvestPartsPerSwing: number,
	storedAmountScoreWeight: number,
	storageCapScoreWeight: number,
	distanceScorePenalty: number,
	recentClusterScorePenalty: number,
	closeTargetScorePenalty: number,
	waitingScoreWeight: number,
	maxWaitingScoreBonus: number,
	neverVisitedScoreBonus: number,
	fullStoredAmountScoreWeight: number,
}

local AutoHarvestConfig: AutoHarvestConfig = table.freeze({
	approachDistanceStuds = 4.5,
	serverHarvestDistanceStuds = 8,
	harvestIntervalSeconds = 1.15,
	targetScanIntervalSeconds = 0.75,
	moveTimeoutSeconds = 8,
	noTargetRetrySeconds = 1.25,
	recentlyVisitedSeconds = 4,
	minRouteTravelDistanceStuds = 8,
	recentClusterRadiusStuds = 9,
	maxAutoHarvestPartsPerSwing = 3,
	storedAmountScoreWeight = 12,
	storageCapScoreWeight = 1.5,
	distanceScorePenalty = 0.35,
	recentClusterScorePenalty = 45,
	closeTargetScorePenalty = 18,
	waitingScoreWeight = 3,
	maxWaitingScoreBonus = 60,
	neverVisitedScoreBonus = 25,
	fullStoredAmountScoreWeight = 0.5,
})

return AutoHarvestConfig

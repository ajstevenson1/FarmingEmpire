--!strict

export type AutoHarvestConfig = {
	arrivalOverlapBoxSize: Vector3,
	arrivalOverlapDepthStuds: number,
	serverHarvestDistanceStuds: number,
	maxAutoHarvestPartsPerSwing: number,
	harvestIntervalSeconds: number,
	targetScanIntervalSeconds: number,
	moveTimeoutSeconds: number,
	noTargetRetrySeconds: number,
	recentlyVisitedSeconds: number,
	minRouteTravelDistanceStuds: number,
	recentClusterRadiusStuds: number,
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
	arrivalOverlapBoxSize = Vector3.new(5, 6, 5),
	arrivalOverlapDepthStuds = 1.75,
	serverHarvestDistanceStuds = 8,
	maxAutoHarvestPartsPerSwing = 8,
	harvestIntervalSeconds = 1.15,
	targetScanIntervalSeconds = 0.75,
	moveTimeoutSeconds = 8,
	noTargetRetrySeconds = 1.25,
	recentlyVisitedSeconds = 4,
	minRouteTravelDistanceStuds = 8,
	recentClusterRadiusStuds = 9,
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

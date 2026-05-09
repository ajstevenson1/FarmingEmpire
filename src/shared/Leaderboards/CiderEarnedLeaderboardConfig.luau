--!strict

export type CiderEarnedLeaderboardConfig = {
	workspaceModelName: string,
	displayBoardName: string,
	scrollingFrameName: string,
	orderedDataStoreName: string,
	entriesToDisplay: number,
	refreshIntervalSeconds: number,
	writeFlushIntervalSeconds: number,
}

local CiderEarnedLeaderboardConfig: CiderEarnedLeaderboardConfig = {
	workspaceModelName = "CiderEarnedLeaderboard",
	displayBoardName = "Board",
	scrollingFrameName = "ScrollingFrame",
	orderedDataStoreName = "FarmingEmpire_CiderEarnedLeaderboard_DEV",
	entriesToDisplay = 10,
	refreshIntervalSeconds = 60,
	writeFlushIntervalSeconds = 30,
}

return table.freeze(CiderEarnedLeaderboardConfig)

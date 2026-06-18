--!strict

export type RobuxSpentLeaderboardConfig = {
	workspaceModelName: string,
	displayBoardName: string,
	scrollingFrameName: string,
	orderedDataStoreName: string,
	entriesToDisplay: number,
	refreshIntervalSeconds: number,
	writeFlushIntervalSeconds: number,
}

local RobuxSpentLeaderboardConfig: RobuxSpentLeaderboardConfig = {
	workspaceModelName = "RobuxSpentLeaderboard",
	displayBoardName = "Board",
	scrollingFrameName = "ScrollingFrame",
	orderedDataStoreName = "FarmingEmpire_RobuxSpentLeaderboard_PROD",
	entriesToDisplay = 50,
	refreshIntervalSeconds = 60,
	writeFlushIntervalSeconds = 30,
}

return table.freeze(RobuxSpentLeaderboardConfig)

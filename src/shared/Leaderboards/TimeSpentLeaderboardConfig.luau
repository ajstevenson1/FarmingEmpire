--!strict

export type TimeSpentLeaderboardConfig = {
	workspaceModelName: string,
	displayBoardName: string,
	scrollingFrameName: string,
	orderedDataStoreName: string,
	entriesToDisplay: number,
	refreshIntervalSeconds: number,
	writeFlushIntervalSeconds: number,
}

local TimeSpentLeaderboardConfig: TimeSpentLeaderboardConfig = {
	workspaceModelName = "TimeSpentLeaderboard",
	displayBoardName = "Board",
	scrollingFrameName = "ScrollingFrame",
	orderedDataStoreName = "FarmingEmpire_TimeSpentLeaderboard_PROD",
	entriesToDisplay = 50,
	refreshIntervalSeconds = 60,
	writeFlushIntervalSeconds = 60,
}

return table.freeze(TimeSpentLeaderboardConfig)

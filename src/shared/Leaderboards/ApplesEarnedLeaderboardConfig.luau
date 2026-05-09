--!strict

export type ApplesEarnedLeaderboardConfig = {
	workspaceModelName: string,
	displayBoardName: string,
	scrollingFrameName: string,
	orderedDataStoreName: string,
	entriesToDisplay: number,
	refreshIntervalSeconds: number,
	writeFlushIntervalSeconds: number,
}

local ApplesEarnedLeaderboardConfig: ApplesEarnedLeaderboardConfig = {
	workspaceModelName = "ApplesEarnedLeaderboard",
	displayBoardName = "Board",
	scrollingFrameName = "ScrollingFrame",
	orderedDataStoreName = "FarmingEmpire_ApplesEarnedLeaderboard_DEV",
	entriesToDisplay = 10,
	refreshIntervalSeconds = 60,
	writeFlushIntervalSeconds = 30,
}

return table.freeze(ApplesEarnedLeaderboardConfig)

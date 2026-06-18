--!strict

export type CashLeaderboardConfig = {
	workspaceModelName: string,
	displayBoardName: string,
	scrollingFrameName: string,
	orderedDataStoreName: string,
	entriesToDisplay: number,
	refreshIntervalSeconds: number,
	writeFlushIntervalSeconds: number,
}

local CashLeaderboardConfig: CashLeaderboardConfig = {
	workspaceModelName = "CashLeaderboard",
	displayBoardName = "Board",
	scrollingFrameName = "ScrollingFrame",
	orderedDataStoreName = "FarmingEmpire_CashLeaderboard_PROD",
	entriesToDisplay = 50,
	refreshIntervalSeconds = 60,
	writeFlushIntervalSeconds = 30,
}

return table.freeze(CashLeaderboardConfig)

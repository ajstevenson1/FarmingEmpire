--!strict

export type CashLeaderboardEntry = {
	userId: number,
	playerName: string,
	cash: number,
}

export type TimeSpentLeaderboardEntry = {
	userId: number,
	playerName: string,
	totalSeconds: number,
}

export type NumberLeaderboardEntry = {
	userId: number,
	playerName: string,
	value: number,
}

return table.freeze({})

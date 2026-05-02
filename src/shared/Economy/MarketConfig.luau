--!strict

local MarketConfig = {
	priceChangeIntervalSeconds = 30,
	minCiderSellPrice = 4,
	maxCiderSellPrice = 8,
}

return table.freeze(MarketConfig)

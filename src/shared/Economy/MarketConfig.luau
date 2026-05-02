--!strict

local MarketConfig = {
	priceChangeIntervalSeconds = 30,
	minCiderSellPrice = 5,
	maxCiderSellPrice = 15,
}

return table.freeze(MarketConfig)

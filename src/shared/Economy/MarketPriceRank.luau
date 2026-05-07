--!strict

local MarketConfig = require(script.Parent.MarketConfig)

export type MarketPriceRankId = "Low" | "Average" | "Good" | "Insane"

export type MarketPriceRankDefinition = {
	id: MarketPriceRankId,
	displayName: string,
	sortOrder: number,
}

local RANKS: { MarketPriceRankDefinition } = table.freeze({
	table.freeze({
		id = "Low",
		displayName = "Low",
		sortOrder = 1,
	}),
	table.freeze({
		id = "Average",
		displayName = "Average",
		sortOrder = 2,
	}),
	table.freeze({
		id = "Good",
		displayName = "Good",
		sortOrder = 3,
	}),
	table.freeze({
		id = "Insane",
		displayName = "Insane",
		sortOrder = 4,
	}),
})

local function getNormalizedPrice(price: number): number
	local priceRange = MarketConfig.maxCiderSellPrice - MarketConfig.minCiderSellPrice
	if priceRange <= 0 then
		return 1
	end

	return math.clamp((price - MarketConfig.minCiderSellPrice) / priceRange, 0, 1)
end

local MarketPriceRank = {}

function MarketPriceRank.getNormalizedCiderPrice(price: number): number
	return getNormalizedPrice(price)
end

function MarketPriceRank.getCiderPriceRank(price: number): MarketPriceRankDefinition
	local normalizedPrice = getNormalizedPrice(price)
	local rankIndex = math.clamp(math.floor(normalizedPrice * #RANKS) + 1, 1, #RANKS)
	return RANKS[rankIndex]
end

function MarketPriceRank.getAllRanks(): { MarketPriceRankDefinition }
	return table.clone(RANKS)
end

return table.freeze(MarketPriceRank)

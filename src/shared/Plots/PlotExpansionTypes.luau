--!strict

export type PlotModifierId = "DoubleProduction" | "TripleProduction" | "QuintupleProduction"

export type PlotTileCoordinate = {
	row: number,
	column: number,
}

export type PlotTileDefinition = {
	row: number,
	column: number,
	price: number,
	modifierId: PlotModifierId?,
}

export type PlotTileSnapshot = {
	row: number,
	column: number,
	price: number,
	modifierId: PlotModifierId?,
	isUnlocked: boolean,
}

export type PlotExpansionSnapshot = {
	rowCount: number,
	columnCount: number,
	tileSizeStuds: number,
	starterTile: PlotTileCoordinate,
	tiles: { PlotTileSnapshot },
}

export type PlotTilePurchaseStatus =
	"Purchased" | "AlreadyUnlocked" | "InvalidTile" | "InsufficientCash" | "MissingPlot"

export type PlotTilePurchaseResult = {
	success: boolean,
	status: PlotTilePurchaseStatus,
	purchasedTile: PlotTileCoordinate?,
	snapshot: PlotExpansionSnapshot,
}

return {}

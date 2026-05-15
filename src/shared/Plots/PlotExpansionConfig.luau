--!strict

local PlotExpansionTypes = require(script.Parent.PlotExpansionTypes)

type PlotModifierId = PlotExpansionTypes.PlotModifierId
type PlotTileCoordinate = PlotExpansionTypes.PlotTileCoordinate
type PlotTileDefinition = PlotExpansionTypes.PlotTileDefinition

local TILE_SIZE_STUDS = 20
local ROW_COUNT = 4
local COLUMN_COUNT = 3

local STARTER_TILE: PlotTileCoordinate = table.freeze({
	row = 1,
	column = 2,
})

local function createTileDefinition(row: number, column: number, price: number, modifierId: PlotModifierId?): PlotTileDefinition
	return table.freeze({
		row = row,
		column = column,
		price = price,
		modifierId = modifierId,
	})
end

local tileDefinitions: { PlotTileDefinition } = table.freeze({
	createTileDefinition(1, 1, 500, nil),
	createTileDefinition(1, 2, 0, nil),
	createTileDefinition(1, 3, 500, nil),
	createTileDefinition(2, 1, 2500, nil),
	createTileDefinition(2, 2, 2500, nil),
	createTileDefinition(2, 3, 2500, nil),
	createTileDefinition(3, 1, 8500, "DoubleApple"),
	createTileDefinition(3, 2, 8500, "DoubleApple"),
	createTileDefinition(3, 3, 8500, "DoubleApple"),
	createTileDefinition(4, 1, 25000, "DoubleCider"),
	createTileDefinition(4, 2, 25000, "DoubleCider"),
	createTileDefinition(4, 3, 25000, "DoubleCider"),
})

local tileDefinitionsByKey: { [string]: PlotTileDefinition } = {}
for _, tileDefinition in ipairs(tileDefinitions) do
	tileDefinitionsByKey[string.format("%d:%d", tileDefinition.row, tileDefinition.column)] = tileDefinition
end

local PlotExpansionConfig = {}

function PlotExpansionConfig.getTileSizeStuds(): number
	return TILE_SIZE_STUDS
end

function PlotExpansionConfig.getRowCount(): number
	return ROW_COUNT
end

function PlotExpansionConfig.getColumnCount(): number
	return COLUMN_COUNT
end

function PlotExpansionConfig.getStarterTile(): PlotTileCoordinate
	return STARTER_TILE
end

function PlotExpansionConfig.getTileDefinitions(): { PlotTileDefinition }
	return tileDefinitions
end

function PlotExpansionConfig.isValidTileCoordinate(row: number, column: number): boolean
	return row >= 1 and row <= ROW_COUNT and column >= 1 and column <= COLUMN_COUNT
end

function PlotExpansionConfig.getTileDefinition(row: number, column: number): PlotTileDefinition?
	return tileDefinitionsByKey[string.format("%d:%d", row, column)]
end

return table.freeze(PlotExpansionConfig)

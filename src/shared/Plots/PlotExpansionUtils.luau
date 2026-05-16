--!strict

local PlotExpansionConfig = require(script.Parent.PlotExpansionConfig)
local PlotExpansionTypes = require(script.Parent.PlotExpansionTypes)

type PlotTileCoordinate = PlotExpansionTypes.PlotTileCoordinate
type PlotExpansionSnapshot = PlotExpansionTypes.PlotExpansionSnapshot

local EDGE_EPSILON = 0.001

type FrontAxis = "X" | "Z"

type PlotOrientation = {
	frontAxis: FrontAxis,
	frontSign: number,
}

local function resolvePlotOrientation(plotBase: BasePart, spawnPart: BasePart): PlotOrientation
	local localSpawnPosition = plotBase.CFrame:PointToObjectSpace(spawnPart.Position)
	local normalizedX = if plotBase.Size.X > 0 then math.abs(localSpawnPosition.X) / (plotBase.Size.X * 0.5) else 0
	local normalizedZ = if plotBase.Size.Z > 0 then math.abs(localSpawnPosition.Z) / (plotBase.Size.Z * 0.5) else 0

	if normalizedX >= normalizedZ then
		return {
			frontAxis = "X",
			frontSign = if localSpawnPosition.X >= 0 then 1 else -1,
		}
	end

	return {
		frontAxis = "Z",
		frontSign = if localSpawnPosition.Z >= 0 then 1 else -1,
	}
end

local function getDepthPosition(plotBase: BasePart, orientation: PlotOrientation, localX: number, localZ: number): number
	if orientation.frontAxis == "X" then
		local halfX = plotBase.Size.X * 0.5
		if orientation.frontSign < 0 then
			return localX + halfX
		end

		return halfX - localX
	end

	local halfZ = plotBase.Size.Z * 0.5
	if orientation.frontSign < 0 then
		return localZ + halfZ
	end

	return halfZ - localZ
end

local function getWidthPosition(plotBase: BasePart, orientation: PlotOrientation, localX: number, localZ: number): number
	if orientation.frontAxis == "X" then
		return localZ + (plotBase.Size.Z * 0.5)
	end

	return localX + (plotBase.Size.X * 0.5)
end

local function getIndexFromPosition(position: number, count: number): number?
	local tileSizeStuds = PlotExpansionConfig.getTileSizeStuds()
	local index = math.floor(position / tileSizeStuds) + 1
	if index < 1 or index > count then
		return nil
	end

	return index
end

local function insertUniqueTile(tiles: { PlotTileCoordinate }, seenTileKeys: { [string]: boolean }, row: number, column: number)
	local key = string.format("%d:%d", row, column)
	if seenTileKeys[key] == true then
		return
	end

	seenTileKeys[key] = true
	table.insert(tiles, {
		row = row,
		column = column,
	})
end

local PlotExpansionUtils = {}

function PlotExpansionUtils.getTileKey(row: number, column: number): string
	return string.format("%d:%d", row, column)
end

function PlotExpansionUtils.areTileCoordinatesEqual(left: PlotTileCoordinate, right: PlotTileCoordinate): boolean
	return left.row == right.row and left.column == right.column
end

function PlotExpansionUtils.getTileCoordinateForGridPosition(
	plotBase: BasePart,
	spawnPart: BasePart,
	gridX: number,
	gridZ: number
): PlotTileCoordinate?
	local orientation = resolvePlotOrientation(plotBase, spawnPart)
	local row = getIndexFromPosition(
		getDepthPosition(plotBase, orientation, gridX, gridZ),
		PlotExpansionConfig.getRowCount()
	)
	local column = getIndexFromPosition(
		getWidthPosition(plotBase, orientation, gridX, gridZ),
		PlotExpansionConfig.getColumnCount()
	)

	if row == nil or column == nil then
		return nil
	end

	return {
		row = row,
		column = column,
	}
end

function PlotExpansionUtils.getCoveredTilesForFootprint(
	plotBase: BasePart,
	spawnPart: BasePart,
	gridX: number,
	gridZ: number,
	footprint: Vector3
): { PlotTileCoordinate }
	local orientation = resolvePlotOrientation(plotBase, spawnPart)
	local footprintHalfX = footprint.X * 0.5
	local footprintHalfZ = footprint.Z * 0.5
	local localMinX = gridX - footprintHalfX + EDGE_EPSILON
	local localMaxX = gridX + footprintHalfX - EDGE_EPSILON
	local localMinZ = gridZ - footprintHalfZ + EDGE_EPSILON
	local localMaxZ = gridZ + footprintHalfZ - EDGE_EPSILON
	local rowStart = getIndexFromPosition(
		getDepthPosition(plotBase, orientation, localMinX, localMinZ),
		PlotExpansionConfig.getRowCount()
	)
	local rowEnd = getIndexFromPosition(
		getDepthPosition(plotBase, orientation, localMaxX, localMaxZ),
		PlotExpansionConfig.getRowCount()
	)
	local columnStart = getIndexFromPosition(
		getWidthPosition(plotBase, orientation, localMinX, localMinZ),
		PlotExpansionConfig.getColumnCount()
	)
	local columnEnd = getIndexFromPosition(
		getWidthPosition(plotBase, orientation, localMaxX, localMaxZ),
		PlotExpansionConfig.getColumnCount()
	)

	if rowStart == nil or rowEnd == nil or columnStart == nil or columnEnd == nil then
		return {}
	end

	local tiles: { PlotTileCoordinate } = {}
	local seenTileKeys: { [string]: boolean } = {}
	for row = math.min(rowStart, rowEnd), math.max(rowStart, rowEnd) do
		for column = math.min(columnStart, columnEnd), math.max(columnStart, columnEnd) do
			insertUniqueTile(tiles, seenTileKeys, row, column)
		end
	end

	return tiles
end

function PlotExpansionUtils.isFootprintUnlockedInSnapshot(
	snapshot: PlotExpansionSnapshot,
	plotBase: BasePart,
	spawnPart: BasePart,
	gridX: number,
	gridZ: number,
	footprint: Vector3
): boolean
	local coveredTiles = PlotExpansionUtils.getCoveredTilesForFootprint(plotBase, spawnPart, gridX, gridZ, footprint)
	if #coveredTiles == 0 then
		return false
	end

	local unlockedTileKeys: { [string]: boolean } = {}
	for _, tileSnapshot in ipairs(snapshot.tiles) do
		if tileSnapshot.isUnlocked then
			unlockedTileKeys[PlotExpansionUtils.getTileKey(tileSnapshot.row, tileSnapshot.column)] = true
		end
	end

	for _, coveredTile in ipairs(coveredTiles) do
		if unlockedTileKeys[PlotExpansionUtils.getTileKey(coveredTile.row, coveredTile.column)] ~= true then
			return false
		end
	end

	return true
end

function PlotExpansionUtils.getTileCenterCFrame(
	plotBase: BasePart,
	spawnPart: BasePart,
	row: number,
	column: number,
	heightOffset: number?
): CFrame?
	if not PlotExpansionConfig.isValidTileCoordinate(row, column) then
		return nil
	end

	local orientation = resolvePlotOrientation(plotBase, spawnPart)
	local tileSizeStuds = PlotExpansionConfig.getTileSizeStuds()
	local depthCenter = (row - 0.5) * tileSizeStuds
	local widthCenter = (column - 0.5) * tileSizeStuds
	local halfX = plotBase.Size.X * 0.5
	local halfZ = plotBase.Size.Z * 0.5
	local localX = 0
	local localZ = 0

	if orientation.frontAxis == "X" then
		localX = if orientation.frontSign < 0 then depthCenter - halfX else halfX - depthCenter
		localZ = widthCenter - halfZ
	else
		localZ = if orientation.frontSign < 0 then depthCenter - halfZ else halfZ - depthCenter
		localX = widthCenter - halfX
	end

	local localY = (plotBase.Size.Y * 0.5) + (heightOffset or 0)
	return plotBase.CFrame * CFrame.new(localX, localY, localZ)
end

return table.freeze(PlotExpansionUtils)

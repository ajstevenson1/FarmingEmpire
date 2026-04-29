--!strict

export type GridCoordinate = {
	x: number,
	z: number,
}

local PlotMath = {}

local function getMaxCenterOffsets(plotSize: Vector3, footprint: Vector3): (number, number)
	local maxOffsetX = math.floor((plotSize.X - footprint.X) * 0.5)
	local maxOffsetZ = math.floor((plotSize.Z - footprint.Z) * 0.5)
	return maxOffsetX, maxOffsetZ
end

function PlotMath.isGridWithinPlot(plotSize: Vector3, footprint: Vector3, gridX: number, gridZ: number): boolean
	if footprint.X > plotSize.X or footprint.Z > plotSize.Z then
		return false
	end

	local maxOffsetX, maxOffsetZ = getMaxCenterOffsets(plotSize, footprint)
	return math.abs(gridX) <= maxOffsetX and math.abs(gridZ) <= maxOffsetZ
end

function PlotMath.worldPositionToGrid(plotCFrame: CFrame, plotSize: Vector3, footprint: Vector3, worldPosition: Vector3): GridCoordinate?
	if footprint.X > plotSize.X or footprint.Z > plotSize.Z then
		return nil
	end

	local localPosition = plotCFrame:PointToObjectSpace(worldPosition)
	local gridX = math.round(localPosition.X)
	local gridZ = math.round(localPosition.Z)

	if not PlotMath.isGridWithinPlot(plotSize, footprint, gridX, gridZ) then
		return nil
	end

	return {
		x = gridX,
		z = gridZ,
	}
end

function PlotMath.gridToWorldCFrame(plotCFrame: CFrame, plotSize: Vector3, footprint: Vector3, gridX: number, gridZ: number): CFrame?
	if not PlotMath.isGridWithinPlot(plotSize, footprint, gridX, gridZ) then
		return nil
	end

	local localY = (plotSize.Y * 0.5) + (footprint.Y * 0.5)

	return plotCFrame * CFrame.new(gridX, localY, gridZ)
end

function PlotMath.doFootprintsOverlap(
	centerAX: number,
	centerAZ: number,
	footprintA: Vector3,
	centerBX: number,
	centerBZ: number,
	footprintB: Vector3
): boolean
	local combinedHalfWidth = (footprintA.X + footprintB.X) * 0.5
	local combinedHalfDepth = (footprintA.Z + footprintB.Z) * 0.5

	return math.abs(centerAX - centerBX) < combinedHalfWidth and math.abs(centerAZ - centerBZ) < combinedHalfDepth
end

return table.freeze(PlotMath)

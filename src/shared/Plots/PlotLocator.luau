--!strict

export type PlotInstance = BasePart | Model

local PlotLocator = {}

PlotLocator.PLOTS_FOLDER_NAME = "Plots"
PlotLocator.MAX_SUPPORTED_PLOTS = 6

PlotLocator.Attributes = table.freeze({
	ownerUserId = "OwnerUserId",
	ownerPlayerName = "OwnerPlayerName",
	slot = "Slot",
})

PlotLocator.PlayerAttributes = table.freeze({
	plotSlot = "PlotSlot",
	assignedPlotName = "AssignedPlotName",
})

local BASE_PART_NAMES: { string } = {
	"Base",
	"PlotBase",
	"PlacementBase",
	"Ground",
}

local SPAWN_PART_NAMES: { string } = {
	"SpawnPoint",
	"SpawnPart",
	"SpawnLocation",
}

local function isWholeNumber(value: number): boolean
	return value == math.floor(value)
end

local function parseSlotFromName(name: string): number?
	local digits = string.match(name, "%d+")
	if digits == nil then
		return nil
	end

	local slot = tonumber(digits)
	if slot == nil or not isWholeNumber(slot) then
		return nil
	end

	return slot
end

local function isPlotInstance(instance: Instance): boolean
	return instance:IsA("BasePart") or instance:IsA("Model")
end

local function findNamedBasePart(root: Instance, names: { string }): BasePart?
	for _, name in ipairs(names) do
		local descendant = root:FindFirstChild(name, true)
		if descendant ~= nil and descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

function PlotLocator.getSlot(plot: Instance): number?
	local rawSlot = plot:GetAttribute(PlotLocator.Attributes.slot)
	if type(rawSlot) == "number" and isWholeNumber(rawSlot) and rawSlot > 0 then
		return rawSlot
	end

	local parsedSlot = parseSlotFromName(plot.Name)
	if parsedSlot ~= nil and parsedSlot > 0 then
		return parsedSlot
	end

	return nil
end

function PlotLocator.getOwnerUserId(plot: Instance): number?
	local ownerUserId = plot:GetAttribute(PlotLocator.Attributes.ownerUserId)
	if type(ownerUserId) == "number" then
		return ownerUserId
	end

	return nil
end

function PlotLocator.isOwnedBy(plot: Instance, player: Player): boolean
	return PlotLocator.getOwnerUserId(plot) == player.UserId
end

function PlotLocator.getPlacementBase(plot: Instance): BasePart?
	if plot:IsA("BasePart") then
		return plot
	end

	if plot:IsA("Model") then
		local namedBasePart = findNamedBasePart(plot, BASE_PART_NAMES)
		if namedBasePart ~= nil then
			return namedBasePart
		end

		if plot.PrimaryPart ~= nil then
			return plot.PrimaryPart
		end

		return plot:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end

function PlotLocator.getSpawnPart(plot: Instance): BasePart?
	local namedSpawnPart = findNamedBasePart(plot, SPAWN_PART_NAMES)
	if namedSpawnPart ~= nil then
		return namedSpawnPart
	end

	local placementBase = PlotLocator.getPlacementBase(plot)
	if placementBase ~= nil then
		return placementBase
	end

	return nil
end

function PlotLocator.getAllPlots(plotsRoot: Instance): { Instance }
	local plots: { Instance } = {}

	for _, child in ipairs(plotsRoot:GetChildren()) do
		if isPlotInstance(child) then
			table.insert(plots, child)
		end
	end

	table.sort(plots, function(leftPlot, rightPlot)
		local leftSlot = PlotLocator.getSlot(leftPlot)
		local rightSlot = PlotLocator.getSlot(rightPlot)

		if leftSlot ~= nil and rightSlot ~= nil and leftSlot ~= rightSlot then
			return leftSlot < rightSlot
		end

		if leftSlot ~= nil and rightSlot == nil then
			return true
		end

		if leftSlot == nil and rightSlot ~= nil then
			return false
		end

		return leftPlot.Name < rightPlot.Name
	end)

	return plots
end

function PlotLocator.getPlotBySlot(plotsRoot: Instance, slot: number): Instance?
	for _, plot in ipairs(PlotLocator.getAllPlots(plotsRoot)) do
		if PlotLocator.getSlot(plot) == slot then
			return plot
		end
	end

	return nil
end

function PlotLocator.getAssignedSlot(player: Player): number?
	local slot = player:GetAttribute(PlotLocator.PlayerAttributes.plotSlot)
	if type(slot) == "number" and isWholeNumber(slot) and slot > 0 then
		return slot
	end

	return nil
end

function PlotLocator.getAssignedPlot(plotsRoot: Instance, player: Player): Instance?
	local assignedPlotName = player:GetAttribute(PlotLocator.PlayerAttributes.assignedPlotName)
	if type(assignedPlotName) == "string" then
		local assignedPlot = plotsRoot:FindFirstChild(assignedPlotName)
		if assignedPlot ~= nil and isPlotInstance(assignedPlot) and PlotLocator.isOwnedBy(assignedPlot, player) then
			return assignedPlot
		end
	end

	local assignedSlot = PlotLocator.getAssignedSlot(player)
	if assignedSlot ~= nil then
		local plotBySlot = PlotLocator.getPlotBySlot(plotsRoot, assignedSlot)
		if plotBySlot ~= nil and PlotLocator.isOwnedBy(plotBySlot, player) then
			return plotBySlot
		end
	end

	for _, plot in ipairs(PlotLocator.getAllPlots(plotsRoot)) do
		if PlotLocator.isOwnedBy(plot, player) then
			return plot
		end
	end

	return nil
end

function PlotLocator.findFirstAvailablePlot(plotsRoot: Instance): Instance?
	for _, plot in ipairs(PlotLocator.getAllPlots(plotsRoot)) do
		local slot = PlotLocator.getSlot(plot)
		if slot ~= nil
			and slot >= 1
			and slot <= PlotLocator.MAX_SUPPORTED_PLOTS
			and PlotLocator.getOwnerUserId(plot) == nil
			and PlotLocator.getPlacementBase(plot) ~= nil
		then
			return plot
		end
	end

	return nil
end

return table.freeze(PlotLocator)

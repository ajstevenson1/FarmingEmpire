--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local plotsFolder = sharedFolder:WaitForChild("Plots") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local PlotExpansionConfig = require(plotsFolder:WaitForChild("PlotExpansionConfig") :: ModuleScript)
local PlotExpansionRules = require(plotsFolder:WaitForChild("PlotExpansionRules") :: ModuleScript)
local PlotExpansionTypes = require(plotsFolder:WaitForChild("PlotExpansionTypes") :: ModuleScript)
local PlotExpansionUtils = require(plotsFolder:WaitForChild("PlotExpansionUtils") :: ModuleScript)
local PlotLocator = require(plotsFolder:WaitForChild("PlotLocator") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)
local EconomyService = require(script.Parent.Parent.Economy.EconomyService)
local Remotes = require(script.Parent.Parent.Networking.Remotes)
local PlotService = require(script.Parent.PlotService)

type BuildingId = BuildingTypes.BuildingId
type PlotExpansionSnapshot = PlotExpansionTypes.PlotExpansionSnapshot
type PlotModifierId = PlotExpansionTypes.PlotModifierId
type PlotTileCoordinate = PlotExpansionTypes.PlotTileCoordinate
type PlotTilePurchaseResult = PlotExpansionTypes.PlotTilePurchaseResult
type PlotTilePurchaseStatus = PlotExpansionTypes.PlotTilePurchaseStatus
type PlotTileSnapshot = PlotExpansionTypes.PlotTileSnapshot
type ResourceId = ResourceTypes.ResourceId
type PlotExpansionChangedListener = (Player) -> ()
type ModifierMultiplierResolver = (PlotModifierId?) -> number

local GRID_X_ATTRIBUTE = "GridX"
local GRID_Z_ATTRIBUTE = "GridZ"
local PLOT_NAME_ATTRIBUTE = "PlotName"
local PLOT_SLOT_ATTRIBUTE = "PlotSlot"

local workspacePlotsFolder = Workspace:WaitForChild(PlotLocator.PLOTS_FOLDER_NAME) :: Folder
local hasStarted = false
local changedListeners: { PlotExpansionChangedListener } = {}

local function buildUnlockedLookup(unlockedPlotTiles: { PlotTileCoordinate }): { [string]: boolean }
	local lookup: { [string]: boolean } = {}
	for _, unlockedPlotTile in ipairs(unlockedPlotTiles) do
		lookup[PlotExpansionUtils.getTileKey(unlockedPlotTile.row, unlockedPlotTile.column)] = true
	end

	return lookup
end

local function getAssignedPlotData(player: Player): (Instance?, BasePart?, BasePart?)
	local plot = PlotService.getAssignedPlot(player)
	if plot == nil then
		return nil, nil, nil
	end

	local plotBase = PlotLocator.getPlacementBase(plot)
	local spawnPart = PlotLocator.getSpawnPart(plot)
	if plotBase == nil or spawnPart == nil then
		return plot, nil, nil
	end

	return plot, plotBase, spawnPart
end

local function buildSnapshot(player: Player): PlotExpansionSnapshot
	local unlockedLookup = buildUnlockedLookup(PlayerDataService.getUnlockedPlotTiles(player))
	local tiles: { PlotTileSnapshot } = {}

	for _, tileDefinition in ipairs(PlotExpansionConfig.getTileDefinitions()) do
		table.insert(tiles, {
			row = tileDefinition.row,
			column = tileDefinition.column,
			price = tileDefinition.price,
			modifierId = tileDefinition.modifierId,
			isUnlocked = unlockedLookup[PlotExpansionUtils.getTileKey(tileDefinition.row, tileDefinition.column)] == true,
		})
	end

	return {
		rowCount = PlotExpansionConfig.getRowCount(),
		columnCount = PlotExpansionConfig.getColumnCount(),
		tileSizeStuds = PlotExpansionConfig.getTileSizeStuds(),
		starterTile = PlotExpansionConfig.getStarterTile(),
		tiles = tiles,
	}
end

local function pushSnapshot(player: Player): PlotExpansionSnapshot
	local snapshot = buildSnapshot(player)
	Remotes.getPlotExpansionRemotes().plotExpansionUpdated:FireClient(player, snapshot)

	for _, listener in ipairs(changedListeners) do
		local success, result = pcall(function()
			listener(player)
		end)

		if not success then
			warn(string.format("[PlotExpansionService] Changed listener failed for %s: %s", player.Name, tostring(result)))
		end
	end

	return snapshot
end

local function createPurchaseResult(
	player: Player,
	success: boolean,
	status: PlotTilePurchaseStatus,
	purchasedTile: PlotTileCoordinate?
): PlotTilePurchaseResult
	return {
		success = success,
		status = status,
		purchasedTile = purchasedTile,
		snapshot = buildSnapshot(player),
	}
end

local function hasUnlockedTile(player: Player, row: number, column: number): boolean
	for _, unlockedPlotTile in ipairs(PlayerDataService.getUnlockedPlotTiles(player)) do
		if unlockedPlotTile.row == row and unlockedPlotTile.column == column then
			return true
		end
	end

	return false
end

local function getModifierIdForTileCoordinate(plotTileCoordinate: PlotTileCoordinate?): PlotModifierId?
	if plotTileCoordinate == nil then
		return nil
	end

	local tileDefinition = PlotExpansionConfig.getTileDefinition(plotTileCoordinate.row, plotTileCoordinate.column)
	if tileDefinition == nil then
		return nil
	end

	return tileDefinition.modifierId
end

local function resolvePlotForPlacedPart(part: BasePart): (Instance?, BasePart?, BasePart?)
	local rawPlotSlot = part:GetAttribute(PLOT_SLOT_ATTRIBUTE)
	if type(rawPlotSlot) == "number" then
		local plotBySlot = PlotLocator.getPlotBySlot(workspacePlotsFolder, rawPlotSlot)
		if plotBySlot ~= nil then
			return plotBySlot, PlotLocator.getPlacementBase(plotBySlot), PlotLocator.getSpawnPart(plotBySlot)
		end
	end

	local rawPlotName = part:GetAttribute(PLOT_NAME_ATTRIBUTE)
	if type(rawPlotName) == "string" then
		local plotByName = workspacePlotsFolder:FindFirstChild(rawPlotName)
		if plotByName ~= nil then
			return plotByName, PlotLocator.getPlacementBase(plotByName), PlotLocator.getSpawnPart(plotByName)
		end
	end

	return nil, nil, nil
end

local function getTileCoordinateForPlacedPart(part: BasePart): PlotTileCoordinate?
	local gridX = part:GetAttribute(GRID_X_ATTRIBUTE)
	local gridZ = part:GetAttribute(GRID_Z_ATTRIBUTE)
	if type(gridX) ~= "number" or type(gridZ) ~= "number" then
		return nil
	end

	local _, plotBase, spawnPart = resolvePlotForPlacedPart(part)
	if plotBase == nil or spawnPart == nil then
		return nil
	end

	return PlotExpansionUtils.getTileCoordinateForGridPosition(plotBase, spawnPart, gridX, gridZ)
end

local function getCoveredTileCoordinatesForPlacedPart(part: BasePart): { PlotTileCoordinate }
	local gridX = part:GetAttribute(GRID_X_ATTRIBUTE)
	local gridZ = part:GetAttribute(GRID_Z_ATTRIBUTE)
	if type(gridX) ~= "number" or type(gridZ) ~= "number" then
		return {}
	end

	local _, plotBase, spawnPart = resolvePlotForPlacedPart(part)
	if plotBase == nil or spawnPart == nil then
		return {}
	end

	local coveredTiles = PlotExpansionUtils.getCoveredTilesForFootprint(plotBase, spawnPart, gridX, gridZ, part.Size)
	if #coveredTiles > 0 then
		return coveredTiles
	end

	local centerTile = PlotExpansionUtils.getTileCoordinateForGridPosition(plotBase, spawnPart, gridX, gridZ)
	if centerTile == nil then
		return {}
	end

	return { centerTile }
end

local function getWholeFootprintMultiplier(part: BasePart, resolveMultiplier: ModifierMultiplierResolver): number
	local coveredTiles = getCoveredTileCoordinatesForPlacedPart(part)
	if #coveredTiles == 0 then
		return 1
	end

	local multiplier: number? = nil
	for _, tileCoordinate in ipairs(coveredTiles) do
		local tileMultiplier = resolveMultiplier(getModifierIdForTileCoordinate(tileCoordinate))
		if tileMultiplier <= 1 then
			return 1
		end

		multiplier = if multiplier == nil then tileMultiplier else math.min(multiplier, tileMultiplier)
	end

	return multiplier or 1
end

local function getTileCoordinateForAssignedPlot(player: Player, gridX: number, gridZ: number): PlotTileCoordinate?
	local _, plotBase, spawnPart = getAssignedPlotData(player)
	if plotBase == nil or spawnPart == nil then
		return nil
	end

	return PlotExpansionUtils.getTileCoordinateForGridPosition(plotBase, spawnPart, gridX, gridZ)
end

local function tryPurchaseTile(player: Player, row: number, column: number): PlotTilePurchaseResult
	if not PlotExpansionConfig.isValidTileCoordinate(row, column) then
		return createPurchaseResult(player, false, "InvalidTile", nil)
	end

	local tileDefinition = PlotExpansionConfig.getTileDefinition(row, column)
	if tileDefinition == nil then
		return createPurchaseResult(player, false, "InvalidTile", nil)
	end

	local _, plotBase, spawnPart = getAssignedPlotData(player)
	if plotBase == nil or spawnPart == nil then
		return createPurchaseResult(player, false, "MissingPlot", nil)
	end

	if hasUnlockedTile(player, row, column) then
		return createPurchaseResult(player, false, "AlreadyUnlocked", {
			row = row,
			column = column,
		})
	end

	if tileDefinition.price > 0 and not EconomyService.trySpendCash(player, tileDefinition.price) then
		return createPurchaseResult(player, false, "InsufficientCash", {
			row = row,
			column = column,
		})
	end

	PlayerDataService.unlockPlotTile(player, row, column)
	local snapshot = pushSnapshot(player)

	return {
		success = true,
		status = "Purchased",
		purchasedTile = {
			row = row,
			column = column,
		},
		snapshot = snapshot,
	}
end

local function handlePurchaseRequest(player: Player, request: unknown): PlotTilePurchaseResult
	if type(request) ~= "table" then
		return createPurchaseResult(player, false, "InvalidTile", nil)
	end

	local requestValues = request :: { [string]: unknown }
	local row = requestValues.row
	local column = requestValues.column
	if type(row) ~= "number"
		or type(column) ~= "number"
		or row ~= math.floor(row)
		or column ~= math.floor(column)
	then
		return createPurchaseResult(player, false, "InvalidTile", nil)
	end

	return tryPurchaseTile(player, row, column)
end

local function initializePlayer(player: Player)
	PlayerDataService.waitForData(player)
	pushSnapshot(player)
end

local PlotExpansionService = {}

function PlotExpansionService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local plotExpansionRemotes = Remotes.getPlotExpansionRemotes()
	plotExpansionRemotes.getPlotExpansionSnapshot.OnServerInvoke = function(player: Player): PlotExpansionSnapshot
		return buildSnapshot(player)
	end
	plotExpansionRemotes.requestPlotTilePurchase.OnServerInvoke = handlePurchaseRequest

	Players.PlayerAdded:Connect(initializePlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		initializePlayer(player)
	end
end

function PlotExpansionService.getSnapshot(player: Player): PlotExpansionSnapshot
	return buildSnapshot(player)
end

function PlotExpansionService.observeChanged(listener: PlotExpansionChangedListener)
	table.insert(changedListeners, listener)
end

function PlotExpansionService.isFootprintUnlockedForAssignedPlot(
	player: Player,
	plotBase: BasePart,
	footprint: Vector3,
	gridX: number,
	gridZ: number
): boolean
	local assignedPlot, assignedPlotBase, spawnPart = getAssignedPlotData(player)
	if assignedPlot == nil or assignedPlotBase == nil or spawnPart == nil or assignedPlotBase ~= plotBase then
		return false
	end

	local coveredTiles = PlotExpansionUtils.getCoveredTilesForFootprint(plotBase, spawnPart, gridX, gridZ, footprint)
	if #coveredTiles == 0 then
		return false
	end

	local unlockedLookup = buildUnlockedLookup(PlayerDataService.getUnlockedPlotTiles(player))
	for _, coveredTile in ipairs(coveredTiles) do
		if unlockedLookup[PlotExpansionUtils.getTileKey(coveredTile.row, coveredTile.column)] ~= true then
			return false
		end
	end

	return true
end

function PlotExpansionService.ensureFootprintUnlockedForAssignedPlot(
	player: Player,
	plotBase: BasePart,
	footprint: Vector3,
	gridX: number,
	gridZ: number
)
	local _, assignedPlotBase, spawnPart = getAssignedPlotData(player)
	if assignedPlotBase == nil or spawnPart == nil or assignedPlotBase ~= plotBase then
		return
	end

	local coveredTiles = PlotExpansionUtils.getCoveredTilesForFootprint(plotBase, spawnPart, gridX, gridZ, footprint)
	if #coveredTiles == 0 then
		return
	end

	local didUnlockAnyTile = false
	for _, coveredTile in ipairs(coveredTiles) do
		if not hasUnlockedTile(player, coveredTile.row, coveredTile.column) then
			PlayerDataService.unlockPlotTile(player, coveredTile.row, coveredTile.column)
			didUnlockAnyTile = true
		end
	end

	if didUnlockAnyTile then
		pushSnapshot(player)
	end
end

function PlotExpansionService.tryPurchaseTile(player: Player, row: number, column: number): PlotTilePurchaseResult
	return tryPurchaseTile(player, row, column)
end

function PlotExpansionService.getModifierIdForPlacedPart(part: BasePart): PlotModifierId?
	return getModifierIdForTileCoordinate(getTileCoordinateForPlacedPart(part))
end

function PlotExpansionService.getResourceOutputMultiplierForPlacedPart(part: BasePart, resourceId: ResourceId): number
	return getWholeFootprintMultiplier(part, function(modifierId: PlotModifierId?): number
		return PlotExpansionRules.getResourceOutputMultiplier(modifierId, resourceId)
	end)
end

function PlotExpansionService.getStorageCapMultiplierForPlacedPart(part: BasePart, resourceId: ResourceId): number
	return getWholeFootprintMultiplier(part, function(modifierId: PlotModifierId?): number
		return PlotExpansionRules.getStorageCapMultiplier(modifierId, resourceId)
	end)
end

function PlotExpansionService.getBuildingProductionMultiplierForPlacedPart(part: BasePart, buildingId: BuildingId): number
	return getWholeFootprintMultiplier(part, function(modifierId: PlotModifierId?): number
		return PlotExpansionRules.getBuildingProductionMultiplier(modifierId, buildingId)
	end)
end

function PlotExpansionService.getOfflineCiderRateMultiplierForPlacedBuilding(
	player: Player,
	buildingId: BuildingId,
	gridX: number,
	gridZ: number
): number
	return PlotExpansionRules.getOfflineCiderRateMultiplier(
		getModifierIdForTileCoordinate(getTileCoordinateForAssignedPlot(player, gridX, gridZ)),
		buildingId
	)
end

return table.freeze(PlotExpansionService)

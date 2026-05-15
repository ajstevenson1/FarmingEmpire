--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before starting OfflineRateController")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local offlineEarningsFolder = sharedFolder:WaitForChild("OfflineEarnings") :: Folder
local plotsFolder = sharedFolder:WaitForChild("Plots") :: Folder

local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local OfflineCiderRateCalculator = require(offlineEarningsFolder:WaitForChild("OfflineCiderRateCalculator") :: ModuleScript)
local PlotExpansionConfig = require(plotsFolder:WaitForChild("PlotExpansionConfig") :: ModuleScript)
local PlotExpansionRules = require(plotsFolder:WaitForChild("PlotExpansionRules") :: ModuleScript)
local PlotExpansionUtils = require(plotsFolder:WaitForChild("PlotExpansionUtils") :: ModuleScript)
local PlotLocator = require(plotsFolder:WaitForChild("PlotLocator") :: ModuleScript)
local OfflineRateView = require(script.Parent.OfflineRateView)

type BuildingId = BuildingTypes.BuildingId
type OfflineRateBuilding = OfflineCiderRateCalculator.OfflineRateBuilding
type OfflineRateViewInstance = OfflineRateView.OfflineRateView

type TrackedPartConnections = {
	buildingIdChanged: RBXScriptConnection,
	ownerUserIdChanged: RBXScriptConnection,
	plotNameChanged: RBXScriptConnection,
	ancestryChanged: RBXScriptConnection,
}

local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local GRID_X_ATTRIBUTE = "GridX"
local GRID_Z_ATTRIBUTE = "GridZ"
local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
local PLOT_NAME_ATTRIBUTE = "PlotName"

local hasStarted = false
local trackedConnectionsByPart: { [BasePart]: TrackedPartConnections } = {}
local workspacePlotsFolder = Workspace:WaitForChild(PlotLocator.PLOTS_FOLDER_NAME) :: Folder

local function getPlacedObjectsFolder(): Folder
	local folder = Workspace:WaitForChild(PLACED_OBJECTS_FOLDER_NAME)
	assert(folder:IsA("Folder"), string.format("%s must be a Folder", PLACED_OBJECTS_FOLDER_NAME))
	return folder
end

local function getAssignedPlotName(): string?
	local value = localPlayer:GetAttribute(PlotLocator.PlayerAttributes.assignedPlotName)
	return if type(value) == "string" then value else nil
end

local function getAssignedPlot(): Instance?
	return PlotLocator.getAssignedPlot(workspacePlotsFolder, localPlayer)
end

local function getOfflineRateMultiplier(buildingId: BuildingId, gridX: number, gridZ: number): number
	local assignedPlot = getAssignedPlot()
	if assignedPlot == nil then
		return 1
	end

	local plotBase = PlotLocator.getPlacementBase(assignedPlot)
	local spawnPart = PlotLocator.getSpawnPart(assignedPlot)
	if plotBase == nil or spawnPart == nil then
		return 1
	end

	local tileCoordinate = PlotExpansionUtils.getTileCoordinateForGridPosition(plotBase, spawnPart, gridX, gridZ)
	if tileCoordinate == nil then
		return 1
	end

	local tileDefinition = PlotExpansionConfig.getTileDefinition(tileCoordinate.row, tileCoordinate.column)
	if tileDefinition == nil then
		return 1
	end

	return PlotExpansionRules.getOfflineCiderRateMultiplier(tileDefinition.modifierId, buildingId)
end

local function getOwnedBuildingIds(placedObjectsFolder: Folder): { OfflineRateBuilding }
	local assignedPlotName = getAssignedPlotName()
	if assignedPlotName == nil then
		return {}
	end

	local ownedBuildings: { OfflineRateBuilding } = {}
	for _, child in ipairs(placedObjectsFolder:GetChildren()) do
		if child:IsA("BasePart")
			and child:GetAttribute(OWNER_USER_ID_ATTRIBUTE) == localPlayer.UserId
			and child:GetAttribute(PLOT_NAME_ATTRIBUTE) == assignedPlotName
		then
			local buildingIdValue = child:GetAttribute(BuildingAttributeNames.buildingId)
			local gridXValue = child:GetAttribute(GRID_X_ATTRIBUTE)
			local gridZValue = child:GetAttribute(GRID_Z_ATTRIBUTE)
			if type(buildingIdValue) == "string"
				and BuildingCatalog.hasBuildingDefinition(buildingIdValue)
				and type(gridXValue) == "number"
				and type(gridZValue) == "number"
			then
				local buildingId = buildingIdValue :: BuildingId
				table.insert(ownedBuildings, {
					buildingId = buildingId,
					rateMultiplier = getOfflineRateMultiplier(buildingId, gridXValue, gridZValue),
				})
			end
		end
	end

	return ownedBuildings
end

local function recomputeOfflineRate(view: OfflineRateViewInstance, placedObjectsFolder: Folder)
	local ciderPerHour = OfflineCiderRateCalculator.calculateCiderPerHour(getOwnedBuildingIds(placedObjectsFolder))
	view:render(ciderPerHour)
end

local function disconnectTrackedPart(part: BasePart)
	local trackedConnections = trackedConnectionsByPart[part]
	if trackedConnections == nil then
		return
	end

	trackedConnections.buildingIdChanged:Disconnect()
	trackedConnections.ownerUserIdChanged:Disconnect()
	trackedConnections.plotNameChanged:Disconnect()
	trackedConnections.ancestryChanged:Disconnect()
	trackedConnectionsByPart[part] = nil
end

local function trackPart(part: BasePart, view: OfflineRateViewInstance, placedObjectsFolder: Folder)
	if trackedConnectionsByPart[part] ~= nil then
		return
	end

	trackedConnectionsByPart[part] = {
		buildingIdChanged = part:GetAttributeChangedSignal(BuildingAttributeNames.buildingId):Connect(function()
			recomputeOfflineRate(view, placedObjectsFolder)
		end),
		ownerUserIdChanged = part:GetAttributeChangedSignal(OWNER_USER_ID_ATTRIBUTE):Connect(function()
			recomputeOfflineRate(view, placedObjectsFolder)
		end),
		plotNameChanged = part:GetAttributeChangedSignal(PLOT_NAME_ATTRIBUTE):Connect(function()
			recomputeOfflineRate(view, placedObjectsFolder)
		end),
		ancestryChanged = part.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				disconnectTrackedPart(part)
				recomputeOfflineRate(view, placedObjectsFolder)
			end
		end),
	}

	recomputeOfflineRate(view, placedObjectsFolder)
end

local OfflineRateController = {}

function OfflineRateController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local view = OfflineRateView.new()
	local placedObjectsFolder = getPlacedObjectsFolder()

	for _, child in ipairs(placedObjectsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			trackPart(child, view, placedObjectsFolder)
		end
	end

	placedObjectsFolder.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			trackPart(child, view, placedObjectsFolder)
		end
	end)

	placedObjectsFolder.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") then
			disconnectTrackedPart(child)
			recomputeOfflineRate(view, placedObjectsFolder)
		end
	end)

	localPlayer:GetAttributeChangedSignal(PlotLocator.PlayerAttributes.assignedPlotName):Connect(function()
		recomputeOfflineRate(view, placedObjectsFolder)
	end)

	recomputeOfflineRate(view, placedObjectsFolder)
end

return table.freeze(OfflineRateController)

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
local windmillsFolder = sharedFolder:WaitForChild("Windmills") :: Folder

local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local OfflineCiderRateCalculator = require(offlineEarningsFolder:WaitForChild("OfflineCiderRateCalculator") :: ModuleScript)
local PlotExpansionConfig = require(plotsFolder:WaitForChild("PlotExpansionConfig") :: ModuleScript)
local PlotExpansionRules = require(plotsFolder:WaitForChild("PlotExpansionRules") :: ModuleScript)
local PlotExpansionUtils = require(plotsFolder:WaitForChild("PlotExpansionUtils") :: ModuleScript)
local PlotLocator = require(plotsFolder:WaitForChild("PlotLocator") :: ModuleScript)
local WindmillConfig = require(windmillsFolder:WaitForChild("WindmillConfig") :: ModuleScript)
local OfflineRateView = require(script.Parent.OfflineRateView)

type BuildingId = BuildingTypes.BuildingId
type OfflineRateBuilding = OfflineCiderRateCalculator.OfflineRateBuilding
type OfflineRateViewInstance = OfflineRateView.OfflineRateView

type TrackedPartConnections = {
	buildingIdChanged: RBXScriptConnection,
	ownerUserIdChanged: RBXScriptConnection,
	plotNameChanged: RBXScriptConnection,
	gridXChanged: RBXScriptConnection,
	gridZChanged: RBXScriptConnection,
	ancestryChanged: RBXScriptConnection,
}

local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local GRID_X_ATTRIBUTE = "GridX"
local GRID_Z_ATTRIBUTE = "GridZ"
local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
local PLOT_NAME_ATTRIBUTE = "PlotName"

local hasStarted = false
local trackedConnectionsByPart: { [BasePart]: TrackedPartConnections } = {}
local trackedRateParts: { [BasePart]: boolean } = {}
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

local function shouldAffectLocalRate(part: BasePart): boolean
	local assignedPlotName = getAssignedPlotName()
	if assignedPlotName == nil then
		return false
	end

	return part:GetAttribute(OWNER_USER_ID_ATTRIBUTE) == localPlayer.UserId
		and part:GetAttribute(PLOT_NAME_ATTRIBUTE) == assignedPlotName
end

local function getOwnedBuildingIds(): { OfflineRateBuilding }
	local ownedBuildings: { OfflineRateBuilding } = {}
	for child in pairs(trackedRateParts) do
		if child.Parent == nil or not shouldAffectLocalRate(child) then
			trackedRateParts[child] = nil
			continue
		end

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

	return ownedBuildings
end

local function getOfflineWindmillMultiplier(buildings: { OfflineRateBuilding }): number
	local bonusTotal = 0
	for _, building in ipairs(buildings) do
		bonusTotal += WindmillConfig.getOfflineEarningsMultiplierBonus(building.buildingId)
	end

	return 1 + bonusTotal
end

local function recomputeOfflineRate(view: OfflineRateViewInstance)
	local ownedBuildings = getOwnedBuildingIds()
	local ciderPerHour =
		OfflineCiderRateCalculator.calculateCiderPerHour(ownedBuildings, getOfflineWindmillMultiplier(ownedBuildings))
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
	trackedConnections.gridXChanged:Disconnect()
	trackedConnections.gridZChanged:Disconnect()
	trackedConnections.ancestryChanged:Disconnect()
	trackedConnectionsByPart[part] = nil
end

local function refreshTrackedRatePart(part: BasePart, view: OfflineRateViewInstance)
	local wasTracked = trackedRateParts[part] == true
	local shouldTrack = part.Parent ~= nil and shouldAffectLocalRate(part)

	if shouldTrack then
		trackedRateParts[part] = true
	else
		trackedRateParts[part] = nil
	end

	if wasTracked or shouldTrack then
		recomputeOfflineRate(view)
	end
end

local function recomputeIfTracked(part: BasePart, view: OfflineRateViewInstance)
	if trackedRateParts[part] == true then
		recomputeOfflineRate(view)
	end
end

local function trackPart(part: BasePart, view: OfflineRateViewInstance)
	if trackedConnectionsByPart[part] ~= nil then
		return
	end

	trackedConnectionsByPart[part] = {
		buildingIdChanged = part:GetAttributeChangedSignal(BuildingAttributeNames.buildingId):Connect(function()
			recomputeIfTracked(part, view)
		end),
		ownerUserIdChanged = part:GetAttributeChangedSignal(OWNER_USER_ID_ATTRIBUTE):Connect(function()
			refreshTrackedRatePart(part, view)
		end),
		plotNameChanged = part:GetAttributeChangedSignal(PLOT_NAME_ATTRIBUTE):Connect(function()
			refreshTrackedRatePart(part, view)
		end),
		gridXChanged = part:GetAttributeChangedSignal(GRID_X_ATTRIBUTE):Connect(function()
			recomputeIfTracked(part, view)
		end),
		gridZChanged = part:GetAttributeChangedSignal(GRID_Z_ATTRIBUTE):Connect(function()
			recomputeIfTracked(part, view)
		end),
		ancestryChanged = part.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				local wasTracked = trackedRateParts[part] == true
				trackedRateParts[part] = nil
				disconnectTrackedPart(part)
				if wasTracked then
					recomputeOfflineRate(view)
				end
			end
		end),
	}

	refreshTrackedRatePart(part, view)
end

local function refreshAllTrackedRateParts(view: OfflineRateViewInstance, placedObjectsFolder: Folder)
	table.clear(trackedRateParts)
	for _, child in ipairs(placedObjectsFolder:GetChildren()) do
		if child:IsA("BasePart") and shouldAffectLocalRate(child) then
			trackedRateParts[child] = true
		end
	end

	recomputeOfflineRate(view)
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
			trackPart(child, view)
		end
	end

	placedObjectsFolder.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			trackPart(child, view)
		end
	end)

	placedObjectsFolder.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") then
			local wasTracked = trackedRateParts[child] == true
			trackedRateParts[child] = nil
			disconnectTrackedPart(child)
			if wasTracked then
				recomputeOfflineRate(view)
			end
		end
	end)

	localPlayer:GetAttributeChangedSignal(PlotLocator.PlayerAttributes.assignedPlotName):Connect(function()
		refreshAllTrackedRateParts(view, placedObjectsFolder)
	end)

	refreshAllTrackedRateParts(view, placedObjectsFolder)
end

return table.freeze(OfflineRateController)

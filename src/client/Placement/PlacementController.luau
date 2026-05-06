--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before starting placement")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local placementFolder = sharedFolder:WaitForChild("Placement") :: Folder
local plotsCodeFolder = sharedFolder:WaitForChild("Plots") :: Folder

local BuildingAssetUtils = require(buildingsFolder:WaitForChild("BuildingAssetUtils") :: ModuleScript)
local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local InventoryUtils = require(inventoryFolder:WaitForChild("InventoryUtils") :: ModuleScript)
local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local PlotMath = require(placementFolder:WaitForChild("PlotMath") :: ModuleScript)
local PlotLocator = require(plotsCodeFolder:WaitForChild("PlotLocator") :: ModuleScript)
local InventoryController = require(script.Parent.Parent.Inventory.InventoryController)
local StructureActionMode = require(script.Parent.StructureActionMode)
local PlacementPreviewView = require(script.Parent.PlacementPreviewView)

type ItemDefinition = InventoryTypes.ItemDefinition
type ItemId = InventoryTypes.ItemId
type InventorySnapshot = InventoryTypes.InventorySnapshot
type GridCoordinate = PlotMath.GridCoordinate

type PreviewState = {
	gridX: number,
	gridZ: number,
}

local PLOTS_FOLDER_NAME = "Plots"
local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local PLOT_NAME_ATTRIBUTE = "PlotName"
local GRID_X_ATTRIBUTE = "GridX"
local GRID_Z_ATTRIBUTE = "GridZ"

local hasStarted = false

type PlacementRemotes = {
	requestPlacement: RemoteEvent,
	requestPickup: RemoteEvent,
}

local function getPlacementRemotes(): PlacementRemotes
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local placementRemotesFolder = rootFolder:WaitForChild(RemoteNames.placementFolderName) :: Folder

	return {
		requestPlacement = placementRemotesFolder:WaitForChild(RemoteNames.requestPlacementEventName) :: RemoteEvent,
		requestPickup = placementRemotesFolder:WaitForChild(RemoteNames.requestPickupEventName) :: RemoteEvent,
	}
end

local function getAssignedPlot(): Instance?
	local plotsFolder = Workspace:FindFirstChild(PLOTS_FOLDER_NAME)
	if plotsFolder == nil or not plotsFolder:IsA("Folder") then
		return nil
	end

	return PlotLocator.getAssignedPlot(plotsFolder, localPlayer)
end

local function getEquippedPlaceableItem(snapshot: InventorySnapshot): (ItemId?, ItemDefinition?)
	local equippedItemId = InventoryUtils.getSelectedItemId(snapshot)
	if equippedItemId == nil then
		return nil, nil
	end

	local itemDefinition = ItemCatalog.getItemDefinition(equippedItemId)
	if itemDefinition.kind ~= "Placeable" then
		return nil, nil
	end

	return equippedItemId, itemDefinition
end

local function getPlotRaycastResult(plot: BasePart): RaycastResult?
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	local screenRay = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { plot }
	raycastParams.IgnoreWater = true

	return Workspace:Raycast(screenRay.Origin, screenRay.Direction * 1000, raycastParams)
end

local function isGridOccupied(plotName: string, footprint: Vector3, grid: GridCoordinate): boolean
	local placedObjectsFolder = Workspace:FindFirstChild(PLACED_OBJECTS_FOLDER_NAME)
	if placedObjectsFolder == nil or not placedObjectsFolder:IsA("Folder") then
		return false
	end

	for _, child in ipairs(placedObjectsFolder:GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute(PLOT_NAME_ATTRIBUTE) == plotName then
			local existingGridX = child:GetAttribute(GRID_X_ATTRIBUTE)
			local existingGridZ = child:GetAttribute(GRID_Z_ATTRIBUTE)

			if type(existingGridX) == "number"
				and type(existingGridZ) == "number"
				and PlotMath.doFootprintsOverlap(grid.x, grid.z, footprint, existingGridX, existingGridZ, child.Size) then
				return true
			end
		end
	end

	return false
end

local PlacementController = {}

function PlacementController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local previewView = PlacementPreviewView.new()
	local placementRemotes = getPlacementRemotes()
	local latestSnapshot = InventoryController.getLatestSnapshot()
	local currentPreviewState: PreviewState? = nil

	InventoryController.observeSnapshotChanged(function(snapshot: InventorySnapshot)
		latestSnapshot = snapshot
	end)

	RunService.RenderStepped:Connect(function()
		if StructureActionMode.getMode() ~= "None" then
			previewView:hide()
			currentPreviewState = nil
			return
		end

		local snapshot = latestSnapshot
		if snapshot == nil then
			previewView:hide()
			currentPreviewState = nil
			return
		end

		local _, itemDefinition = getEquippedPlaceableItem(snapshot)
		if itemDefinition == nil then
			previewView:hide()
			currentPreviewState = nil
			return
		end

		local buildingDefinition = BuildingCatalog.getBuildingDefinition(itemDefinition.id)
		local placementFootprint = BuildingAssetUtils.getPlacementFootprint(buildingDefinition)

		local plot = getAssignedPlot()
		local plotBase = if plot == nil then nil else PlotLocator.getPlacementBase(plot)
		if plot == nil or plotBase == nil then
			previewView:hide()
			currentPreviewState = nil
			return
		end

		local raycastResult = getPlotRaycastResult(plotBase)
		if raycastResult == nil then
			previewView:hide()
			currentPreviewState = nil
			return
		end

		local grid = PlotMath.worldPositionToGrid(plotBase.CFrame, plotBase.Size, placementFootprint, raycastResult.Position)
		if grid == nil then
			previewView:hide()
			currentPreviewState = nil
			return
		end

		local placementCFrame = PlotMath.gridToWorldCFrame(plotBase.CFrame, plotBase.Size, placementFootprint, grid.x, grid.z)
		if placementCFrame == nil then
			previewView:hide()
			currentPreviewState = nil
			return
		end

		local isValid = not isGridOccupied(plot.Name, placementFootprint, grid)
		previewView:show(buildingDefinition, itemDefinition, placementCFrame, isValid)
		currentPreviewState = {
			gridX = grid.x,
			gridZ = grid.z,
		}
	end)

	UserInputService.InputBegan:Connect(function(inputObject: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if StructureActionMode.getMode() ~= "None" then
			return
		end

		if UserInputService:GetFocusedTextBox() ~= nil then
			return
		end

		if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		local snapshot = latestSnapshot
		local previewState = currentPreviewState
		if snapshot == nil or previewState == nil then
			return
		end

		local _, itemDefinition = getEquippedPlaceableItem(snapshot)
		local plot = getAssignedPlot()
		if itemDefinition == nil or plot == nil then
			return
		end

		local buildingDefinition = BuildingCatalog.getBuildingDefinition(itemDefinition.id)
		local placementFootprint = BuildingAssetUtils.getPlacementFootprint(buildingDefinition)

		local currentGrid = {
			x = previewState.gridX,
			z = previewState.gridZ,
		}
		if isGridOccupied(plot.Name, placementFootprint, currentGrid) then
			return
		end

		placementRemotes.requestPlacement:FireServer(previewState.gridX, previewState.gridZ)
	end)
end

return table.freeze(PlacementController)

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
local progressionFolder = sharedFolder:WaitForChild("Progression") :: Folder
local plotsCodeFolder = sharedFolder:WaitForChild("Plots") :: Folder

local BuildingAssetUtils = require(buildingsFolder:WaitForChild("BuildingAssetUtils") :: ModuleScript)
local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local InventoryUtils = require(inventoryFolder:WaitForChild("InventoryUtils") :: ModuleScript)
local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local PlotMath = require(placementFolder:WaitForChild("PlotMath") :: ModuleScript)
local ProgressionConfig = require(progressionFolder:WaitForChild("ProgressionConfig") :: ModuleScript)
local PlotExpansionTypes = require(plotsCodeFolder:WaitForChild("PlotExpansionTypes") :: ModuleScript)
local PlotExpansionUtils = require(plotsCodeFolder:WaitForChild("PlotExpansionUtils") :: ModuleScript)
local PlotLocator = require(plotsCodeFolder:WaitForChild("PlotLocator") :: ModuleScript)
local InventoryController = require(script.Parent.Parent.Inventory.InventoryController)
local ClientInputProfile = require(script.Parent.Parent.Input.ClientInputProfile)
local HudTooltip = require(script.Parent.Parent.UI.HudTooltip)
local StructureActionMode = require(script.Parent.StructureActionMode)
local PlacementPreviewView = require(script.Parent.PlacementPreviewView)

type ItemDefinition = InventoryTypes.ItemDefinition
type ItemId = InventoryTypes.ItemId
type InventorySnapshot = InventoryTypes.InventorySnapshot
type GridCoordinate = PlotMath.GridCoordinate
type PlacementRotationQuarterTurns = BuildingTypes.PlacementRotationQuarterTurns
type PlotExpansionSnapshot = PlotExpansionTypes.PlotExpansionSnapshot

type PreviewState = {
	gridX: number,
	gridZ: number,
	rotationQuarterTurns: PlacementRotationQuarterTurns,
	isValid: boolean,
}

local PLOTS_FOLDER_NAME = "Plots"
local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local PLOT_NAME_ATTRIBUTE = "PlotName"
local GRID_X_ATTRIBUTE = "GridX"
local GRID_Z_ATTRIBUTE = "GridZ"
local PLACEMENT_TOOLTIP_OWNER_ID = "Placement"
local DESKTOP_PLACEMENT_TOOLTIP_TEXT = "Click to place"
local DESKTOP_ROTATABLE_PLACEMENT_TOOLTIP_TEXT = "Click to place, press R to rotate"
local MOBILE_PLACEMENT_TOOLTIP_TEXT = "Move and drag to position, tap to place"
local GAMEPAD_PLACEMENT_TOOLTIP_TEXT = "Press right trigger to place"
local MOBILE_MAX_PLACEMENT_DISTANCE_STUDS = 18
local MOBILE_MIN_PLACEMENT_DISTANCE_STUDS = 4

local hasStarted = false

type PlacementRemotes = {
	requestPlacement: RemoteEvent,
	requestPickup: RemoteEvent,
}

type PlotExpansionRemotes = {
	plotExpansionUpdated: RemoteEvent,
	getPlotExpansionSnapshot: RemoteFunction,
}

local function getPlacementRemotes(): PlacementRemotes
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local placementRemotesFolder = rootFolder:WaitForChild(RemoteNames.placementFolderName) :: Folder

	return {
		requestPlacement = placementRemotesFolder:WaitForChild(RemoteNames.requestPlacementEventName) :: RemoteEvent,
		requestPickup = placementRemotesFolder:WaitForChild(RemoteNames.requestPickupEventName) :: RemoteEvent,
	}
end

local function getMobileRotateButton(): GuiButton
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild("GUI")
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")

	local hud = rootGui:WaitForChild("HUD")
	assert(hud:IsA("Frame"), "GUI.HUD must be a Frame")

	local rightFrame = hud:WaitForChild("Right")
	assert(rightFrame:IsA("Frame"), "GUI.HUD.Right must be a Frame")

	local button = rightFrame:WaitForChild("Rotate")
	assert(button:IsA("GuiButton"), "GUI.HUD.Right.Rotate must be an ImageButton or TextButton")

	return button
end

local function getPlotExpansionRemotes(): PlotExpansionRemotes
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local plotExpansionRemotesFolder = rootFolder:WaitForChild(RemoteNames.plotExpansionFolderName) :: Folder

	return {
		plotExpansionUpdated = plotExpansionRemotesFolder:WaitForChild(RemoteNames.plotExpansionUpdatedEventName) :: RemoteEvent,
		getPlotExpansionSnapshot = plotExpansionRemotesFolder:WaitForChild(RemoteNames.getPlotExpansionSnapshotFunctionName) :: RemoteFunction,
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

local function getPlacementTooltipTextForItem(itemDefinition: ItemDefinition): string
	if ClientInputProfile.usesTouchControls() then
		return MOBILE_PLACEMENT_TOOLTIP_TEXT
	end

	if ClientInputProfile.usesGamepadControls() then
		return GAMEPAD_PLACEMENT_TOOLTIP_TEXT
	end

	if ProgressionConfig.isTreeBuildingId(itemDefinition.id) or ProgressionConfig.isMillBuildingId(itemDefinition.id) then
		return DESKTOP_ROTATABLE_PLACEMENT_TOOLTIP_TEXT
	end

	return DESKTOP_PLACEMENT_TOOLTIP_TEXT
end

local function getPlotRaycastResult(plot: BasePart): RaycastResult?
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end

	local pointerPosition = UserInputService:GetMouseLocation()
	local screenRay = camera:ViewportPointToRay(pointerPosition.X, pointerPosition.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { plot }
	raycastParams.IgnoreWater = true

	return Workspace:Raycast(screenRay.Origin, screenRay.Direction * 1000, raycastParams)
end

local function getCharacterRootPart(): BasePart?
	local character = localPlayer.Character
	if character == nil then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil
	end

	return rootPart
end

local function getMobilePlacementWorldPosition(): Vector3?
	local rootPart = getCharacterRootPart()
	if rootPart == nil then
		return nil
	end

	local currentCamera = Workspace.CurrentCamera
	local lookVector = if currentCamera == nil then rootPart.CFrame.LookVector else currentCamera.CFrame.LookVector
	local planarLookVector = Vector3.new(lookVector.X, 0, lookVector.Z)
	if planarLookVector.Magnitude <= 0.001 then
		local rootLookVector = rootPart.CFrame.LookVector
		planarLookVector = Vector3.new(rootLookVector.X, 0, rootLookVector.Z)
	end

	if planarLookVector.Magnitude <= 0.001 then
		return nil
	end

	local downwardAmount = math.clamp(-lookVector.Y, 0, 1)
	local placementDistance = MOBILE_MAX_PLACEMENT_DISTANCE_STUDS
		+ (MOBILE_MIN_PLACEMENT_DISTANCE_STUDS - MOBILE_MAX_PLACEMENT_DISTANCE_STUDS) * downwardAmount
	return rootPart.Position + planarLookVector.Unit * placementDistance
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

local function isFootprintUnlocked(
	plotBase: BasePart,
	spawnPart: BasePart,
	footprint: Vector3,
	grid: GridCoordinate,
	plotExpansionSnapshot: PlotExpansionSnapshot?
): boolean
	if plotExpansionSnapshot == nil then
		return false
	end

	return PlotExpansionUtils.isFootprintUnlockedInSnapshot(
		plotExpansionSnapshot,
		plotBase,
		spawnPart,
		grid.x,
		grid.z,
		footprint
	)
end

local function isRotatablePlaceableItem(itemDefinition: ItemDefinition?): boolean
	if itemDefinition == nil or itemDefinition.kind ~= "Placeable" then
		return false
	end

	return ProgressionConfig.isTreeBuildingId(itemDefinition.id) or ProgressionConfig.isMillBuildingId(itemDefinition.id)
end

local PlacementController = {}

function PlacementController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local previewView = PlacementPreviewView.new()
	local placementRemotes = getPlacementRemotes()
	local plotExpansionRemotes = getPlotExpansionRemotes()
	local hudTooltip = HudTooltip.get()
	local mobileRotateButton = getMobileRotateButton()
	local latestSnapshot = InventoryController.getLatestSnapshot()
	local latestPlotExpansionSnapshot = plotExpansionRemotes.getPlotExpansionSnapshot:InvokeServer() :: PlotExpansionSnapshot
	local currentPreviewState: PreviewState? = nil
	local currentRotationQuarterTurns: PlacementRotationQuarterTurns = 0
	local currentRotationItemId: ItemId? = nil

	hudTooltip:hide(PLACEMENT_TOOLTIP_OWNER_ID)
	mobileRotateButton.Visible = false

	local function resetRotationState()
		currentRotationQuarterTurns = 0
		currentRotationItemId = nil
	end

	local function rotateCurrentPlaceable(): boolean
		if StructureActionMode.getMode() ~= "None" then
			return false
		end

		if UserInputService:GetFocusedTextBox() ~= nil then
			return false
		end

		local snapshot = latestSnapshot
		if snapshot == nil then
			return false
		end

		local _, itemDefinition = getEquippedPlaceableItem(snapshot)
		if not isRotatablePlaceableItem(itemDefinition) then
			return false
		end

		currentRotationQuarterTurns = PlotMath.normalizeRotationQuarterTurns(currentRotationQuarterTurns + 1)
		currentRotationItemId = itemDefinition.id
		return true
	end

	InventoryController.observeSnapshotChanged(function(snapshot: InventorySnapshot)
		latestSnapshot = snapshot
	end)

	plotExpansionRemotes.plotExpansionUpdated.OnClientEvent:Connect(function(snapshot: PlotExpansionSnapshot)
		latestPlotExpansionSnapshot = snapshot
	end)

	local function requestCurrentPlacement(): boolean
		if StructureActionMode.getMode() ~= "None" then
			return false
		end

		if UserInputService:GetFocusedTextBox() ~= nil then
			return false
		end

		local snapshot = latestSnapshot
		if snapshot == nil then
			return false
		end

		local _, itemDefinition = getEquippedPlaceableItem(snapshot)
		local plot = getAssignedPlot()
		if itemDefinition == nil or plot == nil then
			return false
		end

		local previewState = currentPreviewState
		if previewState == nil or not previewState.isValid then
			return false
		end

		local buildingDefinition = BuildingCatalog.getBuildingDefinition(itemDefinition.id)
		local placementFootprint = PlotMath.getRotatedFootprint(
			BuildingAssetUtils.getPlacementFootprint(buildingDefinition),
			previewState.rotationQuarterTurns
		)

		local placementGrid = {
			x = previewState.gridX,
			z = previewState.gridZ,
		}

		if isGridOccupied(plot.Name, placementFootprint, placementGrid) then
			return false
		end

		placementRemotes.requestPlacement:FireServer(placementGrid.x, placementGrid.z, previewState.rotationQuarterTurns)
		return true
	end

	RunService.RenderStepped:Connect(function()
		if StructureActionMode.getMode() ~= "None" then
			previewView:hide()
			currentPreviewState = nil
			resetRotationState()
			hudTooltip:hide(PLACEMENT_TOOLTIP_OWNER_ID)
			mobileRotateButton.Visible = false
			return
		end

		local snapshot = latestSnapshot
		if snapshot == nil then
			previewView:hide()
			currentPreviewState = nil
			resetRotationState()
			hudTooltip:hide(PLACEMENT_TOOLTIP_OWNER_ID)
			mobileRotateButton.Visible = false
			return
		end

		local _, itemDefinition = getEquippedPlaceableItem(snapshot)
		if itemDefinition == nil then
			previewView:hide()
			currentPreviewState = nil
			resetRotationState()
			hudTooltip:hide(PLACEMENT_TOOLTIP_OWNER_ID)
			mobileRotateButton.Visible = false
			return
		end
		if isRotatablePlaceableItem(itemDefinition) then
			if currentRotationItemId ~= itemDefinition.id then
				currentRotationQuarterTurns = 0
				currentRotationItemId = itemDefinition.id
			end
		else
			resetRotationState()
		end
		mobileRotateButton.Visible = ClientInputProfile.usesTouchControls() and isRotatablePlaceableItem(itemDefinition)
		hudTooltip:show(getPlacementTooltipTextForItem(itemDefinition), false, PLACEMENT_TOOLTIP_OWNER_ID)

		local buildingDefinition = BuildingCatalog.getBuildingDefinition(itemDefinition.id)
		local placementFootprint = PlotMath.getRotatedFootprint(
			BuildingAssetUtils.getPlacementFootprint(buildingDefinition),
			currentRotationQuarterTurns
		)

		local plot = getAssignedPlot()
		local plotBase = if plot == nil then nil else PlotLocator.getPlacementBase(plot)
		local spawnPart = if plot == nil then nil else PlotLocator.getSpawnPart(plot)
		if plot == nil or plotBase == nil or spawnPart == nil then
			previewView:hide()
			currentPreviewState = nil
			return
		end

		local placementWorldPosition: Vector3?
		if ClientInputProfile.usesTouchControls() then
			placementWorldPosition = getMobilePlacementWorldPosition()
		else
			local raycastResult = getPlotRaycastResult(plotBase)
			if raycastResult == nil then
				previewView:hide()
				currentPreviewState = nil
				return
			end

			placementWorldPosition = raycastResult.Position
		end

		if placementWorldPosition == nil then
			previewView:hide()
			currentPreviewState = nil
			return
		end

		local grid = PlotMath.worldPositionToGrid(plotBase.CFrame, plotBase.Size, placementFootprint, placementWorldPosition)
		if grid == nil then
			previewView:hide()
			currentPreviewState = nil
			return
		end

		local placementCFrame = PlotMath.gridToWorldCFrame(
			plotBase.CFrame,
			plotBase.Size,
			placementFootprint,
			grid.x,
			grid.z,
			currentRotationQuarterTurns
		)
		if placementCFrame == nil then
			previewView:hide()
			currentPreviewState = nil
			return
		end

		local isValid = isFootprintUnlocked(plotBase, spawnPart, placementFootprint, grid, latestPlotExpansionSnapshot)
			and not isGridOccupied(plot.Name, placementFootprint, grid)
		previewView:show(buildingDefinition, itemDefinition, placementCFrame, isValid)
		currentPreviewState = {
			gridX = grid.x,
			gridZ = grid.z,
			rotationQuarterTurns = currentRotationQuarterTurns,
			isValid = isValid,
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

		if inputObject.KeyCode == Enum.KeyCode.R then
			rotateCurrentPlaceable()
			return
		end

		if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1
			and inputObject.KeyCode ~= Enum.KeyCode.ButtonR2 then
			return
		end

		requestCurrentPlacement()
	end)

	mobileRotateButton.Activated:Connect(function()
		rotateCurrentPlaceable()
	end)

	UserInputService.TouchTap:Connect(function(_touchPositions: { Vector2 }, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if not ClientInputProfile.usesTouchControls() then
			return
		end

		requestCurrentPlacement()
	end)
end

return table.freeze(PlacementController)

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before starting plot grid")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local plotsFolder = sharedFolder:WaitForChild("Plots") :: Folder

local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local InventoryUtils = require(inventoryFolder:WaitForChild("InventoryUtils") :: ModuleScript)
local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local PlotLocator = require(plotsFolder:WaitForChild("PlotLocator") :: ModuleScript)
local InventoryController = require(script.Parent.Parent.Inventory.InventoryController)
local StructureActionMode = require(script.Parent.StructureActionMode)

type InventorySnapshot = InventoryTypes.InventorySnapshot
type StructureActionModeId = StructureActionMode.StructureActionModeId
type GridTextureCallback = (Texture) -> ()

local GRID_TEXTURE_NAME = "Grid"
local HIDDEN_GRID_TRANSPARENCY = 1
local PULSE_START_TRANSPARENCY = 0.8
local PULSE_END_TRANSPARENCY = 0.6
local PULSE_HALF_DURATION_SECONDS = 1.4

local PULSE_TWEEN_INFO = TweenInfo.new(
	PULSE_HALF_DURATION_SECONDS,
	Enum.EasingStyle.Sine,
	Enum.EasingDirection.InOut,
	-1,
	true
)

local hasStarted = false
local latestSnapshot: InventorySnapshot? = nil
local currentMode: StructureActionModeId = "None"
local activeGridTexture: Texture? = nil
local activeGridTween: Tween? = nil
local connections: { RBXScriptConnection } = {}
local disconnectModeObserver: (() -> ())? = nil

local function getWorkspacePlotsFolder(): Folder?
	local workspacePlotsFolder = Workspace:FindFirstChild(PlotLocator.PLOTS_FOLDER_NAME)
	if workspacePlotsFolder == nil or not workspacePlotsFolder:IsA("Folder") then
		return nil
	end

	return workspacePlotsFolder
end

local function getGridTextureForPlot(plot: Instance): Texture?
	local plotBase = PlotLocator.getPlacementBase(plot)
	if plotBase == nil then
		return nil
	end

	local gridTexture = plotBase:FindFirstChild(GRID_TEXTURE_NAME)
	if gridTexture == nil or not gridTexture:IsA("Texture") then
		return nil
	end

	return gridTexture
end

local function forEachGridTexture(callback: GridTextureCallback)
	local workspacePlotsFolder = getWorkspacePlotsFolder()
	if workspacePlotsFolder == nil then
		return
	end

	for _, plot in ipairs(PlotLocator.getAllPlots(workspacePlotsFolder)) do
		local gridTexture = getGridTextureForPlot(plot)
		if gridTexture ~= nil then
			callback(gridTexture)
		end
	end
end

local function stopActivePulse()
	local gridTween = activeGridTween
	if gridTween ~= nil then
		gridTween:Cancel()
		activeGridTween = nil
	end
end

local function hideGridTexture(gridTexture: Texture)
	gridTexture.Transparency = HIDDEN_GRID_TRANSPARENCY
end

local function hideAllGridTextures()
	forEachGridTexture(hideGridTexture)
end

local function hideInactiveGridTextures(currentActiveGridTexture: Texture)
	forEachGridTexture(function(gridTexture: Texture)
		if gridTexture ~= currentActiveGridTexture then
			hideGridTexture(gridTexture)
		end
	end)
end

local function clearActiveGridTexture()
	stopActivePulse()

	local gridTexture = activeGridTexture
	if gridTexture ~= nil then
		hideGridTexture(gridTexture)
		activeGridTexture = nil
	end
end

local function hasSelectedPlaceableItem(): boolean
	local snapshot = latestSnapshot
	if snapshot == nil then
		return false
	end

	local selectedItemId = InventoryUtils.getSelectedItemId(snapshot)
	if selectedItemId == nil or not ItemCatalog.hasItemDefinition(selectedItemId) then
		return false
	end

	return ItemCatalog.getItemDefinition(selectedItemId).kind == "Placeable"
end

local function shouldShowGrid(): boolean
	if currentMode == "Pickup" or currentMode == "Sell" then
		return true
	end

	return currentMode == "None" and hasSelectedPlaceableItem()
end

local function getAssignedGridTexture(): Texture?
	local workspacePlotsFolder = getWorkspacePlotsFolder()
	if workspacePlotsFolder == nil then
		return nil
	end

	local assignedPlot = PlotLocator.getAssignedPlot(workspacePlotsFolder, localPlayer)
	if assignedPlot == nil then
		return nil
	end

	return getGridTextureForPlot(assignedPlot)
end

local function startPulse(gridTexture: Texture)
	gridTexture.Transparency = PULSE_START_TRANSPARENCY

	local tween = TweenService:Create(gridTexture, PULSE_TWEEN_INFO, {
		Transparency = PULSE_END_TRANSPARENCY,
	})
	activeGridTween = tween
	tween:Play()
end

local function refreshGridVisibility()
	if not shouldShowGrid() then
		clearActiveGridTexture()
		hideAllGridTextures()
		return
	end

	local assignedGridTexture = getAssignedGridTexture()
	if assignedGridTexture == nil then
		clearActiveGridTexture()
		hideAllGridTextures()
		return
	end

	hideInactiveGridTextures(assignedGridTexture)

	if activeGridTexture == assignedGridTexture and activeGridTween ~= nil then
		return
	end

	clearActiveGridTexture()
	activeGridTexture = assignedGridTexture
	startPulse(assignedGridTexture)
end

local PlotGridController = {}

function PlotGridController.start()
	if hasStarted then
		return
	end

	hasStarted = true
	latestSnapshot = InventoryController.getLatestSnapshot()
	currentMode = StructureActionMode.getMode()

	hideAllGridTextures()
	refreshGridVisibility()

	InventoryController.observeSnapshotChanged(function(snapshot: InventorySnapshot)
		if not hasStarted then
			return
		end

		latestSnapshot = snapshot
		refreshGridVisibility()
	end)

	disconnectModeObserver = StructureActionMode.observeModeChanged(function(mode: StructureActionModeId)
		currentMode = mode
		refreshGridVisibility()
	end)

	table.insert(
		connections,
		localPlayer:GetAttributeChangedSignal(PlotLocator.PlayerAttributes.assignedPlotName):Connect(refreshGridVisibility)
	)
	table.insert(
		connections,
		localPlayer:GetAttributeChangedSignal(PlotLocator.PlayerAttributes.plotSlot):Connect(refreshGridVisibility)
	)

	local workspacePlotsFolder = getWorkspacePlotsFolder()
	if workspacePlotsFolder ~= nil then
		table.insert(connections, workspacePlotsFolder.ChildAdded:Connect(function(_child: Instance)
			refreshGridVisibility()
		end))
		table.insert(connections, workspacePlotsFolder.ChildRemoved:Connect(function(_child: Instance)
			refreshGridVisibility()
		end))
	end
end

function PlotGridController.destroy()
	if not hasStarted then
		return
	end

	hasStarted = false

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)

	if disconnectModeObserver ~= nil then
		disconnectModeObserver()
		disconnectModeObserver = nil
	end

	clearActiveGridTexture()
	hideAllGridTextures()
end

return table.freeze(PlotGridController)

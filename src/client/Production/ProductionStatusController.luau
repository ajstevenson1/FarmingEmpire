--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before starting ProductionStatusController")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local plotsFolder = sharedFolder:WaitForChild("Plots") :: Folder
local progressionFolder = sharedFolder:WaitForChild("Progression") :: Folder
local windmillsFolder = sharedFolder:WaitForChild("Windmills") :: Folder

local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local PlotLocator = require(plotsFolder:WaitForChild("PlotLocator") :: ModuleScript)
local ProgressionConfig = require(progressionFolder:WaitForChild("ProgressionConfig") :: ModuleScript)
local WindmillConfig = require(windmillsFolder:WaitForChild("WindmillConfig") :: ModuleScript)
local AppleCounterBillboardView = require(script.Parent.AppleCounterBillboardView)
local CiderCounterBillboardView = require(script.Parent.CiderCounterBillboardView)
local AutoCiderPassController = require(script.Parent.Parent.Monetization.AutoCiderPassController)
local ProductionBillboardView = require(script.Parent.ProductionBillboardView)
local WindmillBillboardView = require(script.Parent.WindmillBillboardView)

type AppleCounterBillboardViewInstance = AppleCounterBillboardView.AppleCounterBillboardView
type CiderCounterBillboardViewInstance = CiderCounterBillboardView.CiderCounterBillboardView
type ProductionBillboardViewInstance = ProductionBillboardView.ProductionBillboardView
type WindmillBillboardViewInstance = WindmillBillboardView.WindmillBillboardView
type ProductionViewInstance =
	AppleCounterBillboardViewInstance
	| CiderCounterBillboardViewInstance
	| ProductionBillboardViewInstance
	| WindmillBillboardViewInstance

type TrackedConnections = {
	refreshConnections: { RBXScriptConnection },
	ancestryConnection: RBXScriptConnection,
}

local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
local PLOT_NAME_ATTRIBUTE = "PlotName"

local trackedViewsByPart: { [BasePart]: ProductionViewInstance } = {}
local trackedConnectionsByPart: { [BasePart]: TrackedConnections } = {}
local hasStarted = false

local function getAssignedPlotName(): string?
	local assignedPlotName = localPlayer:GetAttribute(PlotLocator.PlayerAttributes.assignedPlotName)
	return if type(assignedPlotName) == "string" then assignedPlotName else nil
end

local function isOwnedPartOnAssignedPlot(part: BasePart): boolean
	if part:GetAttribute(OWNER_USER_ID_ATTRIBUTE) ~= localPlayer.UserId then
		return false
	end

	local assignedPlotName = getAssignedPlotName()
	return assignedPlotName ~= nil and part:GetAttribute(PLOT_NAME_ATTRIBUTE) == assignedPlotName
end

local function destroyTrackedView(part: BasePart)
	local existingView = trackedViewsByPart[part]
	if existingView ~= nil then
		existingView:destroy()
		trackedViewsByPart[part] = nil
	end

	local existingConnections = trackedConnectionsByPart[part]
	if existingConnections ~= nil then
		for _, connection in ipairs(existingConnections.refreshConnections) do
			connection:Disconnect()
		end

		existingConnections.ancestryConnection:Disconnect()
		trackedConnectionsByPart[part] = nil
	end
end

local function shouldTrackPart(part: BasePart): boolean
	local buildingId = part:GetAttribute(BuildingAttributeNames.buildingId)
	return type(buildingId) == "string" and isOwnedPartOnAssignedPlot(part)
end

local function shouldUseAppleCounter(part: BasePart): boolean
	local buildingId = part:GetAttribute(BuildingAttributeNames.buildingId)
	return type(buildingId) == "string" and ProgressionConfig.isTreeBuildingId(buildingId)
end

local function shouldUseCiderCounter(part: BasePart): boolean
	local buildingId = part:GetAttribute(BuildingAttributeNames.buildingId)
	return type(buildingId) == "string" and ProgressionConfig.isMillBuildingId(buildingId)
end

local function applyAutoCiderStateToView(part: BasePart, view: ProductionViewInstance)
	if shouldUseCiderCounter(part) then
		(view :: CiderCounterBillboardViewInstance):setCountVisible(not AutoCiderPassController.isAutoCiderEnabled())
	end
end

local function shouldUseWindmillBillboard(part: BasePart): boolean
	local buildingId = part:GetAttribute(BuildingAttributeNames.buildingId)
	return type(buildingId) == "string" and WindmillConfig.isWindmillBuildingId(buildingId)
end

local function createView(part: BasePart): ProductionViewInstance
	if shouldUseAppleCounter(part) then
		return AppleCounterBillboardView.new(part)
	end

	if shouldUseCiderCounter(part) then
		return CiderCounterBillboardView.new(part)
	end

	if shouldUseWindmillBillboard(part) then
		return WindmillBillboardView.new(part)
	end

	return ProductionBillboardView.new(part)
end

local trackPart: ((BasePart) -> ())? = nil

local function refreshPartTracking(part: BasePart)
	if shouldTrackPart(part) then
		local currentTrackPart = trackPart
		if currentTrackPart ~= nil then
			currentTrackPart(part)
		end
	else
		destroyTrackedView(part)
	end
end

trackPart = function(part: BasePart)
	if trackedViewsByPart[part] ~= nil then
		return
	end

	if not shouldTrackPart(part) then
		return
	end

	local view = createView(part)
	trackedViewsByPart[part] = view
	applyAutoCiderStateToView(part, view)

	local refreshConnections = {
		part:GetAttributeChangedSignal(BuildingAttributeNames.productionStoredAmount):Connect(function()
			view:refresh()
		end),
		part:GetAttributeChangedSignal(BuildingAttributeNames.productionStorageCap):Connect(function()
			view:refresh()
		end),
		part:GetAttributeChangedSignal(BuildingAttributeNames.productionMultiplier):Connect(function()
			view:refresh()
		end),
		part:GetAttributeChangedSignal(BuildingAttributeNames.productionRatePerSecond):Connect(function()
			view:refresh()
		end),
		part:GetAttributeChangedSignal(BuildingAttributeNames.productionProgress):Connect(function()
			view:refresh()
		end),
		part:GetAttributeChangedSignal(BuildingAttributeNames.productionStatusText):Connect(function()
			view:refresh()
		end),
		part:GetAttributeChangedSignal(BuildingAttributeNames.productionState):Connect(function()
			view:refresh()
		end),
		part:GetAttributeChangedSignal(BuildingAttributeNames.buildingId):Connect(function()
			refreshPartTracking(part)
		end),
		part:GetAttributeChangedSignal(OWNER_USER_ID_ATTRIBUTE):Connect(function()
			refreshPartTracking(part)
		end),
		part:GetAttributeChangedSignal(PLOT_NAME_ATTRIBUTE):Connect(function()
			refreshPartTracking(part)
		end),
	}

	local ancestryConnection = part.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			destroyTrackedView(part)
		end
	end)

	trackedConnectionsByPart[part] = {
		refreshConnections = refreshConnections,
		ancestryConnection = ancestryConnection,
	}

	task.defer(function()
		if trackedViewsByPart[part] == view then
			view:refresh()
			applyAutoCiderStateToView(part, view)
		end
	end)
end

local function connectPartForDeferredTracking(part: BasePart)
	if shouldTrackPart(part) then
		trackPart(part)
		return
	end

	local connections: { RBXScriptConnection } = {}
	local function disconnectConnections()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end

		table.clear(connections)
	end

	local function tryTrack()
		if shouldTrackPart(part) then
			disconnectConnections()
			trackPart(part)
		end
	end

	table.insert(connections, part:GetAttributeChangedSignal(BuildingAttributeNames.buildingId):Connect(tryTrack))
	table.insert(connections, part:GetAttributeChangedSignal(OWNER_USER_ID_ATTRIBUTE):Connect(tryTrack))
	table.insert(connections, part:GetAttributeChangedSignal(PLOT_NAME_ATTRIBUTE):Connect(tryTrack))

	part.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			disconnectConnections()
		end
	end)
end

local function getPlacedObjectsFolder(): Folder
	local existingFolder = Workspace:WaitForChild(PLACED_OBJECTS_FOLDER_NAME)
	assert(existingFolder:IsA("Folder"), string.format("%s must be a Folder", PLACED_OBJECTS_FOLDER_NAME))
	return existingFolder
end

local function refreshTrackedViewsForAutoCiderEnabled()
	local placedObjectsFolder = getPlacedObjectsFolder()
	for _, child in ipairs(placedObjectsFolder:GetChildren()) do
		if not child:IsA("BasePart") then
			continue
		end

		local existingView = trackedViewsByPart[child]
		if existingView ~= nil then
			if shouldTrackPart(child) then
				applyAutoCiderStateToView(child, existingView)
			else
				destroyTrackedView(child)
			end
		elseif shouldTrackPart(child) then
			trackPart(child)
		end
	end
end

local function refreshAllPlacedParts()
	local placedObjectsFolder = getPlacedObjectsFolder()
	for _, child in ipairs(placedObjectsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			refreshPartTracking(child)
		end
	end
end

local ProductionStatusController = {}

function ProductionStatusController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local placedObjectsFolder = getPlacedObjectsFolder()

	for _, child in ipairs(placedObjectsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			connectPartForDeferredTracking(child)
		end
	end

	placedObjectsFolder.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			connectPartForDeferredTracking(child)
		end
	end)

	placedObjectsFolder.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") then
			destroyTrackedView(child)
		end
	end)

	AutoCiderPassController.observeEnabledChanged(function(_isAutoCiderEnabled: boolean)
		refreshTrackedViewsForAutoCiderEnabled()
	end)

	localPlayer:GetAttributeChangedSignal(PlotLocator.PlayerAttributes.assignedPlotName):Connect(refreshAllPlacedParts)
end

return table.freeze(ProductionStatusController)

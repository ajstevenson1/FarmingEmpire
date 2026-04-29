--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local ProductionBillboardView = require(script.Parent.ProductionBillboardView)

type ProductionBillboardViewInstance = ProductionBillboardView.ProductionBillboardView

type TrackedConnections = {
	refreshConnections: { RBXScriptConnection },
	ancestryConnection: RBXScriptConnection,
}

local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"

local trackedViewsByPart: { [BasePart]: ProductionBillboardViewInstance } = {}
local trackedConnectionsByPart: { [BasePart]: TrackedConnections } = {}
local hasStarted = false

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
	return type(buildingId) == "string"
end

local function trackPart(part: BasePart)
	if trackedViewsByPart[part] ~= nil then
		return
	end

	if not shouldTrackPart(part) then
		return
	end

	local view = ProductionBillboardView.new(part)
	trackedViewsByPart[part] = view

	local refreshConnections = {
		part:GetAttributeChangedSignal(BuildingAttributeNames.productionProgress):Connect(function()
			view:refresh()
		end),
		part:GetAttributeChangedSignal(BuildingAttributeNames.productionStatusText):Connect(function()
			view:refresh()
		end),
		part:GetAttributeChangedSignal(BuildingAttributeNames.productionState):Connect(function()
			view:refresh()
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
end

local function connectPartForDeferredTracking(part: BasePart)
	if shouldTrackPart(part) then
		trackPart(part)
		return
	end

	local attributeConnection: RBXScriptConnection? = nil
	attributeConnection = part:GetAttributeChangedSignal(BuildingAttributeNames.buildingId):Connect(function()
		if shouldTrackPart(part) then
			if attributeConnection ~= nil then
				attributeConnection:Disconnect()
			end

			trackPart(part)
		end
	end)

	part.AncestryChanged:Connect(function(_, parent)
		if parent == nil and attributeConnection ~= nil then
			attributeConnection:Disconnect()
		end
	end)
end

local function getPlacedObjectsFolder(): Folder?
	local existingFolder = Workspace:FindFirstChild(PLACED_OBJECTS_FOLDER_NAME)
	if existingFolder == nil then
		return nil
	end

	assert(existingFolder:IsA("Folder"), string.format("%s must be a Folder", PLACED_OBJECTS_FOLDER_NAME))
	return existingFolder
end

local ProductionStatusController = {}

function ProductionStatusController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local placedObjectsFolder = getPlacedObjectsFolder()
	if placedObjectsFolder == nil then
		return
	end

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
end

return table.freeze(ProductionStatusController)

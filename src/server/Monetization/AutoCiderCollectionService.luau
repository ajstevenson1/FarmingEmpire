--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local monetizationFolder = sharedFolder:WaitForChild("Monetization") :: Folder

local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local GamePassConfig = require(monetizationFolder:WaitForChild("GamePassConfig") :: ModuleScript)
local GamePassOwnershipService = require(script.Parent.GamePassOwnershipService)
local PlotService = require(script.Parent.Parent.Plots.PlotService)
local ProductionService = require(script.Parent.Parent.Production.ProductionService)
local ResourceService = require(script.Parent.Parent.Resources.ResourceService)

local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
local PLOT_NAME_ATTRIBUTE = "PlotName"
local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local INPUT_PROCESSOR_BEHAVIOR_ID = "InputProcessor"
local CIDER_RESOURCE_ID = "Cider"
local COLLECTION_INTERVAL_SECONDS = 1

local trackedCiderMillParts: { [BasePart]: boolean } = {}
local trackedConnectionsByPart: { [BasePart]: { RBXScriptConnection } } = {}
local hasStarted = false

local function getPlacedObjectsFolder(): Folder
	local existingFolder = Workspace:WaitForChild(PLACED_OBJECTS_FOLDER_NAME)
	assert(existingFolder:IsA("Folder"), string.format("%s must be a Folder", PLACED_OBJECTS_FOLDER_NAME))
	return existingFolder
end

local function getStoredAmount(part: BasePart): number
	local value = part:GetAttribute(BuildingAttributeNames.productionStoredAmount)
	return if type(value) == "number" then math.max(0, math.floor(value)) else 0
end

local function shouldTrackPart(part: BasePart): boolean
	local productionBehaviorId = part:GetAttribute(BuildingAttributeNames.productionBehaviorId)
	local outputResourceId = part:GetAttribute(BuildingAttributeNames.productionOutputName)

	return productionBehaviorId == INPUT_PROCESSOR_BEHAVIOR_ID and outputResourceId == CIDER_RESOURCE_ID
end

local function refreshTrackedPart(part: BasePart)
	if shouldTrackPart(part) then
		trackedCiderMillParts[part] = true
	else
		trackedCiderMillParts[part] = nil
	end
end

local function clearTrackedPart(part: BasePart)
	trackedCiderMillParts[part] = nil

	local connections = trackedConnectionsByPart[part]
	if connections == nil then
		return
	end

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end

	trackedConnectionsByPart[part] = nil
end

local function connectPartForTracking(part: BasePart)
	if trackedConnectionsByPart[part] ~= nil then
		refreshTrackedPart(part)
		return
	end

	refreshTrackedPart(part)

	trackedConnectionsByPart[part] = {
		part:GetAttributeChangedSignal(BuildingAttributeNames.productionBehaviorId):Connect(function()
			refreshTrackedPart(part)
		end),
		part:GetAttributeChangedSignal(BuildingAttributeNames.productionOutputName):Connect(function()
			refreshTrackedPart(part)
		end),
		part.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				clearTrackedPart(part)
			end
		end),
	}
end

local function isOwnedPartOnAssignedPlot(player: Player, assignedPlotName: string, part: BasePart): boolean
	return part:GetAttribute(OWNER_USER_ID_ATTRIBUTE) == player.UserId and part:GetAttribute(PLOT_NAME_ATTRIBUTE) == assignedPlotName
end

local function playerOwnsAutoCiderPass(player: Player): boolean
	local definition = GamePassConfig.getAutoCiderDefinition()
	return GamePassOwnershipService.playerOwnsGamePass(player, definition.gamePassId)
end

local function collectCiderForPlayer(player: Player)
	if not playerOwnsAutoCiderPass(player) then
		return
	end

	local assignedPlotName = PlotService.getAssignedPlotName(player)
	if assignedPlotName == nil then
		return
	end

	for part in pairs(trackedCiderMillParts) do
		if part.Parent == nil then
			trackedCiderMillParts[part] = nil
			continue
		end

		if getStoredAmount(part) <= 0 or not isOwnedPartOnAssignedPlot(player, assignedPlotName, part) then
			continue
		end

		local didHarvest, harvestOutput = ProductionService.tryHarvestPlacedBuilding(part)
		if didHarvest and harvestOutput ~= nil and harvestOutput.resourceId == CIDER_RESOURCE_ID then
			ResourceService.addResource(player, harvestOutput.resourceId, harvestOutput.amount)
		end
	end
end

local function registerExistingParts()
	local placedObjectsFolder = getPlacedObjectsFolder()

	for _, child in ipairs(placedObjectsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			connectPartForTracking(child)
		end
	end

	placedObjectsFolder.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			connectPartForTracking(child)
		end
	end)

	placedObjectsFolder.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") then
			clearTrackedPart(child)
		end
	end)
end

local function startCollectionLoop()
	task.spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				collectCiderForPlayer(player)
			end

			task.wait(COLLECTION_INTERVAL_SECONDS)
		end
	end)
end

local AutoCiderCollectionService = {}

function AutoCiderCollectionService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	task.spawn(registerExistingParts)
	startCollectionLoop()
end

return table.freeze(AutoCiderCollectionService)

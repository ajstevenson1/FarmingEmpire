--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local ProductionBehaviorRegistry = require(script.Parent.ProductionBehaviorRegistry)

type BuildingDefinition = BuildingTypes.BuildingDefinition
type BuildingId = BuildingTypes.BuildingId
type RuntimeState = require(script.Parent.Behaviors.GrowAndHarvestBehavior).RuntimeState

type TrackedBuilding = {
	part: BasePart,
	buildingDefinition: BuildingDefinition,
	runtimeState: RuntimeState,
}

local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local ITEM_ID_ATTRIBUTE = "ItemId"
local UPDATE_INTERVAL_SECONDS = 0.25

local trackedBuildingsByPart: { [BasePart]: TrackedBuilding } = {}
local hasStarted = false

local function getPlacedObjectsFolder(): Folder?
	local existingFolder = Workspace:FindFirstChild(PLACED_OBJECTS_FOLDER_NAME)
	if existingFolder == nil then
		return nil
	end

	assert(existingFolder:IsA("Folder"), string.format("%s must be a Folder", PLACED_OBJECTS_FOLDER_NAME))
	return existingFolder
end

local function getCurrentTime(): number
	return Workspace:GetServerTimeNow()
end

local function syncPartAttributes(trackedBuilding: TrackedBuilding)
	local part = trackedBuilding.part
	local buildingDefinition = trackedBuilding.buildingDefinition
	local productionConfig = buildingDefinition.productionConfig
	local runtimeState = trackedBuilding.runtimeState

	part:SetAttribute(BuildingAttributeNames.buildingId, buildingDefinition.id)
	part:SetAttribute(BuildingAttributeNames.buildingDisplayName, buildingDefinition.displayName)
	part:SetAttribute(BuildingAttributeNames.productionBehaviorId, productionConfig.behaviorId)
	part:SetAttribute(BuildingAttributeNames.productionState, runtimeState.state)
	part:SetAttribute(BuildingAttributeNames.productionProgress, runtimeState.progress)
	part:SetAttribute(BuildingAttributeNames.productionTimeLeft, runtimeState.timeLeft)
	part:SetAttribute(BuildingAttributeNames.productionStatusText, runtimeState.statusText)
	part:SetAttribute(BuildingAttributeNames.productionDuration, productionConfig.cycleDurationSeconds)
	part:SetAttribute(BuildingAttributeNames.productionOutputName, productionConfig.outputResourceName)
	part:SetAttribute(BuildingAttributeNames.productionStoredAmount, runtimeState.storedAmount)
	part:SetAttribute(BuildingAttributeNames.productionStorageCap, productionConfig.storageCap)
	part:SetAttribute(BuildingAttributeNames.isReadyToHarvest, runtimeState.isReadyToHarvest)
end

local function createTrackedBuilding(part: BasePart, buildingDefinition: BuildingDefinition): TrackedBuilding
	local behavior = ProductionBehaviorRegistry.getBehavior(buildingDefinition.productionConfig.behaviorId)
	assert(behavior ~= nil, string.format("No production behavior registered for %s", buildingDefinition.productionConfig.behaviorId))

	local runtimeState = behavior.createRuntimeState(buildingDefinition.productionConfig, getCurrentTime()) :: RuntimeState
	local trackedBuilding: TrackedBuilding = {
		part = part,
		buildingDefinition = buildingDefinition,
		runtimeState = runtimeState,
	}

	syncPartAttributes(trackedBuilding)

	return trackedBuilding
end

local function updateTrackedBuilding(trackedBuilding: TrackedBuilding)
	local behavior = ProductionBehaviorRegistry.getBehavior(trackedBuilding.buildingDefinition.productionConfig.behaviorId)
	assert(behavior ~= nil, string.format("No production behavior registered for %s", trackedBuilding.buildingDefinition.productionConfig.behaviorId))

	trackedBuilding.runtimeState = behavior.updateRuntimeState(
		trackedBuilding.runtimeState,
		trackedBuilding.buildingDefinition.productionConfig,
		getCurrentTime()
	) :: RuntimeState

	syncPartAttributes(trackedBuilding)
end

local function startUpdateLoop()
	task.spawn(function()
		while true do
			for part, trackedBuilding in pairs(trackedBuildingsByPart) do
				if part.Parent == nil then
					trackedBuildingsByPart[part] = nil
				else
					updateTrackedBuilding(trackedBuilding)
				end
			end

			task.wait(UPDATE_INTERVAL_SECONDS)
		end
	end)
end

local function registerExistingPlacedBuildings()
	local placedObjectsFolder = getPlacedObjectsFolder()
	if placedObjectsFolder == nil then
		return
	end

	for _, child in ipairs(placedObjectsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			local itemId = child:GetAttribute(ITEM_ID_ATTRIBUTE)
			if type(itemId) == "string" and BuildingCatalog.hasBuildingDefinition(itemId) then
				local buildingId = itemId :: BuildingId
				if trackedBuildingsByPart[child] == nil then
					trackedBuildingsByPart[child] = createTrackedBuilding(child, BuildingCatalog.getBuildingDefinition(buildingId))
				end
			end
		end
	end
end

local ProductionService = {}

function ProductionService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	registerExistingPlacedBuildings()
	startUpdateLoop()
end

function ProductionService.registerPlacedBuilding(part: BasePart, buildingId: BuildingId)
	local buildingDefinition = BuildingCatalog.getBuildingDefinition(buildingId)
	trackedBuildingsByPart[part] = createTrackedBuilding(part, buildingDefinition)
end

return table.freeze(ProductionService)

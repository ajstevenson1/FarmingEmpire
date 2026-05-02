--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local BuildingVisualService = require(script.Parent.Parent.Buildings.BuildingVisualService)
local ProductionBehaviorRegistry = require(script.Parent.ProductionBehaviorRegistry)
local ResourceService = require(script.Parent.Parent.Resources.ResourceService)

type BuildingDefinition = BuildingTypes.BuildingDefinition
type BuildingId = BuildingTypes.BuildingId
type GrowthVisualStage = BuildingTypes.GrowthVisualStage
type HarvestOutput = BuildingTypes.HarvestOutput
type ProductionBehavior = BuildingTypes.ProductionBehavior
type ProductionBehaviorContext = BuildingTypes.ProductionBehaviorContext
type ProductionRuntimeState = BuildingTypes.ProductionRuntimeState

type TrackedBuilding = {
	part: BasePart,
	buildingDefinition: BuildingDefinition,
	runtimeState: ProductionRuntimeState,
	currentGrowthStageName: string,
}

local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local ITEM_ID_ATTRIBUTE = "ItemId"
local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
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

local function getOwnerPlayer(part: BasePart): Player?
	local ownerUserId = part:GetAttribute(OWNER_USER_ID_ATTRIBUTE)
	if type(ownerUserId) ~= "number" then
		return nil
	end

	return Players:GetPlayerByUserId(ownerUserId)
end

local function getProductionBehavior(buildingDefinition: BuildingDefinition): ProductionBehavior
	local behavior = ProductionBehaviorRegistry.getBehavior(buildingDefinition.productionConfig.behaviorId)
	assert(behavior ~= nil, string.format("No production behavior registered for %s", buildingDefinition.productionConfig.behaviorId))
	return behavior
end

local function getBehaviorContext(part: BasePart): ProductionBehaviorContext
	return {
		currentTime = getCurrentTime(),
		ownerPlayer = getOwnerPlayer(part),
		getResourceAmount = ResourceService.getResourceAmount,
		tryConsumeResource = ResourceService.tryConsumeResource,
		addResource = ResourceService.addResource,
	}
end

local function getStorageCap(buildingDefinition: BuildingDefinition): number
	local productionConfig = buildingDefinition.productionConfig
	if productionConfig.behaviorId == "GrowAndHarvest" then
		return productionConfig.storageCap
	end

	return 0
end

local function getOutputResourceName(buildingDefinition: BuildingDefinition): string
	local productionConfig = buildingDefinition.productionConfig
	if productionConfig.behaviorId == "GrowAndHarvest" then
		return productionConfig.outputResourceId
	end

	return productionConfig.outputResourceId
end

local function syncPartAttributes(trackedBuilding: TrackedBuilding)
	local part = trackedBuilding.part
	local buildingDefinition = trackedBuilding.buildingDefinition
	local productionConfig = buildingDefinition.productionConfig
	local runtimeState = trackedBuilding.runtimeState
	local currentGrowthStage = BuildingCatalog.getGrowthStageForProgress(buildingDefinition, runtimeState.progress)

	part:SetAttribute(BuildingAttributeNames.buildingId, buildingDefinition.id)
	part:SetAttribute(BuildingAttributeNames.buildingDisplayName, buildingDefinition.displayName)
	part:SetAttribute(BuildingAttributeNames.productionBehaviorId, productionConfig.behaviorId)
	part:SetAttribute(BuildingAttributeNames.productionState, runtimeState.state)
	part:SetAttribute(BuildingAttributeNames.productionProgress, runtimeState.progress)
	part:SetAttribute(BuildingAttributeNames.productionTimeLeft, runtimeState.timeLeft)
	part:SetAttribute(BuildingAttributeNames.productionStatusText, runtimeState.statusText)
	part:SetAttribute(BuildingAttributeNames.productionDuration, productionConfig.cycleDurationSeconds)
	part:SetAttribute(BuildingAttributeNames.productionOutputName, getOutputResourceName(buildingDefinition))
	part:SetAttribute(BuildingAttributeNames.productionStoredAmount, runtimeState.storedAmount)
	part:SetAttribute(BuildingAttributeNames.productionStorageCap, getStorageCap(buildingDefinition))
	part:SetAttribute(BuildingAttributeNames.isReadyToHarvest, runtimeState.isReadyToHarvest)
	part:SetAttribute(BuildingAttributeNames.growthVisualStageName, currentGrowthStage.modelName)
end

local function getCurrentGrowthStage(buildingDefinition: BuildingDefinition, runtimeState: ProductionRuntimeState): GrowthVisualStage
	return BuildingCatalog.getGrowthStageForProgress(buildingDefinition, runtimeState.progress)
end

local function createTrackedBuilding(part: BasePart, buildingDefinition: BuildingDefinition): TrackedBuilding
	local behavior = getProductionBehavior(buildingDefinition)
	local runtimeState = behavior.createRuntimeState(buildingDefinition.productionConfig, getCurrentTime())
	local initialGrowthStage = getCurrentGrowthStage(buildingDefinition, runtimeState)
	local trackedBuilding: TrackedBuilding = {
		part = part,
		buildingDefinition = buildingDefinition,
		runtimeState = runtimeState,
		currentGrowthStageName = initialGrowthStage.modelName,
	}

	BuildingVisualService.setGrowthStageVisual(part, buildingDefinition.id, initialGrowthStage.modelName)
	syncPartAttributes(trackedBuilding)

	return trackedBuilding
end

local function updateTrackedBuilding(trackedBuilding: TrackedBuilding)
	local behavior = getProductionBehavior(trackedBuilding.buildingDefinition)
	trackedBuilding.runtimeState = behavior.updateRuntimeState(
		trackedBuilding.runtimeState,
		trackedBuilding.buildingDefinition.productionConfig,
		getBehaviorContext(trackedBuilding.part)
	)

	local nextGrowthStage = getCurrentGrowthStage(trackedBuilding.buildingDefinition, trackedBuilding.runtimeState)
	if nextGrowthStage.modelName ~= trackedBuilding.currentGrowthStageName then
		trackedBuilding.currentGrowthStageName = nextGrowthStage.modelName
		BuildingVisualService.setGrowthStageVisual(trackedBuilding.part, trackedBuilding.buildingDefinition.id, nextGrowthStage.modelName)
	end

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

function ProductionService.tryHarvestPlacedBuilding(part: BasePart): (boolean, HarvestOutput?)
	local trackedBuilding = trackedBuildingsByPart[part]
	if trackedBuilding == nil or not trackedBuilding.runtimeState.isReadyToHarvest then
		return false, nil
	end

	local behavior = getProductionBehavior(trackedBuilding.buildingDefinition)
	if behavior.harvest == nil then
		return false, nil
	end

	local nextRuntimeState, harvestOutput = behavior.harvest(
		trackedBuilding.runtimeState,
		trackedBuilding.buildingDefinition.productionConfig,
		getCurrentTime()
	)

	trackedBuilding.runtimeState = nextRuntimeState

	local nextGrowthStage = getCurrentGrowthStage(trackedBuilding.buildingDefinition, trackedBuilding.runtimeState)
	trackedBuilding.currentGrowthStageName = nextGrowthStage.modelName
	BuildingVisualService.setGrowthStageVisual(part, trackedBuilding.buildingDefinition.id, nextGrowthStage.modelName)
	syncPartAttributes(trackedBuilding)

	return true, harvestOutput
end

return table.freeze(ProductionService)

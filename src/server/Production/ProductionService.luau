--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)
local BuildingVisualService = require(script.Parent.Parent.Buildings.BuildingVisualService)
local PlotExpansionService = require(script.Parent.Parent.Plots.PlotExpansionService)
local PlotService = require(script.Parent.Parent.Plots.PlotService)
local ProductionBehaviorRegistry = require(script.Parent.ProductionBehaviorRegistry)
local ResourceService = require(script.Parent.Parent.Resources.ResourceService)

type BuildingDefinition = BuildingTypes.BuildingDefinition
type BuildingId = BuildingTypes.BuildingId
type GrowthVisualStage = BuildingTypes.GrowthVisualStage
type HarvestOutput = BuildingTypes.HarvestOutput
type ProductionBehavior = BuildingTypes.ProductionBehavior
type ProductionConfig = BuildingTypes.ProductionConfig
type ProductionBehaviorContext = BuildingTypes.ProductionBehaviorContext
type ProductionRuntimeState = BuildingTypes.ProductionRuntimeState
type ResourceId = ResourceTypes.ResourceId
type SavedProductionState = BuildingTypes.SavedProductionState

type TrackedBuilding = {
	part: BasePart,
	buildingDefinition: BuildingDefinition,
	effectiveProductionConfig: ProductionConfig,
	runtimeState: ProductionRuntimeState,
	currentGrowthStageName: string,
}

local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local ITEM_ID_ATTRIBUTE = "ItemId"
local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
local PLOT_NAME_ATTRIBUTE = "PlotName"
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

	local ownerPlayer = Players:GetPlayerByUserId(ownerUserId)
	if ownerPlayer == nil then
		return nil
	end

	local assignedPlotName = PlotService.getAssignedPlotName(ownerPlayer)
	if assignedPlotName == nil or part:GetAttribute(PLOT_NAME_ATTRIBUTE) ~= assignedPlotName then
		return nil
	end

	return ownerPlayer
end

local function getProductionBehavior(productionConfig: ProductionConfig): ProductionBehavior
	local behavior = ProductionBehaviorRegistry.getBehavior(productionConfig.behaviorId)
	assert(behavior ~= nil, string.format("No production behavior registered for %s", productionConfig.behaviorId))
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

local function getStorageCap(productionConfig: ProductionConfig): number
	if productionConfig.behaviorId == "GrowAndHarvest" or productionConfig.behaviorId == "TimedStorageProducer" then
		return productionConfig.storageCap
	end

	return 0
end

local function getOutputResourceName(productionConfig: ProductionConfig): string
	if productionConfig.behaviorId == "GrowAndHarvest" or productionConfig.behaviorId == "TimedStorageProducer" then
		return productionConfig.outputResourceId
	end

	return productionConfig.outputResourceId
end

local function getOutputResourceId(productionConfig: ProductionConfig): ResourceId
	if productionConfig.behaviorId == "GrowAndHarvest" or productionConfig.behaviorId == "TimedStorageProducer" then
		return productionConfig.outputResourceId
	end

	return productionConfig.outputResourceId
end

local function getProductionDuration(productionConfig: ProductionConfig): number
	if productionConfig.behaviorId == "TimedStorageProducer" then
		return productionConfig.produceIntervalSeconds
	end

	return productionConfig.cycleDurationSeconds
end

local function scaleWholeNumber(value: number, multiplier: number): number
	return math.max(0, math.floor(value * multiplier))
end

local function getEffectiveProductionConfig(part: BasePart, buildingDefinition: BuildingDefinition): ProductionConfig
	local baseProductionConfig = buildingDefinition.productionConfig
	local outputResourceId = getOutputResourceId(baseProductionConfig)
	local outputMultiplier = PlotExpansionService.getResourceOutputMultiplierForPlacedPart(part, outputResourceId)
	local storageCapMultiplier = PlotExpansionService.getStorageCapMultiplierForPlacedPart(part, outputResourceId)
	if outputMultiplier <= 1 and storageCapMultiplier <= 1 then
		return baseProductionConfig
	end

	if baseProductionConfig.behaviorId == "GrowAndHarvest" then
		return {
			behaviorId = "GrowAndHarvest",
			cycleDurationSeconds = baseProductionConfig.cycleDurationSeconds,
			outputResourceId = baseProductionConfig.outputResourceId,
			outputAmount = scaleWholeNumber(baseProductionConfig.outputAmount, outputMultiplier),
			storageCap = scaleWholeNumber(baseProductionConfig.storageCap, storageCapMultiplier),
		}
	elseif baseProductionConfig.behaviorId == "TimedStorageProducer" then
		return {
			behaviorId = "TimedStorageProducer",
			produceIntervalSeconds = baseProductionConfig.produceIntervalSeconds,
			outputResourceId = baseProductionConfig.outputResourceId,
			outputAmountPerInterval = scaleWholeNumber(baseProductionConfig.outputAmountPerInterval, outputMultiplier),
			storageCap = scaleWholeNumber(baseProductionConfig.storageCap, storageCapMultiplier),
		}
	end

	return {
		behaviorId = "InputProcessor",
		cycleDurationSeconds = baseProductionConfig.cycleDurationSeconds,
		inputResourceId = baseProductionConfig.inputResourceId,
		inputAmount = baseProductionConfig.inputAmount,
		outputResourceId = baseProductionConfig.outputResourceId,
		outputAmount = scaleWholeNumber(baseProductionConfig.outputAmount, outputMultiplier),
		outputStorageMode = baseProductionConfig.outputStorageMode,
		idleStatusText = baseProductionConfig.idleStatusText,
		blockedStatusText = baseProductionConfig.blockedStatusText,
	}
end

local function syncPartAttributes(trackedBuilding: TrackedBuilding)
	local part = trackedBuilding.part
	local buildingDefinition = trackedBuilding.buildingDefinition
	local productionConfig = trackedBuilding.effectiveProductionConfig
	local runtimeState = trackedBuilding.runtimeState
	local currentGrowthStage = BuildingCatalog.getGrowthStageForProgress(buildingDefinition, runtimeState.progress)

	part:SetAttribute(
		BuildingAttributeNames.productionMultiplier,
		PlotExpansionService.getBuildingProductionMultiplierForPlacedPart(part, buildingDefinition.id)
	)
	part:SetAttribute(BuildingAttributeNames.buildingId, buildingDefinition.id)
	part:SetAttribute(BuildingAttributeNames.buildingDisplayName, buildingDefinition.displayName)
	part:SetAttribute(BuildingAttributeNames.productionBehaviorId, productionConfig.behaviorId)
	part:SetAttribute(BuildingAttributeNames.productionState, runtimeState.state)
	part:SetAttribute(BuildingAttributeNames.productionProgress, runtimeState.progress)
	part:SetAttribute(BuildingAttributeNames.productionTimeLeft, runtimeState.timeLeft)
	part:SetAttribute(BuildingAttributeNames.productionStatusText, runtimeState.statusText)
	part:SetAttribute(BuildingAttributeNames.productionDuration, getProductionDuration(productionConfig))
	part:SetAttribute(BuildingAttributeNames.productionOutputName, getOutputResourceName(productionConfig))
	part:SetAttribute(BuildingAttributeNames.productionStoredAmount, runtimeState.storedAmount)
	part:SetAttribute(BuildingAttributeNames.productionStorageCap, getStorageCap(productionConfig))
	part:SetAttribute(BuildingAttributeNames.isReadyToHarvest, runtimeState.isReadyToHarvest)
	part:SetAttribute(BuildingAttributeNames.growthVisualStageName, currentGrowthStage.modelName)
end

local function getCurrentGrowthStage(buildingDefinition: BuildingDefinition, runtimeState: ProductionRuntimeState): GrowthVisualStage
	return BuildingCatalog.getGrowthStageForProgress(buildingDefinition, runtimeState.progress)
end

local function createTrackedBuilding(
	part: BasePart,
	buildingDefinition: BuildingDefinition,
	savedProductionState: SavedProductionState?
): TrackedBuilding
	local effectiveProductionConfig = getEffectiveProductionConfig(part, buildingDefinition)
	local behavior = getProductionBehavior(effectiveProductionConfig)
	local currentTime = getCurrentTime()
	local hydratedRuntimeState: ProductionRuntimeState? = nil

	if savedProductionState ~= nil and savedProductionState.behaviorId == effectiveProductionConfig.behaviorId then
		hydratedRuntimeState = behavior.createRuntimeStateFromSavedState(
			effectiveProductionConfig,
			savedProductionState,
			currentTime
		)
	end

	local runtimeState = hydratedRuntimeState or behavior.createRuntimeState(effectiveProductionConfig, currentTime)
	local initialGrowthStage = getCurrentGrowthStage(buildingDefinition, runtimeState)
	local trackedBuilding: TrackedBuilding = {
		part = part,
		buildingDefinition = buildingDefinition,
		effectiveProductionConfig = effectiveProductionConfig,
		runtimeState = runtimeState,
		currentGrowthStageName = initialGrowthStage.modelName,
	}

	BuildingVisualService.setGrowthStageVisual(part, buildingDefinition.id, initialGrowthStage.modelName)
	syncPartAttributes(trackedBuilding)

	return trackedBuilding
end

local function updateTrackedBuilding(trackedBuilding: TrackedBuilding)
	local behavior = getProductionBehavior(trackedBuilding.effectiveProductionConfig)
	trackedBuilding.runtimeState = behavior.updateRuntimeState(
		trackedBuilding.runtimeState,
		trackedBuilding.effectiveProductionConfig,
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
					trackedBuildingsByPart[child] = createTrackedBuilding(child, BuildingCatalog.getBuildingDefinition(buildingId), nil)
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

function ProductionService.registerPlacedBuilding(part: BasePart, buildingId: BuildingId, savedProductionState: SavedProductionState?)
	local buildingDefinition = BuildingCatalog.getBuildingDefinition(buildingId)
	trackedBuildingsByPart[part] = createTrackedBuilding(part, buildingDefinition, savedProductionState)
end

function ProductionService.getSavedProductionState(part: BasePart): SavedProductionState?
	local trackedBuilding = trackedBuildingsByPart[part]
	if trackedBuilding == nil then
		return nil
	end

	local behavior = getProductionBehavior(trackedBuilding.effectiveProductionConfig)
	return behavior.createSavedState(
		trackedBuilding.runtimeState,
		trackedBuilding.effectiveProductionConfig,
		getCurrentTime()
	)
end

function ProductionService.getStoredOutput(part: BasePart): HarvestOutput?
	local trackedBuilding = trackedBuildingsByPart[part]
	if trackedBuilding == nil then
		return nil
	end

	local storedAmount = math.floor(trackedBuilding.runtimeState.storedAmount)
	if storedAmount <= 0 then
		return nil
	end

	return {
		resourceId = getOutputResourceId(trackedBuilding.effectiveProductionConfig),
		amount = storedAmount,
	}
end

function ProductionService.unregisterPlacedBuilding(part: BasePart)
	trackedBuildingsByPart[part] = nil
end

function ProductionService.tryHarvestPlacedBuilding(part: BasePart): (boolean, HarvestOutput?)
	local trackedBuilding = trackedBuildingsByPart[part]
	if trackedBuilding == nil then
		return false, nil
	end

	local behavior = getProductionBehavior(trackedBuilding.effectiveProductionConfig)
	if behavior.harvest == nil then
		return false, nil
	end

	local nextRuntimeState, harvestOutput = behavior.harvest(
		trackedBuilding.runtimeState,
		trackedBuilding.effectiveProductionConfig,
		getCurrentTime()
	)

	trackedBuilding.runtimeState = nextRuntimeState
	if harvestOutput == nil then
		syncPartAttributes(trackedBuilding)
		return false, nil
	end

	local nextGrowthStage = getCurrentGrowthStage(trackedBuilding.buildingDefinition, trackedBuilding.runtimeState)
	trackedBuilding.currentGrowthStageName = nextGrowthStage.modelName
	BuildingVisualService.setGrowthStageVisual(part, trackedBuilding.buildingDefinition.id, nextGrowthStage.modelName)
	syncPartAttributes(trackedBuilding)

	return true, harvestOutput
end

return table.freeze(ProductionService)

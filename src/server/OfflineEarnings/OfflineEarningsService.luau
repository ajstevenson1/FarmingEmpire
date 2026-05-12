--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local formattingFolder = sharedFolder:WaitForChild("Formatting") :: Folder
local offlineEarningsFolder = sharedFolder:WaitForChild("OfflineEarnings") :: Folder
local plotsFolder = sharedFolder:WaitForChild("Plots") :: Folder

local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local NumberFormatter = require(formattingFolder:WaitForChild("NumberFormatter") :: ModuleScript)
local OfflineEarningsConfig = require(offlineEarningsFolder:WaitForChild("OfflineEarningsConfig") :: ModuleScript)
local PlotLocator = require(plotsFolder:WaitForChild("PlotLocator") :: ModuleScript)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)
local PlotService = require(script.Parent.Parent.Plots.PlotService)
local ResourceService = require(script.Parent.Parent.Resources.ResourceService)

type BuildingDefinition = BuildingTypes.BuildingDefinition
type InputProcessorProductionConfig = BuildingTypes.InputProcessorProductionConfig
type PlacedBuildingData = PlayerDataService.PlacedBuildingData
type TimedStorageProducerProductionConfig = BuildingTypes.TimedStorageProducerProductionConfig

type OfflineMill = {
	inputAmount: number,
	outputAmount: number,
	cycleDurationSeconds: number,
	ciderPerApple: number,
	nextAvailableAt: number,
	completionOutputAmount: number?,
}

type OfflineTree = {
	startingStoredAmount: number,
	outputAmountPerInterval: number,
	produceIntervalSeconds: number,
	remainingStorage: number,
	nextProduceAt: number?,
}

type OfflineCiderResult = {
	earnedCider: number,
	consumedInventoryApples: number,
}

local CIDER_RESOURCE_ID = "Cider"
local APPLE_RESOURCE_ID = "Apple"
local CHARACTER_ROOT_NAME = "HumanoidRootPart"
local CLAIM_DEBOUNCE_SECONDS = 1
local OWNER_USER_ID_ATTRIBUTE = PlotLocator.Attributes.ownerUserId

local workspacePlotsFolder = Workspace:WaitForChild(PlotLocator.PLOTS_FOLDER_NAME) :: Folder
local nextAllowedClaimAtByPlayer: { [Player]: number } = {}
local hasStarted = false

local function sanitizeTimestamp(timestamp: number): number
	if timestamp ~= timestamp or timestamp == math.huge or timestamp == -math.huge or timestamp < 0 then
		return 0
	end

	return math.floor(timestamp)
end

local function getCurrentUnixTime(): number
	return os.time()
end

local function getOfflineSeconds(lastSeenAt: number, currentTime: number): number
	local elapsedSeconds = math.max(0, currentTime - sanitizeTimestamp(lastSeenAt))
	return math.min(elapsedSeconds, OfflineEarningsConfig.maxOfflineSeconds)
end

local function getTextLabel(root: Instance, name: string): TextLabel?
	local label = root:FindFirstChild(name, true)
	if label == nil then
		return nil
	end

	if not label:IsA("TextLabel") then
		warn(string.format("[OfflineEarningsService] %s must be a TextLabel.", label:GetFullName()))
		return nil
	end

	return label
end

local function getPlateGui(plate: Instance): Instance?
	local gui = plate:FindFirstChild(OfflineEarningsConfig.guiName, true)
	if gui == nil then
		warn(string.format("[OfflineEarningsService] Missing %s.%s.", plate:GetFullName(), OfflineEarningsConfig.guiName))
		return nil
	end

	return gui
end

local function findPlateModel(plot: Instance): Instance?
	local plate = plot:FindFirstChild(OfflineEarningsConfig.plateModelName)
	if plate == nil then
		warn(string.format(
			"[OfflineEarningsService] Missing %s.%s.",
			plot:GetFullName(),
			OfflineEarningsConfig.plateModelName
		))
	end

	return plate
end

local function findTouchPart(plot: Instance): BasePart?
	local plate = findPlateModel(plot)
	if plate == nil then
		return nil
	end

	local touchPart = plate:FindFirstChild(OfflineEarningsConfig.touchPartName)
	if touchPart == nil then
		warn(string.format("[OfflineEarningsService] Missing %s.%s.", plate:GetFullName(), OfflineEarningsConfig.touchPartName))
		return nil
	end

	if not touchPart:IsA("BasePart") then
		warn(string.format("[OfflineEarningsService] %s must be a BasePart.", touchPart:GetFullName()))
		return nil
	end

	return touchPart
end

local function getPlayerFromTouchedPart(touchedPart: BasePart): Player?
	local character = touchedPart:FindFirstAncestorOfClass("Model")
	if character == nil then
		return nil
	end

	local rootPart = character:FindFirstChild(CHARACTER_ROOT_NAME)
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function formatPendingCider(pendingCider: number): string
	if pendingCider <= 0 then
		return "No Cider"
	end

	return string.format("+%s Cider", NumberFormatter.formatAbbreviated(pendingCider, {
		decimalPlaces = 1,
		trimTrailingZeros = true,
	}))
end

local function updatePlotDisplay(plot: Instance)
	local plate = findPlateModel(plot)
	if plate == nil then
		return
	end

	local gui = getPlateGui(plate)
	if gui == nil then
		return
	end

	local nameLabel = getTextLabel(gui, OfflineEarningsConfig.nameLabelName)
	if nameLabel ~= nil then
		nameLabel.Text = OfflineEarningsConfig.displayNameText
	end

	local earningsLabel = getTextLabel(gui, OfflineEarningsConfig.earningsLabelName)
	if earningsLabel == nil then
		return
	end

	local ownerUserId = PlotLocator.getOwnerUserId(plot)
	if ownerUserId == nil then
		earningsLabel.Text = "Unclaimed"
		return
	end

	local ownerPlayer = Players:GetPlayerByUserId(ownerUserId)
	if ownerPlayer == nil then
		earningsLabel.Text = "Unclaimed"
		return
	end

	earningsLabel.Text = formatPendingCider(PlayerDataService.getPendingOfflineCider(ownerPlayer))
end

local function updatePlayerPlotDisplay(player: Player)
	local plot = PlotService.getAssignedPlot(player)
	if plot ~= nil then
		updatePlotDisplay(plot)
	end
end

local function createOfflineTree(
	placedBuilding: PlacedBuildingData,
	buildingDefinition: BuildingDefinition
): OfflineTree?
	local productionConfig = buildingDefinition.productionConfig
	if productionConfig.behaviorId ~= "TimedStorageProducer" or productionConfig.outputResourceId ~= APPLE_RESOURCE_ID then
		return nil
	end

	local typedConfig = productionConfig :: TimedStorageProducerProductionConfig
	local storageCap = math.max(0, math.floor(typedConfig.storageCap))
	local outputAmountPerInterval = math.max(0, math.floor(typedConfig.outputAmountPerInterval))
	local produceIntervalSeconds = math.max(0.001, typedConfig.produceIntervalSeconds)
	if storageCap <= 0 or outputAmountPerInterval <= 0 then
		return nil
	end

	local savedProduction = placedBuilding.production
	local storedAmount = 0
	local secondsUntilNextProduce = produceIntervalSeconds
	if savedProduction ~= nil and savedProduction.behaviorId == "TimedStorageProducer" then
		storedAmount = math.clamp(math.floor(savedProduction.storedAmount), 0, storageCap)
		secondsUntilNextProduce = math.clamp(savedProduction.secondsUntilNextProduce, 0, produceIntervalSeconds)
	end

	local remainingStorage = math.max(0, storageCap - storedAmount)
	if storedAmount <= 0 and remainingStorage <= 0 then
		return nil
	end

	return {
		startingStoredAmount = storedAmount,
		outputAmountPerInterval = outputAmountPerInterval,
		produceIntervalSeconds = produceIntervalSeconds,
		remainingStorage = remainingStorage,
		nextProduceAt = if remainingStorage > 0 then secondsUntilNextProduce else nil,
	}
end

local function createOfflineMill(
	placedBuilding: PlacedBuildingData,
	buildingDefinition: BuildingDefinition
): OfflineMill?
	local productionConfig = buildingDefinition.productionConfig
	if productionConfig.behaviorId ~= "InputProcessor"
		or productionConfig.inputResourceId ~= APPLE_RESOURCE_ID
		or productionConfig.outputResourceId ~= CIDER_RESOURCE_ID
	then
		return nil
	end

	local typedConfig = productionConfig :: InputProcessorProductionConfig
	local inputAmount = math.max(0, math.floor(typedConfig.inputAmount))
	local outputAmount = math.max(0, math.floor(typedConfig.outputAmount))
	local cycleDurationSeconds = math.max(0.001, typedConfig.cycleDurationSeconds)
	if inputAmount <= 0 or outputAmount <= 0 then
		return nil
	end

	return {
		inputAmount = inputAmount,
		outputAmount = outputAmount,
		cycleDurationSeconds = cycleDurationSeconds,
		ciderPerApple = outputAmount / inputAmount,
		nextAvailableAt = if placedBuilding.production ~= nil
			and placedBuilding.production.behaviorId == "InputProcessor"
			and placedBuilding.production.state == "Processing"
			and placedBuilding.production.secondsUntilCycleFinishes ~= nil
			then math.clamp(placedBuilding.production.secondsUntilCycleFinishes, 0, cycleDurationSeconds)
			else 0,
		completionOutputAmount = if placedBuilding.production ~= nil
			and placedBuilding.production.behaviorId == "InputProcessor"
			and placedBuilding.production.state == "Processing"
			then outputAmount
			else nil,
	}
end

local function getNextEventTime(offlineTrees: { OfflineTree }, offlineMills: { OfflineMill }, currentTime: number): number?
	local nextEventTime: number? = nil

	for _, offlineTree in ipairs(offlineTrees) do
		local nextProduceAt = offlineTree.nextProduceAt
		if nextProduceAt ~= nil and nextProduceAt > currentTime then
			if nextEventTime == nil or nextProduceAt < nextEventTime then
				nextEventTime = nextProduceAt
			end
		end
	end

	for _, offlineMill in ipairs(offlineMills) do
		if offlineMill.nextAvailableAt > currentTime then
			if nextEventTime == nil or offlineMill.nextAvailableAt < nextEventTime then
				nextEventTime = offlineMill.nextAvailableAt
			end
		end
	end

	return nextEventTime
end

local function processTreeEventsAtTime(
	offlineTrees: { OfflineTree },
	currentTime: number,
	availableVirtualApples: number
): number
	for _, offlineTree in ipairs(offlineTrees) do
		local nextProduceAt = offlineTree.nextProduceAt
		if nextProduceAt ~= nil and nextProduceAt == currentTime and offlineTree.remainingStorage > 0 then
			local producedAmount = math.min(offlineTree.remainingStorage, offlineTree.outputAmountPerInterval)
			if producedAmount > 0 then
				availableVirtualApples += producedAmount
				offlineTree.remainingStorage -= producedAmount
			end

			offlineTree.nextProduceAt = if offlineTree.remainingStorage > 0
				then currentTime + offlineTree.produceIntervalSeconds
				else nil
		end
	end

	return availableVirtualApples
end

local function processMillEventsAtTime(
	offlineMills: { OfflineMill },
	currentTime: number,
	pendingCider: number
): number
	for _, offlineMill in ipairs(offlineMills) do
		if offlineMill.nextAvailableAt == currentTime then
			local completionOutputAmount = offlineMill.completionOutputAmount
			if completionOutputAmount ~= nil and completionOutputAmount > 0 then
				pendingCider += completionOutputAmount
				offlineMill.completionOutputAmount = nil
			end
		end
	end

	return pendingCider
end

local function startOfflineMillCyclesAtTime(
	offlineMills: { OfflineMill },
	currentTime: number,
	offlineSeconds: number,
	availableInventoryApples: number,
	availableTreeApples: number
): (number, number)
	local startedCycle = true
	while startedCycle do
		startedCycle = false

		for _, offlineMill in ipairs(offlineMills) do
			local availableVirtualApples = availableInventoryApples + availableTreeApples
			if offlineMill.nextAvailableAt <= currentTime
				and offlineMill.completionOutputAmount == nil
				and currentTime + offlineMill.cycleDurationSeconds <= offlineSeconds
				and availableVirtualApples >= offlineMill.inputAmount
			then
				local inventoryApplesToConsume = math.min(availableInventoryApples, offlineMill.inputAmount)
				local treeApplesToConsume = offlineMill.inputAmount - inventoryApplesToConsume
				availableInventoryApples -= inventoryApplesToConsume
				availableTreeApples -= treeApplesToConsume
				offlineMill.nextAvailableAt = currentTime + offlineMill.cycleDurationSeconds
				offlineMill.completionOutputAmount = offlineMill.outputAmount
				startedCycle = true
			end
		end
	end

	return availableInventoryApples, availableTreeApples
end

local function calculateOfflineCider(player: Player, offlineSeconds: number): OfflineCiderResult
	if offlineSeconds < OfflineEarningsConfig.minOfflineSecondsToReward then
		return {
			earnedCider = 0,
			consumedInventoryApples = 0,
		}
	end

	local offlineTrees: { OfflineTree } = {}
	local offlineMills: { OfflineMill } = {}
	local startingTreeApples = 0

	for _, placedBuilding in ipairs(PlayerDataService.getPlacedBuildings(player)) do
		local buildingDefinition = BuildingCatalog.getBuildingDefinition(placedBuilding.buildingId)
		local offlineTree = createOfflineTree(placedBuilding, buildingDefinition)
		if offlineTree ~= nil then
			startingTreeApples += offlineTree.startingStoredAmount
			if offlineTree.nextProduceAt ~= nil and offlineTree.nextProduceAt <= offlineSeconds then
				table.insert(offlineTrees, offlineTree)
			end
		end

		local offlineMill = createOfflineMill(placedBuilding, buildingDefinition)
		if offlineMill ~= nil and offlineMill.nextAvailableAt <= offlineSeconds then
			table.insert(offlineMills, offlineMill)
		end
	end

	if #offlineMills == 0 then
		return {
			earnedCider = 0,
			consumedInventoryApples = 0,
		}
	end

	table.sort(offlineMills, function(leftMill: OfflineMill, rightMill: OfflineMill): boolean
		if leftMill.ciderPerApple == rightMill.ciderPerApple then
			if leftMill.cycleDurationSeconds == rightMill.cycleDurationSeconds then
				return leftMill.outputAmount > rightMill.outputAmount
			end

			return leftMill.cycleDurationSeconds < rightMill.cycleDurationSeconds
		end

		return leftMill.ciderPerApple > rightMill.ciderPerApple
	end)

	local pendingCider = 0
	local startingInventoryApples = math.max(0, math.floor(PlayerDataService.getResourceAmount(player, APPLE_RESOURCE_ID)))
	local availableInventoryApples = startingInventoryApples
	local availableTreeApples = startingTreeApples
	local currentTime = 0

	while currentTime <= offlineSeconds do
		pendingCider = processMillEventsAtTime(offlineMills, currentTime, pendingCider)
		availableTreeApples = processTreeEventsAtTime(offlineTrees, currentTime, availableTreeApples)
		availableInventoryApples, availableTreeApples = startOfflineMillCyclesAtTime(
			offlineMills,
			currentTime,
			offlineSeconds,
			availableInventoryApples,
			availableTreeApples
		)

		local nextEventTime = getNextEventTime(offlineTrees, offlineMills, currentTime)
		if nextEventTime == nil or nextEventTime > offlineSeconds then
			break
		end

		currentTime = nextEventTime
	end

	return {
		earnedCider = math.min(math.floor(pendingCider), OfflineEarningsConfig.maxPendingCider),
		consumedInventoryApples = math.max(0, startingInventoryApples - availableInventoryApples),
	}
end

local function initializePlayer(player: Player)
	PlayerDataService.waitForData(player)

	local currentTime = getCurrentUnixTime()
	local offlineData = PlayerDataService.getOfflineData(player)
	if offlineData.lastSeenAt <= 0 then
		PlayerDataService.setOfflineLastSeenAt(player, currentTime)
		updatePlayerPlotDisplay(player)
		return
	end

	local offlineSeconds = getOfflineSeconds(offlineData.lastSeenAt, currentTime)
	local offlineCiderResult = calculateOfflineCider(player, offlineSeconds)
	if offlineCiderResult.consumedInventoryApples > 0 then
		ResourceService.tryConsumeResource(player, APPLE_RESOURCE_ID, offlineCiderResult.consumedInventoryApples)
	end

	if offlineCiderResult.earnedCider > 0 then
		local currentPendingCider = PlayerDataService.getPendingOfflineCider(player)
		local remainingPendingCapacity = math.max(0, OfflineEarningsConfig.maxPendingCider - currentPendingCider)
		PlayerDataService.addPendingOfflineCider(player, math.min(offlineCiderResult.earnedCider, remainingPendingCapacity))
	end

	PlayerDataService.setOfflineLastSeenAt(player, currentTime)
	updatePlayerPlotDisplay(player)
end

local function saveCurrentSeenTime(player: Player)
	PlayerDataService.setOfflineLastSeenAt(player, getCurrentUnixTime())
end

local function canClaim(player: Player): boolean
	local now = Workspace:GetServerTimeNow()
	local nextAllowedClaimAt = nextAllowedClaimAtByPlayer[player] or 0
	if now < nextAllowedClaimAt then
		return false
	end

	nextAllowedClaimAtByPlayer[player] = now + CLAIM_DEBOUNCE_SECONDS
	return true
end

local function claimPendingCider(player: Player)
	if not canClaim(player) then
		return
	end

	local pendingCider = PlayerDataService.claimPendingOfflineCider(player)
	if pendingCider <= 0 then
		updatePlayerPlotDisplay(player)
		return
	end

	ResourceService.addResource(player, CIDER_RESOURCE_ID, pendingCider)
	updatePlayerPlotDisplay(player)
end

local function connectPlot(plot: Instance)
	local touchPart = findTouchPart(plot)
	if touchPart == nil then
		updatePlotDisplay(plot)
		return
	end

	touchPart.Touched:Connect(function(touchedPart: BasePart)
		local player = getPlayerFromTouchedPart(touchedPart)
		if player == nil or not PlotService.isAssignedPlot(player, plot) then
			return
		end

		claimPendingCider(player)
	end)

	plot:GetAttributeChangedSignal(OWNER_USER_ID_ATTRIBUTE):Connect(function()
		updatePlotDisplay(plot)
	end)

	updatePlotDisplay(plot)
end

local function connectExistingPlots()
	for _, plot in ipairs(PlotLocator.getAllPlots(workspacePlotsFolder)) do
		connectPlot(plot)
	end
end

local function cleanupPlayer(player: Player)
	nextAllowedClaimAtByPlayer[player] = nil
end

local OfflineEarningsService = {}

function OfflineEarningsService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	connectExistingPlots()
	PlayerDataService.observeBeforeSave(saveCurrentSeenTime)
	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(cleanupPlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		initializePlayer(player)
	end
end

return table.freeze(OfflineEarningsService)

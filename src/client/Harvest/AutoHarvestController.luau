--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before starting AutoHarvestController")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local harvestFolder = sharedFolder:WaitForChild("Harvest") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local plotsFolder = sharedFolder:WaitForChild("Plots") :: Folder

local AutoHarvestConfig = require(harvestFolder:WaitForChild("AutoHarvestConfig") :: ModuleScript)
local AutoHarvestNavigator = require(script.Parent.AutoHarvestNavigator)
local AutoHarvestView = require(script.Parent.AutoHarvestView)
local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local InventoryController = require(script.Parent.Parent.Inventory.InventoryController)
local PlotLocator = require(plotsFolder:WaitForChild("PlotLocator") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local ScytheController = require(script.Parent.Parent.Tools.ScytheController)

type AutoHarvestViewInstance = AutoHarvestView.AutoHarvestView

local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
local PLOT_NAME_ATTRIBUTE = "PlotName"
local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local SCYTHE_ITEM_ID = "Scythe"
local APPLE_RESOURCE_ID = "Apple"
local AIM_SETTLE_SECONDS = 0.05

local hasStarted = false
local view: AutoHarvestViewInstance? = nil
local isScytheSelected = false
local isAutoHarvestEnabled = false
local runToken = 0
local recentlyVisitedUntilByPart: { [BasePart]: number } = {}
local lastVisitedTimeByPart: { [BasePart]: number } = {}
local appleTargetCandidates: { [BasePart]: boolean } = {}
local appleTargetConnectionsByPart: { [BasePart]: { RBXScriptConnection } } = {}
local lastVisitedPosition: Vector3? = nil
local lastVisitedClusterExpiresAt = 0

local MOVEMENT_KEYCODES: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true,
	[Enum.KeyCode.Down] = true,
	[Enum.KeyCode.Left] = true,
	[Enum.KeyCode.Right] = true,
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.Thumbstick1] = true,
	[Enum.KeyCode.DPadUp] = true,
	[Enum.KeyCode.DPadDown] = true,
	[Enum.KeyCode.DPadLeft] = true,
	[Enum.KeyCode.DPadRight] = true,
}

local function getAutoHarvestStateRemote(): RemoteEvent
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local harvestRemotesFolder = rootFolder:WaitForChild(RemoteNames.harvestFolderName) :: Folder
	return harvestRemotesFolder:WaitForChild(RemoteNames.requestAutoHarvestStateEventName) :: RemoteEvent
end

local function getAutoHarvestRemote(): RemoteEvent
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local harvestRemotesFolder = rootFolder:WaitForChild(RemoteNames.harvestFolderName) :: Folder
	return harvestRemotesFolder:WaitForChild(RemoteNames.requestAutoHarvestEventName) :: RemoteEvent
end

local function getPlacedObjectsFolder(): Folder?
	local existingFolder = Workspace:FindFirstChild(PLACED_OBJECTS_FOLDER_NAME)
	if existingFolder == nil then
		return nil
	end

	assert(existingFolder:IsA("Folder"), string.format("%s must be a Folder", PLACED_OBJECTS_FOLDER_NAME))
	return existingFolder
end

local function getHumanoidRootPart(): BasePart?
	local character = localPlayer.Character
	if character == nil then
		return nil
	end

	local candidate = character:FindFirstChild("HumanoidRootPart")
	if candidate == nil or not candidate:IsA("BasePart") then
		return nil
	end

	return candidate
end

local function getSelectedItemId(): string?
	local snapshot = InventoryController.getLatestSnapshot()
	if snapshot == nil or snapshot.selectedSlotIndex == nil then
		return nil
	end

	return snapshot.hotbarSlots[snapshot.selectedSlotIndex]
end

local function isOwnedPartOnAssignedPlot(part: BasePart): boolean
	if part:GetAttribute(OWNER_USER_ID_ATTRIBUTE) ~= localPlayer.UserId then
		return false
	end

	local assignedPlotName = localPlayer:GetAttribute(PlotLocator.PlayerAttributes.assignedPlotName)
	if type(assignedPlotName) ~= "string" or part:GetAttribute(PLOT_NAME_ATTRIBUTE) ~= assignedPlotName then
		return false
	end

	return true
end

local function isOwnedAppleCandidate(part: BasePart): boolean
	return isOwnedPartOnAssignedPlot(part)
		and part:GetAttribute(BuildingAttributeNames.productionOutputName) == APPLE_RESOURCE_ID
end

local function isOwnedAppleTarget(part: BasePart): boolean
	return isOwnedAppleCandidate(part) and part:GetAttribute(BuildingAttributeNames.isReadyToHarvest) == true
end

local function refreshAppleTargetCandidate(part: BasePart)
	if part.Parent ~= nil and isOwnedAppleCandidate(part) then
		appleTargetCandidates[part] = true
	else
		appleTargetCandidates[part] = nil
	end
end

local function disconnectAppleTargetCandidate(part: BasePart)
	local connections = appleTargetConnectionsByPart[part]
	if connections ~= nil then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end

		appleTargetConnectionsByPart[part] = nil
	end

	appleTargetCandidates[part] = nil
	recentlyVisitedUntilByPart[part] = nil
	lastVisitedTimeByPart[part] = nil
end

local function connectAppleTargetCandidate(part: BasePart)
	if appleTargetConnectionsByPart[part] ~= nil then
		refreshAppleTargetCandidate(part)
		return
	end

	appleTargetConnectionsByPart[part] = {
		part:GetAttributeChangedSignal(OWNER_USER_ID_ATTRIBUTE):Connect(function()
			refreshAppleTargetCandidate(part)
		end),
		part:GetAttributeChangedSignal(PLOT_NAME_ATTRIBUTE):Connect(function()
			refreshAppleTargetCandidate(part)
		end),
		part:GetAttributeChangedSignal(BuildingAttributeNames.productionOutputName):Connect(function()
			refreshAppleTargetCandidate(part)
		end),
		part.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				disconnectAppleTargetCandidate(part)
			end
		end),
	}

	refreshAppleTargetCandidate(part)
end

local function refreshAllAppleTargetCandidates()
	table.clear(appleTargetCandidates)
	local placedObjectsFolder = getPlacedObjectsFolder()
	if placedObjectsFolder == nil then
		return
	end

	for _, child in ipairs(placedObjectsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			connectAppleTargetCandidate(child)
		end
	end
end

local function faceTarget(rootPart: BasePart, targetPart: BasePart)
	local targetOffset = targetPart.Position - rootPart.Position
	local planarTargetOffset = Vector3.new(targetOffset.X, 0, targetOffset.Z)
	if planarTargetOffset.Magnitude <= 0.001 then
		return
	end

	rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + planarTargetOffset.Unit, Vector3.yAxis)
end

local function clearExpiredRecentTargets(currentTime: number)
	for part, expiresAt in pairs(recentlyVisitedUntilByPart) do
		if part.Parent == nil or currentTime >= expiresAt then
			recentlyVisitedUntilByPart[part] = nil
		end
	end

	for part in pairs(lastVisitedTimeByPart) do
		if part.Parent == nil then
			lastVisitedTimeByPart[part] = nil
		end
	end
end

local function getNumericAttribute(part: BasePart, attributeName: string): number
	local value = part:GetAttribute(attributeName)
	return if type(value) == "number" then value else 0
end

local function isAtStorageCapacity(part: BasePart): boolean
	local storedAmount = getNumericAttribute(part, BuildingAttributeNames.productionStoredAmount)
	local storageCap = getNumericAttribute(part, BuildingAttributeNames.productionStorageCap)
	return storedAmount > 0 and storageCap > 0 and storedAmount >= storageCap
end

local function isNearLastVisitedCluster(part: BasePart): boolean
	local visitedPosition = lastVisitedPosition
	return visitedPosition ~= nil
		and os.clock() < lastVisitedClusterExpiresAt
		and (part.Position - visitedPosition).Magnitude < AutoHarvestConfig.recentClusterRadiusStuds
end

local function getWaitingScore(part: BasePart, currentTime: number): number
	local lastVisitedTime = lastVisitedTimeByPart[part]
	return if lastVisitedTime == nil
		then AutoHarvestConfig.neverVisitedScoreBonus
		else math.min((currentTime - lastVisitedTime) * AutoHarvestConfig.waitingScoreWeight, AutoHarvestConfig.maxWaitingScoreBonus)
end

local function isRecentlyVisited(part: BasePart, currentTime: number): boolean
	local recentUntil = recentlyVisitedUntilByPart[part]
	return recentUntil ~= nil and currentTime < recentUntil
end

local function getRoutePenalty(part: BasePart, rootPart: BasePart): number
	local distance = (rootPart.Position - part.Position).Magnitude
	local penalty = distance * AutoHarvestConfig.distanceScorePenalty
	if isNearLastVisitedCluster(part) then
		penalty += AutoHarvestConfig.recentClusterScorePenalty
	end

	if distance < AutoHarvestConfig.minRouteTravelDistanceStuds then
		penalty += AutoHarvestConfig.closeTargetScorePenalty
	end

	return penalty
end

local function getFullTreeScore(part: BasePart, rootPart: BasePart, currentTime: number): number
	local storedAmount = getNumericAttribute(part, BuildingAttributeNames.productionStoredAmount)
	local score = getWaitingScore(part, currentTime)
		+ storedAmount * AutoHarvestConfig.fullStoredAmountScoreWeight
		- getRoutePenalty(part, rootPart)

	if isRecentlyVisited(part, currentTime) then
		score -= AutoHarvestConfig.recentClusterScorePenalty
	end

	return score
end

local function getTargetScore(part: BasePart, rootPart: BasePart, currentTime: number): number
	local storedAmount = getNumericAttribute(part, BuildingAttributeNames.productionStoredAmount)
	local storageCap = getNumericAttribute(part, BuildingAttributeNames.productionStorageCap)
	local score = storedAmount * AutoHarvestConfig.storedAmountScoreWeight
		+ storageCap * AutoHarvestConfig.storageCapScoreWeight
		+ getWaitingScore(part, currentTime)
		- getRoutePenalty(part, rootPart)

	if isRecentlyVisited(part, currentTime) then
		score -= AutoHarvestConfig.recentClusterScorePenalty
	end

	return score
end

local function findNextReadyAppleTarget(): BasePart?
	local rootPart = getHumanoidRootPart()
	if rootPart == nil then
		return nil
	end

	local currentTime = os.clock()
	clearExpiredRecentTargets(currentTime)

	local selectedFreshFullTarget: BasePart? = nil
	local selectedFreshFullScore = -math.huge
	local selectedAnyFullTarget: BasePart? = nil
	local selectedAnyFullScore = -math.huge
	local selectedTarget: BasePart? = nil
	local selectedScore = -math.huge

	for child in pairs(appleTargetCandidates) do
		if child.Parent == nil then
			disconnectAppleTargetCandidate(child)
			continue
		end

		if isOwnedAppleTarget(child) then
			if isAtStorageCapacity(child) then
				local fullScore = getFullTreeScore(child, rootPart, currentTime)
				if not isRecentlyVisited(child, currentTime)
					and not isNearLastVisitedCluster(child)
					and (selectedFreshFullTarget == nil or fullScore > selectedFreshFullScore)
				then
					selectedFreshFullTarget = child
					selectedFreshFullScore = fullScore
				end

				if selectedAnyFullTarget == nil or fullScore > selectedAnyFullScore then
					selectedAnyFullTarget = child
					selectedAnyFullScore = fullScore
				end
			end

			local score = getTargetScore(child, rootPart, currentTime)
			if selectedTarget == nil or score > selectedScore then
				selectedTarget = child
				selectedScore = score
			end
		end
	end

	return selectedFreshFullTarget or selectedAnyFullTarget or selectedTarget
end

local function markTargetVisited(targetPart: BasePart)
	local expiresAt = os.clock() + AutoHarvestConfig.recentlyVisitedSeconds
	for child in pairs(appleTargetCandidates) do
		if child.Parent == nil then
			disconnectAppleTargetCandidate(child)
			continue
		end

		if isOwnedAppleTarget(child)
			and (child.Position - targetPart.Position).Magnitude <= AutoHarvestConfig.recentClusterRadiusStuds
		then
			recentlyVisitedUntilByPart[child] = expiresAt
			lastVisitedTimeByPart[child] = os.clock()
		end
	end

	recentlyVisitedUntilByPart[targetPart] = expiresAt
	lastVisitedTimeByPart[targetPart] = os.clock()
	lastVisitedPosition = targetPart.Position
	lastVisitedClusterExpiresAt = expiresAt
end

local function setViewState()
	local currentView = view
	if currentView == nil then
		return
	end

	currentView:setVisible(isScytheSelected)
	currentView:setEnabled(isAutoHarvestEnabled)
end

local function setAutoHarvestEnabled(shouldEnable: boolean)
	if shouldEnable and not isScytheSelected then
		shouldEnable = false
	end

	if isAutoHarvestEnabled == shouldEnable then
		setViewState()
		return
	end

	isAutoHarvestEnabled = shouldEnable
	runToken += 1
	setViewState()
	getAutoHarvestStateRemote():FireServer(isAutoHarvestEnabled)

	if shouldEnable then
		local currentToken = runToken
		task.spawn(function()
			local requestAutoHarvest = getAutoHarvestRemote()
			while isAutoHarvestEnabled and currentToken == runToken do
				local targetPart = findNextReadyAppleTarget()
				if targetPart == nil then
					task.wait(AutoHarvestConfig.noTargetRetrySeconds)
					continue
				end

				local didReachTarget = AutoHarvestNavigator.moveToTarget(targetPart)
				if not isAutoHarvestEnabled or currentToken ~= runToken then
					break
				end

				if didReachTarget and targetPart.Parent ~= nil and isOwnedAppleTarget(targetPart) then
					local rootPart = getHumanoidRootPart()
					if rootPart ~= nil then
						faceTarget(rootPart, targetPart)
						task.wait(AIM_SETTLE_SECONDS)
						if not isAutoHarvestEnabled or currentToken ~= runToken or targetPart.Parent == nil or not isOwnedAppleTarget(targetPart) then
							continue
						end

						ScytheController.tryPlaySwing()
						markTargetVisited(targetPart)
						requestAutoHarvest:FireServer(targetPart)
					end
					task.wait(AutoHarvestConfig.harvestIntervalSeconds)
				else
					task.wait(AutoHarvestConfig.targetScanIntervalSeconds)
				end
			end
		end)
	else
		AutoHarvestNavigator.stopMovement()
	end
end

local function shouldCancelAutoHarvestForInput(inputObject: InputObject): boolean
	if UserInputService:GetFocusedTextBox() ~= nil then
		return false
	end

	return MOVEMENT_KEYCODES[inputObject.KeyCode] == true
end

local function shouldCancelAutoHarvestForInputChange(inputObject: InputObject): boolean
	if inputObject.KeyCode ~= Enum.KeyCode.Thumbstick1 then
		return false
	end

	return inputObject.Position.Magnitude > 0.2
end

local function updateSelectedToolState()
	isScytheSelected = getSelectedItemId() == SCYTHE_ITEM_ID
	if not isScytheSelected then
		setAutoHarvestEnabled(false)
	else
		setViewState()
	end
end

local AutoHarvestController = {}

function AutoHarvestController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local createdView = AutoHarvestView.new()
	view = createdView
	createdView:connectToggleRequested(function()
		setAutoHarvestEnabled(not isAutoHarvestEnabled)
	end)

	local placedObjectsFolder = getPlacedObjectsFolder()
	if placedObjectsFolder ~= nil then
		for _, child in ipairs(placedObjectsFolder:GetChildren()) do
			if child:IsA("BasePart") then
				connectAppleTargetCandidate(child)
			end
		end

		placedObjectsFolder.ChildAdded:Connect(function(child)
			if child:IsA("BasePart") then
				connectAppleTargetCandidate(child)
			end
		end)

		placedObjectsFolder.ChildRemoved:Connect(function(child)
			if child:IsA("BasePart") then
				disconnectAppleTargetCandidate(child)
			end
		end)
	end

	localPlayer:GetAttributeChangedSignal(PlotLocator.PlayerAttributes.assignedPlotName):Connect(refreshAllAppleTargetCandidates)

	InventoryController.observeSnapshotChanged(function(_snapshot)
		updateSelectedToolState()
	end)

	localPlayer.CharacterRemoving:Connect(function()
		setAutoHarvestEnabled(false)
	end)

	UserInputService.InputBegan:Connect(function(inputObject: InputObject, _gameProcessedEvent: boolean)
		if isAutoHarvestEnabled and shouldCancelAutoHarvestForInput(inputObject) then
			setAutoHarvestEnabled(false)
		end
	end)

	UserInputService.InputChanged:Connect(function(inputObject: InputObject, _gameProcessedEvent: boolean)
		if isAutoHarvestEnabled and shouldCancelAutoHarvestForInputChange(inputObject) then
			setAutoHarvestEnabled(false)
		end
	end)

	updateSelectedToolState()
end

return table.freeze(AutoHarvestController)

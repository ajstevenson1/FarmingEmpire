--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local harvestFolder = sharedFolder:WaitForChild("Harvest") :: Folder
local toolsFolder = sharedFolder:WaitForChild("Tools") :: Folder

local AutoHarvestConfig = require(harvestFolder:WaitForChild("AutoHarvestConfig") :: ModuleScript)
local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local ScytheSwingVolume = require(toolsFolder:WaitForChild("ScytheSwingVolume") :: ModuleScript)
local HarvestEffectService = require(script.Parent.HarvestEffectService)
local InventoryService = require(script.Parent.Parent.Inventory.InventoryService)
local PlotService = require(script.Parent.Parent.Plots.PlotService)
local ProductionService = require(script.Parent.Parent.Production.ProductionService)
local Remotes = require(script.Parent.Parent.Networking.Remotes)
local ResourceService = require(script.Parent.Parent.Resources.ResourceService)

type AppleHarvestEffectPayload = HarvestEffectService.AppleHarvestEffectPayload

type AutoHarvestPlayerState = {
	isEnabled: boolean,
	nextAllowedHarvestTime: number,
}

local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
local PLOT_NAME_ATTRIBUTE = "PlotName"
local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local APPLE_RESOURCE_ID = "Apple"

local hasStarted = false
local stateByPlayer: { [Player]: AutoHarvestPlayerState } = {}

local AUTO_HARVEST_PRODUCTION_BEHAVIORS: { [string]: boolean } = {
	GrowAndHarvest = true,
	TimedStorageProducer = true,
}

local function getPlacedObjectsFolder(): Folder?
	local existingFolder = Workspace:FindFirstChild(PLACED_OBJECTS_FOLDER_NAME)
	if existingFolder == nil then
		return nil
	end

	assert(existingFolder:IsA("Folder"), string.format("%s must be a Folder", PLACED_OBJECTS_FOLDER_NAME))
	return existingFolder
end

local function getOrCreateState(player: Player): AutoHarvestPlayerState
	local existingState = stateByPlayer[player]
	if existingState ~= nil then
		return existingState
	end

	local createdState: AutoHarvestPlayerState = {
		isEnabled = false,
		nextAllowedHarvestTime = 0,
	}
	stateByPlayer[player] = createdState
	return createdState
end

local function getHumanoidRootPart(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end

	local candidate = character:FindFirstChild("HumanoidRootPart")
	if candidate == nil or not candidate:IsA("BasePart") then
		return nil
	end

	return candidate
end

local function setAutoHarvestEnabled(player: Player, isEnabled: boolean)
	local playerState = getOrCreateState(player)
	if playerState.isEnabled == isEnabled then
		return
	end

	playerState.isEnabled = isEnabled
	if isEnabled then
		if InventoryService.getEquippedItemId(player) ~= "Scythe" then
			playerState.isEnabled = false
			return
		end

		playerState.nextAllowedHarvestTime = Workspace:GetServerTimeNow()
	end
end

local function resolvePlacedPart(requestedTarget: Instance): BasePart?
	local placedObjectsFolder = getPlacedObjectsFolder()
	if placedObjectsFolder == nil then
		return nil
	end

	local current: Instance? = requestedTarget
	while current ~= nil and current ~= placedObjectsFolder do
		if current:IsA("BasePart") and current.Parent == placedObjectsFolder then
			return current
		end
		current = current.Parent
	end

	return nil
end

local function isAutoHarvestableApplePart(part: BasePart): boolean
	local productionBehaviorId = part:GetAttribute(BuildingAttributeNames.productionBehaviorId)
	local outputResourceId = part:GetAttribute(BuildingAttributeNames.productionOutputName)
	local isReadyToHarvest = part:GetAttribute(BuildingAttributeNames.isReadyToHarvest)

	return type(productionBehaviorId) == "string"
		and AUTO_HARVEST_PRODUCTION_BEHAVIORS[productionBehaviorId] == true
		and outputResourceId == APPLE_RESOURCE_ID
		and isReadyToHarvest == true
end

local function isOwnedPartOnAssignedPlot(player: Player, part: BasePart): boolean
	if part:GetAttribute(OWNER_USER_ID_ATTRIBUTE) ~= player.UserId then
		return false
	end

	local assignedPlotName = PlotService.getAssignedPlotName(player)
	return assignedPlotName ~= nil and part:GetAttribute(PLOT_NAME_ATTRIBUTE) == assignedPlotName
end

local function isCloseEnoughToHarvest(player: Player, part: BasePart): boolean
	local rootPart = getHumanoidRootPart(player)
	if rootPart == nil then
		return false
	end

	return (rootPart.Position - part.Position).Magnitude <= AutoHarvestConfig.serverHarvestDistanceStuds
end

local function getAutoHarvestOriginCFrame(rootPart: BasePart, targetPart: BasePart): CFrame
	local targetOffset = targetPart.Position - rootPart.Position
	local planarTargetOffset = Vector3.new(targetOffset.X, 0, targetOffset.Z)
	if planarTargetOffset.Magnitude <= 0.001 then
		return rootPart.CFrame
	end

	return CFrame.lookAt(rootPart.Position, rootPart.Position + planarTargetOffset.Unit, Vector3.yAxis)
end

local function getSwingOverlapParts(originCFrame: CFrame, placedObjectsFolder: Folder): { BasePart }
	local slices = ScytheSwingVolume.getSwingHitboxSlices(originCFrame)
	if #slices == 0 then
		return {}
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { placedObjectsFolder }

	local overlappingParts: { BasePart } = {}
	local seenParts: { [BasePart]: boolean } = {}

	for _, slice in ipairs(slices) do
		for _, part in ipairs(Workspace:GetPartBoundsInBox(slice.cframe, slice.size, overlapParams)) do
			if not seenParts[part] then
				seenParts[part] = true
				table.insert(overlappingParts, part)
			end
		end
	end

	return overlappingParts
end

local function getAutoHarvestParts(player: Player, rootPart: BasePart, targetPart: BasePart, placedObjectsFolder: Folder): { BasePart }
	local originCFrame = getAutoHarvestOriginCFrame(rootPart, targetPart)
	local harvestableParts: { BasePart } = {}

	for _, part in ipairs(getSwingOverlapParts(originCFrame, placedObjectsFolder)) do
		if isOwnedPartOnAssignedPlot(player, part) and isAutoHarvestableApplePart(part) then
			table.insert(harvestableParts, part)
		end
	end

	table.sort(harvestableParts, function(leftPart: BasePart, rightPart: BasePart): boolean
		return (targetPart.Position - leftPart.Position).Magnitude < (targetPart.Position - rightPart.Position).Magnitude
	end)

	return harvestableParts
end

local function canAttemptAutoHarvest(player: Player, playerState: AutoHarvestPlayerState): boolean
	if not playerState.isEnabled then
		return false
	end

	if InventoryService.getEquippedItemId(player) ~= "Scythe" then
		setAutoHarvestEnabled(player, false)
		return false
	end

	local now = Workspace:GetServerTimeNow()
	if now < playerState.nextAllowedHarvestTime then
		return false
	end

	playerState.nextAllowedHarvestTime = now + AutoHarvestConfig.harvestIntervalSeconds
	return true
end

local function handleAutoHarvestStateRequest(player: Player, requestedEnabled: unknown)
	if type(requestedEnabled) ~= "boolean" then
		return
	end

	setAutoHarvestEnabled(player, requestedEnabled)
end

local function handleAutoHarvestRequest(player: Player, requestedTarget: unknown)
	local playerState = getOrCreateState(player)
	if not canAttemptAutoHarvest(player, playerState) then
		return
	end

	if typeof(requestedTarget) ~= "Instance" then
		return
	end

	local placedPart = resolvePlacedPart(requestedTarget :: Instance)
	local rootPart = getHumanoidRootPart(player)
	local placedObjectsFolder = getPlacedObjectsFolder()
	if placedPart == nil
		or rootPart == nil
		or placedObjectsFolder == nil
		or not isOwnedPartOnAssignedPlot(player, placedPart)
		or not isAutoHarvestableApplePart(placedPart)
		or not isCloseEnoughToHarvest(player, placedPart)
	then
		return
	end

	local harvestedCount = 0
	local harvestEffectPayloads: { AppleHarvestEffectPayload } = {}

	for _, harvestPart in ipairs(getAutoHarvestParts(player, rootPart, placedPart, placedObjectsFolder)) do
		if harvestedCount >= AutoHarvestConfig.maxAutoHarvestPartsPerSwing then
			break
		end

		local didHarvest, harvestOutput = ProductionService.tryHarvestPlacedBuilding(harvestPart)
		if didHarvest and harvestOutput ~= nil then
			harvestedCount += 1
			ResourceService.addResource(player, harvestOutput.resourceId, harvestOutput.amount)

			local harvestEffectPayload = HarvestEffectService.createAppleHarvestEffectPayload(harvestPart, harvestOutput)
			if harvestEffectPayload ~= nil then
				table.insert(harvestEffectPayloads, harvestEffectPayload)
			end
		end
	end

	if harvestedCount > 0 then
		Remotes.getHarvestRemotes().scytheHarvestConfirmed:FireClient(player)
		HarvestEffectService.fireAppleHarvestEffects(player, harvestEffectPayloads)
	end
end

local function cleanupPlayer(player: Player)
	local playerState = stateByPlayer[player]
	if playerState == nil then
		return
	end

	stateByPlayer[player] = nil
end

local AutoHarvestService = {}

function AutoHarvestService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local harvestRemotes = Remotes.getHarvestRemotes()
	harvestRemotes.requestAutoHarvestState.OnServerEvent:Connect(handleAutoHarvestStateRequest)
	harvestRemotes.requestAutoHarvest.OnServerEvent:Connect(handleAutoHarvestRequest)
	Players.PlayerRemoving:Connect(cleanupPlayer)
end

return table.freeze(AutoHarvestService)

--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local toolsFolder = sharedFolder:WaitForChild("Tools") :: Folder

local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local ScytheConfig = require(toolsFolder:WaitForChild("ScytheConfig") :: ModuleScript)
local ScytheSwingVolume = require(toolsFolder:WaitForChild("ScytheSwingVolume") :: ModuleScript)
local HarvestEffectService = require(script.Parent.HarvestEffectService)
local InventoryService = require(script.Parent.Parent.Inventory.InventoryService)
local Remotes = require(script.Parent.Parent.Networking.Remotes)
local PlotService = require(script.Parent.Parent.Plots.PlotService)
local ProductionService = require(script.Parent.Parent.Production.ProductionService)
local ResourceService = require(script.Parent.Parent.Resources.ResourceService)

type AppleHarvestEffectPayload = HarvestEffectService.AppleHarvestEffectPayload

local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
local PLOT_NAME_ATTRIBUTE = "PlotName"
local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"

local hasStarted = false
local nextAllowedSwingByPlayer: { [Player]: number } = {}

local TOOL_HARVEST_PRODUCTION_BEHAVIORS: { [string]: boolean } = {
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

local function canHarvestWithTool(part: BasePart): boolean
	local productionBehaviorId = part:GetAttribute(BuildingAttributeNames.productionBehaviorId)
	return type(productionBehaviorId) == "string" and TOOL_HARVEST_PRODUCTION_BEHAVIORS[productionBehaviorId] == true
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

local function isOwnedPartOnAssignedPlot(player: Player, part: BasePart): boolean
	if part:GetAttribute(OWNER_USER_ID_ATTRIBUTE) ~= player.UserId then
		return false
	end

	local assignedPlotName = PlotService.getAssignedPlotName(player)
	return assignedPlotName ~= nil and part:GetAttribute(PLOT_NAME_ATTRIBUTE) == assignedPlotName
end

local function handleScytheSwingRequest(player: Player)
	local now = Workspace:GetServerTimeNow()
	local nextAllowedSwingTime = nextAllowedSwingByPlayer[player] or 0
	if now < nextAllowedSwingTime then
		return
	end

	nextAllowedSwingByPlayer[player] = now + ScytheConfig.cooldownSeconds

	if InventoryService.getEquippedItemId(player) ~= "Scythe" then
		return
	end

	local rootPart = getHumanoidRootPart(player)
	local placedObjectsFolder = getPlacedObjectsFolder()
	if rootPart == nil or placedObjectsFolder == nil then
		return
	end

	local harvestedAny = false
	local harvestEffectPayloads: { AppleHarvestEffectPayload } = {}

	for _, part in ipairs(getSwingOverlapParts(rootPart.CFrame, placedObjectsFolder)) do
		if isOwnedPartOnAssignedPlot(player, part)
			and canHarvestWithTool(part)
		then
			local didHarvest, harvestOutput = ProductionService.tryHarvestPlacedBuilding(part)
			if didHarvest and harvestOutput ~= nil then
				harvestedAny = true
				ResourceService.addResource(player, harvestOutput.resourceId, harvestOutput.amount)

				local harvestEffectPayload = HarvestEffectService.createAppleHarvestEffectPayload(part, harvestOutput)
				if harvestEffectPayload ~= nil then
					table.insert(harvestEffectPayloads, harvestEffectPayload)
				end
			end
		end
	end

	if harvestedAny then
		Remotes.getScytheHarvestConfirmedRemote():FireClient(player)
		HarvestEffectService.fireAppleHarvestEffects(player, harvestEffectPayloads)
	end
end

local HarvestService = {}

function HarvestService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	Remotes.getScytheHarvestConfirmedRemote()
	Remotes.getHarvestRemote().OnServerEvent:Connect(handleScytheSwingRequest)
	Players.PlayerRemoving:Connect(function(player: Player)
		nextAllowedSwingByPlayer[player] = nil
	end)
end

return table.freeze(HarvestService)

--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local InventoryService = require(script.Parent.Parent.Inventory.InventoryService)
local Remotes = require(script.Parent.Parent.Networking.Remotes)
local ProductionService = require(script.Parent.Parent.Production.ProductionService)
local ResourceService = require(script.Parent.Parent.Resources.ResourceService)

local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local SCYTHE_SWING_COOLDOWN_SECONDS = 0.5
local SCYTHE_SWING_HALF_ANGLE_DEGREES = 60
local SCYTHE_SWING_RANGE = 8
local SCYTHE_SWING_VERTICAL_TOLERANCE = 6

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

local function isPartInsideScytheCone(originPart: BasePart, targetPart: BasePart): boolean
	local offset = targetPart.Position - originPart.Position
	local planarOffset = Vector3.new(offset.X, 0, offset.Z)
	local planarDistance = planarOffset.Magnitude
	if planarDistance > SCYTHE_SWING_RANGE then
		return false
	end

	if math.abs(offset.Y) > SCYTHE_SWING_VERTICAL_TOLERANCE then
		return false
	end

	if planarDistance <= 0.001 then
		return true
	end

	local direction = planarOffset.Unit
	local lookVector = Vector3.new(originPart.CFrame.LookVector.X, 0, originPart.CFrame.LookVector.Z)
	if lookVector.Magnitude <= 0.001 then
		return false
	end

	local minimumDot = math.cos(math.rad(SCYTHE_SWING_HALF_ANGLE_DEGREES))
	return lookVector.Unit:Dot(direction) >= minimumDot
end

local function canHarvestWithTool(part: BasePart): boolean
	local productionBehaviorId = part:GetAttribute(BuildingAttributeNames.productionBehaviorId)
	return type(productionBehaviorId) == "string" and TOOL_HARVEST_PRODUCTION_BEHAVIORS[productionBehaviorId] == true
end

local function handleScytheSwingRequest(player: Player)
	local now = Workspace:GetServerTimeNow()
	local nextAllowedSwingTime = nextAllowedSwingByPlayer[player] or 0
	if now < nextAllowedSwingTime then
		return
	end

	nextAllowedSwingByPlayer[player] = now + SCYTHE_SWING_COOLDOWN_SECONDS

	if InventoryService.getEquippedItemId(player) ~= "Scythe" then
		return
	end

	local rootPart = getHumanoidRootPart(player)
	local placedObjectsFolder = getPlacedObjectsFolder()
	if rootPart == nil or placedObjectsFolder == nil then
		return
	end

	for _, child in ipairs(placedObjectsFolder:GetChildren()) do
		if child:IsA("BasePart")
			and child:GetAttribute(OWNER_USER_ID_ATTRIBUTE) == player.UserId
			and canHarvestWithTool(child)
			and isPartInsideScytheCone(rootPart, child)
		then
			local didHarvest, harvestOutput = ProductionService.tryHarvestPlacedBuilding(child)
			if didHarvest and harvestOutput ~= nil then
				ResourceService.addResource(player, harvestOutput.resourceId, harvestOutput.amount)
			end
		end
	end
end

local HarvestService = {}

function HarvestService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	Remotes.getHarvestRemote().OnServerEvent:Connect(handleScytheSwingRequest)
	Players.PlayerRemoving:Connect(function(player: Player)
		nextAllowedSwingByPlayer[player] = nil
	end)
end

return table.freeze(HarvestService)

--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local PlotService = require(script.Parent.Parent.Plots.PlotService)
local ProductionService = require(script.Parent.Parent.Production.ProductionService)
local ResourceService = require(script.Parent.Parent.Resources.ResourceService)

local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
local PLOT_NAME_ATTRIBUTE = "PlotName"
local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local UPDATE_INTERVAL_SECONDS = 0.15
local COLLECTION_MARGIN_STUDS = 1.5
local COLLECTION_VERTICAL_TOLERANCE_STUDS = 7
local COLLECTION_COOLDOWN_SECONDS = 0.25

local WALKOVER_PRODUCTION_BEHAVIORS: { [string]: boolean } = {
	InputProcessor = true,
}

local hasStarted = false
local collectableParts: { [BasePart]: boolean } = {}
local nextAllowedCollectionByPlayerPart: { [Player]: { [BasePart]: number } } = {}

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

local function shouldTrackPart(part: BasePart): boolean
	local productionBehaviorId = part:GetAttribute(BuildingAttributeNames.productionBehaviorId)
	return type(productionBehaviorId) == "string" and WALKOVER_PRODUCTION_BEHAVIORS[productionBehaviorId] == true
end

local function trackPart(part: BasePart)
	if shouldTrackPart(part) then
		collectableParts[part] = true
	else
		collectableParts[part] = nil
	end
end

local function connectPartForTracking(part: BasePart)
	trackPart(part)

	local attributeConnection = part:GetAttributeChangedSignal(BuildingAttributeNames.productionBehaviorId):Connect(function()
		trackPart(part)
	end)

	part.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			collectableParts[part] = nil
			attributeConnection:Disconnect()
		end
	end)
end

local function isRootOverPart(rootPart: BasePart, placedPart: BasePart): boolean
	local localPoint = placedPart.CFrame:PointToObjectSpace(rootPart.Position)
	local halfSize = placedPart.Size * 0.5

	return math.abs(localPoint.X) <= halfSize.X + COLLECTION_MARGIN_STUDS
		and math.abs(localPoint.Z) <= halfSize.Z + COLLECTION_MARGIN_STUDS
		and math.abs(localPoint.Y) <= COLLECTION_VERTICAL_TOLERANCE_STUDS
end

local function canAttemptCollection(player: Player, part: BasePart, currentTime: number): boolean
	local nextAllowedByPart = nextAllowedCollectionByPlayerPart[player]
	if nextAllowedByPart == nil then
		nextAllowedByPart = {}
		nextAllowedCollectionByPlayerPart[player] = nextAllowedByPart
	end

	local nextAllowedTime = nextAllowedByPart[part] or 0
	if currentTime < nextAllowedTime then
		return false
	end

	nextAllowedByPart[part] = currentTime + COLLECTION_COOLDOWN_SECONDS
	return true
end

local function isOwnedPartOnAssignedPlot(player: Player, part: BasePart): boolean
	if part:GetAttribute(OWNER_USER_ID_ATTRIBUTE) ~= player.UserId then
		return false
	end

	local assignedPlotName = PlotService.getAssignedPlotName(player)
	return assignedPlotName ~= nil and part:GetAttribute(PLOT_NAME_ATTRIBUTE) == assignedPlotName
end

local function collectForPlayer(player: Player, rootPart: BasePart, currentTime: number)
	for part in pairs(collectableParts) do
		if part.Parent ~= nil
			and isOwnedPartOnAssignedPlot(player, part)
			and isRootOverPart(rootPart, part)
			and canAttemptCollection(player, part, currentTime)
		then
			local didHarvest, harvestOutput = ProductionService.tryHarvestPlacedBuilding(part)
			if didHarvest and harvestOutput ~= nil then
				ResourceService.addResource(player, harvestOutput.resourceId, harvestOutput.amount)
			end
		end
	end
end

local function registerExistingParts()
	local placedObjectsFolder = getPlacedObjectsFolder()
	if placedObjectsFolder == nil then
		return
	end

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
			collectableParts[child] = nil
		end
	end)
end

local function startCollectionLoop()
	task.spawn(function()
		while true do
			local currentTime = Workspace:GetServerTimeNow()
			for _, player in ipairs(Players:GetPlayers()) do
				local rootPart = getHumanoidRootPart(player)
				if rootPart ~= nil then
					collectForPlayer(player, rootPart, currentTime)
				end
			end

			task.wait(UPDATE_INTERVAL_SECONDS)
		end
	end)
end

local WalkoverCollectionService = {}

function WalkoverCollectionService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	registerExistingParts()
	startCollectionLoop()

	Players.PlayerRemoving:Connect(function(player: Player)
		nextAllowedCollectionByPlayerPart[player] = nil
	end)
end

return table.freeze(WalkoverCollectionService)

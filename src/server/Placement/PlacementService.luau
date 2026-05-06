--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local placementFolder = sharedFolder:WaitForChild("Placement") :: Folder

local BuildingAssetUtils = require(buildingsFolder:WaitForChild("BuildingAssetUtils") :: ModuleScript)
local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local PlotMath = require(placementFolder:WaitForChild("PlotMath") :: ModuleScript)
local Remotes = require(script.Parent.Parent.Networking.Remotes)
local EconomyService = require(script.Parent.Parent.Economy.EconomyService)
local InventoryService = require(script.Parent.Parent.Inventory.InventoryService)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)
local ProductionService = require(script.Parent.Parent.Production.ProductionService)
local PlotService = require(script.Parent.Parent.Plots.PlotService)
local ResourceService = require(script.Parent.Parent.Resources.ResourceService)

type BuildingId = BuildingTypes.BuildingId
type ItemId = InventoryTypes.ItemId
type SavedProductionState = BuildingTypes.SavedProductionState

type PlacedBuildingData = {
	buildingId: BuildingId,
	gridX: number,
	gridZ: number,
	production: SavedProductionState?,
}

type ValidatedPlacedBuildingTarget = {
	part: BasePart,
	buildingId: BuildingId,
}

local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
local PLOT_NAME_ATTRIBUTE = "PlotName"
local PLOT_SLOT_ATTRIBUTE = "PlotSlot"
local ITEM_ID_ATTRIBUTE = "ItemId"
local GRID_X_ATTRIBUTE = "GridX"
local GRID_Z_ATTRIBUTE = "GridZ"
local MAX_PICKUP_DISTANCE_STUDS = 40

local hasStarted = false
local loadedPlayers: { [Player]: boolean } = {}
local canSnapshotPlacedBuildingsByPlayer: { [Player]: boolean } = {}

local function getPlacedObjectsFolder(): Folder
	local existingFolder = Workspace:FindFirstChild(PLACED_OBJECTS_FOLDER_NAME)
	if existingFolder ~= nil then
		assert(existingFolder:IsA("Folder"), string.format("%s must be a Folder", PLACED_OBJECTS_FOLDER_NAME))
		return existingFolder
	end

	local folder = Instance.new("Folder")
	folder.Name = PLACED_OBJECTS_FOLDER_NAME
	folder.Parent = Workspace

	return folder
end

local function isWholeNumber(value: number): boolean
	return value == math.floor(value)
end

local function getPlacedBuildingDataFromPart(player: Player, part: BasePart): PlacedBuildingData?
	if part:GetAttribute(OWNER_USER_ID_ATTRIBUTE) ~= player.UserId then
		return nil
	end

	local rawBuildingId = part:GetAttribute(ITEM_ID_ATTRIBUTE)
	local rawGridX = part:GetAttribute(GRID_X_ATTRIBUTE)
	local rawGridZ = part:GetAttribute(GRID_Z_ATTRIBUTE)

	if type(rawBuildingId) ~= "string"
		or not BuildingCatalog.hasBuildingDefinition(rawBuildingId)
		or type(rawGridX) ~= "number"
		or type(rawGridZ) ~= "number"
		or not isWholeNumber(rawGridX)
		or not isWholeNumber(rawGridZ)
	then
		return nil
	end

	return {
		buildingId = rawBuildingId :: BuildingId,
		gridX = rawGridX,
		gridZ = rawGridZ,
		production = ProductionService.getSavedProductionState(part),
	}
end

local function getPlacedPartFromInstance(instance: Instance): BasePart?
	local placedObjectsFolder = getPlacedObjectsFolder()
	local current: Instance? = instance

	while current ~= nil and current ~= placedObjectsFolder do
		if current:IsA("BasePart") and current.Parent == placedObjectsFolder then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function isPlayerCloseEnoughToPickup(player: Player, placedPart: BasePart): boolean
	local character = player.Character
	if character == nil then
		return false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return false
	end

	return (rootPart.Position - placedPart.Position).Magnitude <= MAX_PICKUP_DISTANCE_STUDS
end

local function serializePlayerPlacedBuildings(player: Player): { PlacedBuildingData }
	local placedBuildings: { PlacedBuildingData } = {}
	local assignedPlotName = PlotService.getAssignedPlotName(player)

	for _, child in ipairs(getPlacedObjectsFolder():GetChildren()) do
		if child:IsA("BasePart") then
			local isOnAssignedPlot = assignedPlotName == nil or child:GetAttribute(PLOT_NAME_ATTRIBUTE) == assignedPlotName
			local placedBuildingData = if isOnAssignedPlot then getPlacedBuildingDataFromPart(player, child) else nil
			if placedBuildingData ~= nil then
				table.insert(placedBuildings, placedBuildingData)
			end
		end
	end

	return placedBuildings
end

local function savePlayerPlacedBuildings(player: Player)
	if canSnapshotPlacedBuildingsByPlayer[player] ~= true then
		return
	end

	PlayerDataService.setPlacedBuildings(player, serializePlayerPlacedBuildings(player))
end

local function isPlacementOverlapping(plotName: string, footprint: Vector3, gridX: number, gridZ: number): boolean
	for _, child in ipairs(getPlacedObjectsFolder():GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute(PLOT_NAME_ATTRIBUTE) == plotName then
			local existingGridX = child:GetAttribute(GRID_X_ATTRIBUTE)
			local existingGridZ = child:GetAttribute(GRID_Z_ATTRIBUTE)

			if type(existingGridX) == "number"
				and type(existingGridZ) == "number"
				and PlotMath.doFootprintsOverlap(gridX, gridZ, footprint, existingGridX, existingGridZ, child.Size) then
				return true
			end
		end
	end

	return false
end

local function createPlacedPart(
	player: Player,
	plotBase: BasePart,
	plotName: string,
	plotSlot: number?,
	buildingId: BuildingId,
	gridX: number,
	gridZ: number
): BasePart?
	local buildingDefinition = BuildingCatalog.getBuildingDefinition(buildingId)
	local placementFootprint = BuildingAssetUtils.getPlacementFootprint(buildingDefinition)
	local placementCFrame = PlotMath.gridToWorldCFrame(plotBase.CFrame, plotBase.Size, placementFootprint, gridX, gridZ)
	if placementCFrame == nil then
		return nil
	end

	local placedPart = Instance.new("Part")
	placedPart.Name = string.format("%sRoot", buildingDefinition.id)
	placedPart.Anchored = true
	placedPart.CanCollide = false
	placedPart.CanQuery = true
	placedPart.CanTouch = false
	placedPart.Transparency = 1
	placedPart.Material = Enum.Material.SmoothPlastic
	placedPart.Size = placementFootprint
	placedPart.CFrame = placementCFrame
	placedPart.TopSurface = Enum.SurfaceType.Smooth
	placedPart.BottomSurface = Enum.SurfaceType.Smooth
	placedPart:SetAttribute(OWNER_USER_ID_ATTRIBUTE, player.UserId)
	placedPart:SetAttribute(PLOT_NAME_ATTRIBUTE, plotName)
	if plotSlot ~= nil then
		placedPart:SetAttribute(PLOT_SLOT_ATTRIBUTE, plotSlot)
	end
	placedPart:SetAttribute(ITEM_ID_ATTRIBUTE, buildingId)
	placedPart:SetAttribute(GRID_X_ATTRIBUTE, gridX)
	placedPart:SetAttribute(GRID_Z_ATTRIBUTE, gridZ)
	placedPart.Parent = getPlacedObjectsFolder()

	return placedPart
end

local function canPlaceBuildingOnPlot(plotBase: BasePart, plotName: string, buildingId: BuildingId, gridX: number, gridZ: number): boolean
	local buildingDefinition = BuildingCatalog.getBuildingDefinition(buildingId)
	local placementFootprint = BuildingAssetUtils.getPlacementFootprint(buildingDefinition)

	if not PlotMath.isGridWithinPlot(plotBase.Size, placementFootprint, gridX, gridZ) then
		return false
	end

	if isPlacementOverlapping(plotName, placementFootprint, gridX, gridZ) then
		return false
	end

	return true
end

local function loadPlayerPlacedBuildings(player: Player)
	if loadedPlayers[player] == true then
		return
	end

	loadedPlayers[player] = true
	PlayerDataService.waitForData(player)

	local plotBase = PlotService.waitForAssignedPlotBase(player, 10)
	local plotName = PlotService.getAssignedPlotName(player)
	if plotBase == nil or plotName == nil then
		loadedPlayers[player] = nil
		return
	end
	local plotSlot = PlotService.getAssignedSlot(player)

	local savedPlacedBuildings = PlayerDataService.getPlacedBuildings(player)
	local loadedCount = 0
	for _, placedBuilding in ipairs(savedPlacedBuildings) do
		local buildingId = placedBuilding.buildingId
		if canPlaceBuildingOnPlot(plotBase, plotName, buildingId, placedBuilding.gridX, placedBuilding.gridZ) then
			local placedPart = createPlacedPart(player, plotBase, plotName, plotSlot, buildingId, placedBuilding.gridX, placedBuilding.gridZ)
			if placedPart ~= nil then
				ProductionService.registerPlacedBuilding(placedPart, buildingId, placedBuilding.production)
				loadedCount += 1
			end
		end
	end

	if #savedPlacedBuildings == 0 or loadedCount > 0 then
		canSnapshotPlacedBuildingsByPlayer[player] = true
	else
		warn(string.format("Skipped building save snapshots for %s because saved buildings could not be loaded.", player.Name))
	end
end

local function cleanupPlayerPlacedBuildings(player: Player)
	loadedPlayers[player] = nil
	canSnapshotPlacedBuildingsByPlayer[player] = nil

	for _, child in ipairs(getPlacedObjectsFolder():GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute(OWNER_USER_ID_ATTRIBUTE) == player.UserId then
			child:Destroy()
		end
	end
end

local function handlePlacementRequest(player: Player, requestedGridX: unknown, requestedGridZ: unknown)
	if type(requestedGridX) ~= "number" or type(requestedGridZ) ~= "number" then
		return
	end

	if not isWholeNumber(requestedGridX) or not isWholeNumber(requestedGridZ) then
		return
	end

	local gridX = requestedGridX
	local gridZ = requestedGridZ
	local plotBase = PlotService.getAssignedPlotBase(player)
	local plotName = PlotService.getAssignedPlotName(player)
	if plotBase == nil or plotName == nil then
		return
	end
	local plotSlot = PlotService.getAssignedSlot(player)

	local itemId = InventoryService.getEquippedItemId(player)
	if itemId == nil then
		return
	end

	local itemDefinition = ItemCatalog.getItemDefinition(itemId)
	if itemDefinition.kind ~= "Placeable" then
		return
	end

	local buildingId = itemId :: BuildingId
	if not canPlaceBuildingOnPlot(plotBase, plotName, buildingId, gridX, gridZ) then
		return
	end

	if not InventoryService.tryConsumeItem(player, itemId, 1) then
		return
	end

	local placedPart = createPlacedPart(player, plotBase, plotName, plotSlot, buildingId, gridX, gridZ)
	if placedPart == nil then
		return
	end

	ProductionService.registerPlacedBuilding(placedPart, buildingId, nil)
	PlayerDataService.addPlacedBuilding(player, buildingId, gridX, gridZ)
end

local function resolveValidatedPlacedBuildingTarget(player: Player, requestedTarget: unknown): ValidatedPlacedBuildingTarget?
	if typeof(requestedTarget) ~= "Instance" then
		return nil
	end

	local placedPart = getPlacedPartFromInstance(requestedTarget :: Instance)
	if placedPart == nil then
		return nil
	end

	if placedPart:GetAttribute(OWNER_USER_ID_ATTRIBUTE) ~= player.UserId then
		return nil
	end

	local assignedPlotName = PlotService.getAssignedPlotName(player)
	if assignedPlotName == nil or placedPart:GetAttribute(PLOT_NAME_ATTRIBUTE) ~= assignedPlotName then
		return nil
	end

	if not isPlayerCloseEnoughToPickup(player, placedPart) then
		return nil
	end

	local rawBuildingId = placedPart:GetAttribute(ITEM_ID_ATTRIBUTE)
	if type(rawBuildingId) ~= "string" or not BuildingCatalog.hasBuildingDefinition(rawBuildingId) then
		return nil
	end

	return {
		part = placedPart,
		buildingId = rawBuildingId :: BuildingId,
	}
end

local function handlePickupRequest(player: Player, requestedTarget: unknown)
	local validatedTarget = resolveValidatedPlacedBuildingTarget(player, requestedTarget)
	if validatedTarget == nil then
		return
	end

	local storedOutput = ProductionService.getStoredOutput(validatedTarget.part)
	if storedOutput ~= nil then
		ResourceService.addResource(player, storedOutput.resourceId, storedOutput.amount)
	end

	InventoryService.addItem(player, validatedTarget.buildingId :: ItemId, 1)
	ProductionService.unregisterPlacedBuilding(validatedTarget.part)
	validatedTarget.part:Destroy()
	savePlayerPlacedBuildings(player)
end

local function handleSellRequest(player: Player, requestedTarget: unknown)
	local validatedTarget = resolveValidatedPlacedBuildingTarget(player, requestedTarget)
	if validatedTarget == nil then
		return
	end

	local storedOutput = ProductionService.getStoredOutput(validatedTarget.part)
	if storedOutput ~= nil then
		ResourceService.addResource(player, storedOutput.resourceId, storedOutput.amount)
	end

	local buildingDefinition = BuildingCatalog.getBuildingDefinition(validatedTarget.buildingId)
	EconomyService.addCash(player, buildingDefinition.sellPrice)
	ProductionService.unregisterPlacedBuilding(validatedTarget.part)
	validatedTarget.part:Destroy()
	savePlayerPlacedBuildings(player)
end

local PlacementService = {}

function PlacementService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local placementRemotes = Remotes.getPlacementRemotes()
	placementRemotes.requestPlacement.OnServerEvent:Connect(handlePlacementRequest)
	placementRemotes.requestPickup.OnServerEvent:Connect(handlePickupRequest)
	placementRemotes.requestSell.OnServerEvent:Connect(handleSellRequest)
	getPlacedObjectsFolder()
	PlayerDataService.observeBeforeSave(savePlayerPlacedBuildings)
	PlayerDataService.observeAfterRemove(cleanupPlayerPlacedBuildings)

	Players.PlayerAdded:Connect(loadPlayerPlacedBuildings)

	for _, player in ipairs(Players:GetPlayers()) do
		loadPlayerPlacedBuildings(player)
	end
end

return table.freeze(PlacementService)

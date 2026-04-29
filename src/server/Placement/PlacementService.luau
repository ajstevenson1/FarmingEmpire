--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local placementFolder = sharedFolder:WaitForChild("Placement") :: Folder

local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local PlotMath = require(placementFolder:WaitForChild("PlotMath") :: ModuleScript)
local Remotes = require(script.Parent.Parent.Networking.Remotes)
local InventoryService = require(script.Parent.Parent.Inventory.InventoryService)
local ProductionService = require(script.Parent.Parent.Production.ProductionService)
local PlotService = require(script.Parent.Parent.Plots.PlotService)

type ItemId = InventoryTypes.ItemId
type ItemDefinition = InventoryTypes.ItemDefinition

local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
local PLOT_NAME_ATTRIBUTE = "PlotName"
local ITEM_ID_ATTRIBUTE = "ItemId"
local GRID_X_ATTRIBUTE = "GridX"
local GRID_Z_ATTRIBUTE = "GridZ"

local hasStarted = false

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

local function createPlacedPart(player: Player, plot: BasePart, itemId: ItemId, itemDefinition: ItemDefinition, gridX: number, gridZ: number): BasePart?
	local placementCFrame = PlotMath.gridToWorldCFrame(plot.CFrame, plot.Size, itemDefinition.placementFootprint, gridX, gridZ)
	if placementCFrame == nil then
		return nil
	end

	local placedPart = Instance.new("Part")
	placedPart.Name = string.format("%sPlaced", itemDefinition.id)
	placedPart.Anchored = true
	placedPart.CanCollide = false
	placedPart.CanQuery = true
	placedPart.CanTouch = false
	placedPart.Color = itemDefinition.placedPartColor
	placedPart.Material = Enum.Material.SmoothPlastic
	placedPart.Size = itemDefinition.placementFootprint
	placedPart.CFrame = placementCFrame
	placedPart.TopSurface = Enum.SurfaceType.Smooth
	placedPart.BottomSurface = Enum.SurfaceType.Smooth
	placedPart:SetAttribute(OWNER_USER_ID_ATTRIBUTE, player.UserId)
	placedPart:SetAttribute(PLOT_NAME_ATTRIBUTE, plot.Name)
	placedPart:SetAttribute(ITEM_ID_ATTRIBUTE, itemId)
	placedPart:SetAttribute(GRID_X_ATTRIBUTE, gridX)
	placedPart:SetAttribute(GRID_Z_ATTRIBUTE, gridZ)
	placedPart.Parent = getPlacedObjectsFolder()

	return placedPart
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
	local plot = PlotService.getAssignedPlot(player)
	if plot == nil then
		return
	end

	local itemId = InventoryService.getEquippedItemId(player)
	if itemId == nil then
		return
	end

	local itemDefinition = ItemCatalog.getItemDefinition(itemId)
	if itemDefinition.kind ~= "Placeable" then
		return
	end

	if not PlotMath.isGridWithinPlot(plot.Size, itemDefinition.placementFootprint, gridX, gridZ) then
		return
	end

	if isPlacementOverlapping(plot.Name, itemDefinition.placementFootprint, gridX, gridZ) then
		return
	end

	if not InventoryService.tryConsumeItem(player, itemId, 1) then
		return
	end

	local placedPart = createPlacedPart(player, plot, itemId, itemDefinition, gridX, gridZ)
	if placedPart == nil then
		return
	end

	ProductionService.registerPlacedBuilding(placedPart, itemId)
end

local PlacementService = {}

function PlacementService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local placementRemote = Remotes.getPlacementRemote()
	placementRemote.OnServerEvent:Connect(handlePlacementRequest)
	getPlacedObjectsFolder()
end

return table.freeze(PlacementService)

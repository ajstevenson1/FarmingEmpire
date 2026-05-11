--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local plotsCodeFolder = sharedFolder:WaitForChild("Plots") :: Folder

local PlotLocator = require(plotsCodeFolder:WaitForChild("PlotLocator") :: ModuleScript)

local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
local PLOT_NAME_ATTRIBUTE = "PlotName"
local MAX_INTERACTION_DISTANCE_STUDS = 40

local PlacedBuildingTargeting = {}

local function getPlacedObjectsFolder(): Folder?
	local placedObjectsFolder = Workspace:FindFirstChild(PLACED_OBJECTS_FOLDER_NAME)
	if placedObjectsFolder == nil or not placedObjectsFolder:IsA("Folder") then
		return nil
	end

	return placedObjectsFolder
end

local function getAssignedPlotName(player: Player): string?
	local plotsFolder = Workspace:FindFirstChild(PlotLocator.PLOTS_FOLDER_NAME)
	if plotsFolder == nil or not plotsFolder:IsA("Folder") then
		return nil
	end

	local assignedPlot = PlotLocator.getAssignedPlot(plotsFolder, player)
	if assignedPlot == nil then
		return nil
	end

	return assignedPlot.Name
end

local function getRaycastResult(screenPosition: Vector2?): RaycastResult?
	local camera = Workspace.CurrentCamera
	local placedObjectsFolder = getPlacedObjectsFolder()
	if camera == nil or placedObjectsFolder == nil then
		return nil
	end

	local pointerPosition = screenPosition or UserInputService:GetMouseLocation()
	local screenRay = camera:ViewportPointToRay(pointerPosition.X, pointerPosition.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { placedObjectsFolder }
	raycastParams.IgnoreWater = true

	return Workspace:Raycast(screenRay.Origin, screenRay.Direction * 1000, raycastParams)
end

local function getPlacedPartFromInstance(instance: Instance): BasePart?
	local placedObjectsFolder = getPlacedObjectsFolder()
	if placedObjectsFolder == nil then
		return nil
	end

	local current: Instance? = instance
	while current ~= nil and current ~= placedObjectsFolder do
		if current:IsA("BasePart") and current.Parent == placedObjectsFolder then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function getCharacterRootPart(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil
	end

	return rootPart
end

local function isCloseEnough(player: Player, placedPart: BasePart): boolean
	local rootPart = getCharacterRootPart(player)
	if rootPart == nil then
		return false
	end

	return (rootPart.Position - placedPart.Position).Magnitude <= MAX_INTERACTION_DISTANCE_STUDS
end

function PlacedBuildingTargeting.getCurrentTarget(player: Player, screenPosition: Vector2?): BasePart?
	local raycastResult = getRaycastResult(screenPosition)
	if raycastResult == nil then
		return nil
	end

	local placedPart = getPlacedPartFromInstance(raycastResult.Instance)
	if placedPart == nil then
		return nil
	end

	if placedPart:GetAttribute(OWNER_USER_ID_ATTRIBUTE) ~= player.UserId then
		return nil
	end

	local assignedPlotName = getAssignedPlotName(player)
	if assignedPlotName == nil or placedPart:GetAttribute(PLOT_NAME_ATTRIBUTE) ~= assignedPlotName then
		return nil
	end

	if not isCloseEnough(player, placedPart) then
		return nil
	end

	return placedPart
end

return table.freeze(PlacedBuildingTargeting)

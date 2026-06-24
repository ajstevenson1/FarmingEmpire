--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local windmillsFolder = sharedFolder:WaitForChild("Windmills") :: Folder

local BuildingAssetUtils = require(buildingsFolder:WaitForChild("BuildingAssetUtils") :: ModuleScript)
local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local WindmillConfig = require(windmillsFolder:WaitForChild("WindmillConfig") :: ModuleScript)

type BuildingId = BuildingTypes.BuildingId

type TrackedPartConnections = {
	buildingIdChanged: RBXScriptConnection,
	growthStageChanged: RBXScriptConnection,
	ancestryChanged: RBXScriptConnection,
}

local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local CURRENT_VISUAL_MODEL_NAME = "CurrentVisual"
local NEXT_VISUAL_MODEL_NAME = "NextVisual"
local PLACEMENT_BOX_NAME = "PlacementBox"
local ROTATE_PART_NAME = "Rotate"
local CLIENT_VISUAL_ATTRIBUTE = "ClientBuildingVisual"
local VISUAL_BUILDING_ID_ATTRIBUTE = "VisualBuildingId"
local VISUAL_STAGE_MODEL_NAME_ATTRIBUTE = "VisualStageModelName"

local hasStarted = false
local trackedConnectionsByPart: { [BasePart]: TrackedPartConnections } = {}
local visualTokenByPart: { [BasePart]: number } = {}

local function getPlacedObjectsFolder(): Folder
	local folder = Workspace:WaitForChild(PLACED_OBJECTS_FOLDER_NAME)
	assert(folder:IsA("Folder"), string.format("Workspace.%s must be a Folder", PLACED_OBJECTS_FOLDER_NAME))
	return folder
end

local function setBasePartVisualProperties(basePart: BasePart, isAnchored: boolean)
	basePart.Anchored = isAnchored
	basePart.CanCollide = false
	basePart.CanQuery = false
	basePart.CanTouch = false
	basePart.CastShadow = false
	basePart.Massless = true
end

local function getRotatingWeldedParts(buildingId: BuildingId, stageModel: Model): { [BasePart]: boolean }
	if not WindmillConfig.isWindmillBuildingId(buildingId) then
		return {}
	end

	local rotatePart = stageModel:FindFirstChild(ROTATE_PART_NAME, true)
	if rotatePart == nil or not rotatePart:IsA("BasePart") then
		return {}
	end

	local rotatingParts: { [BasePart]: boolean } = {}
	for _, descendant in ipairs(stageModel:GetDescendants()) do
		if descendant:IsA("WeldConstraint") then
			local part0 = descendant.Part0
			local part1 = descendant.Part1
			if part0 == rotatePart and part1 ~= nil then
				rotatingParts[part1] = true
			elseif part1 == rotatePart and part0 ~= nil then
				rotatingParts[part0] = true
			end
		end
	end

	rotatingParts[rotatePart] = nil
	return rotatingParts
end

local function destroyVisual(rootPart: BasePart, visualModelName: string)
	local visual = rootPart:FindFirstChild(visualModelName)
	if visual ~= nil then
		visual:Destroy()
	end
end

local function destroyLocalVisuals(rootPart: BasePart)
	destroyVisual(rootPart, CURRENT_VISUAL_MODEL_NAME)
	destroyVisual(rootPart, NEXT_VISUAL_MODEL_NAME)
end

local function getVisualState(part: BasePart): (BuildingId?, string?)
	local buildingId = part:GetAttribute(BuildingAttributeNames.buildingId)
	local stageModelName = part:GetAttribute(BuildingAttributeNames.growthVisualStageName)
	if type(buildingId) ~= "string"
		or not BuildingCatalog.hasBuildingDefinition(buildingId)
		or type(stageModelName) ~= "string"
	then
		return nil, nil
	end

	return buildingId :: BuildingId, stageModelName
end

local function isCurrentClientVisual(rootPart: BasePart, buildingId: BuildingId, stageModelName: string): boolean
	local existingVisual = rootPart:FindFirstChild(CURRENT_VISUAL_MODEL_NAME)
	return existingVisual ~= nil
		and existingVisual:IsA("Model")
		and existingVisual:GetAttribute(CLIENT_VISUAL_ATTRIBUTE) == true
		and existingVisual:GetAttribute(VISUAL_BUILDING_ID_ATTRIBUTE) == buildingId
		and existingVisual:GetAttribute(VISUAL_STAGE_MODEL_NAME_ATTRIBUTE) == stageModelName
end

local function prepareStageModel(stageModel: Model, buildingId: BuildingId, stageModelName: string)
	BuildingAssetUtils.normalizeStageModel(stageModel)
	stageModel.Name = NEXT_VISUAL_MODEL_NAME
	stageModel:SetAttribute(CLIENT_VISUAL_ATTRIBUTE, true)
	stageModel:SetAttribute(VISUAL_BUILDING_ID_ATTRIBUTE, buildingId)
	stageModel:SetAttribute(VISUAL_STAGE_MODEL_NAME_ATTRIBUTE, stageModelName)

	local rotatingWeldedParts = getRotatingWeldedParts(buildingId, stageModel)
	for _, descendant in ipairs(stageModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			setBasePartVisualProperties(descendant, rotatingWeldedParts[descendant] ~= true)
			if descendant.Name == PLACEMENT_BOX_NAME then
				descendant.Transparency = 1
			end
		end
	end
end

local function swapVisual(rootPart: BasePart, buildingId: BuildingId, stageModelName: string)
	if isCurrentClientVisual(rootPart, buildingId, stageModelName) then
		return
	end

	destroyVisual(rootPart, NEXT_VISUAL_MODEL_NAME)

	local buildingDefinition = BuildingCatalog.getBuildingDefinition(buildingId)
	local stageModel = BuildingAssetUtils.getVisualModel(buildingDefinition, stageModelName):Clone()
	prepareStageModel(stageModel, buildingId, stageModelName)
	stageModel:PivotTo(rootPart.CFrame)

	local existingVisual = rootPart:FindFirstChild(CURRENT_VISUAL_MODEL_NAME)
	local nextToken = (visualTokenByPart[rootPart] or 0) + 1
	visualTokenByPart[rootPart] = nextToken

	stageModel.Parent = rootPart

	task.defer(function()
		if visualTokenByPart[rootPart] ~= nextToken then
			if stageModel.Parent ~= nil then
				stageModel:Destroy()
			end
			return
		end

		if rootPart.Parent == nil then
			stageModel:Destroy()
			return
		end

		if existingVisual ~= nil and existingVisual.Parent == rootPart then
			existingVisual:Destroy()
		end

		if stageModel.Parent == rootPart then
			stageModel.Name = CURRENT_VISUAL_MODEL_NAME
		end
	end)
end

local function refreshVisual(part: BasePart)
	local buildingId, stageModelName = getVisualState(part)
	if buildingId == nil or stageModelName == nil then
		destroyLocalVisuals(part)
		return
	end

	swapVisual(part, buildingId, stageModelName)
end

local function disconnectPart(part: BasePart)
	local connections = trackedConnectionsByPart[part]
	if connections == nil then
		return
	end

	connections.buildingIdChanged:Disconnect()
	connections.growthStageChanged:Disconnect()
	connections.ancestryChanged:Disconnect()
	trackedConnectionsByPart[part] = nil
	visualTokenByPart[part] = nil
	destroyLocalVisuals(part)
end

local function connectPart(part: BasePart)
	if trackedConnectionsByPart[part] ~= nil then
		refreshVisual(part)
		return
	end

	trackedConnectionsByPart[part] = {
		buildingIdChanged = part:GetAttributeChangedSignal(BuildingAttributeNames.buildingId):Connect(function()
			refreshVisual(part)
		end),
		growthStageChanged = part:GetAttributeChangedSignal(BuildingAttributeNames.growthVisualStageName):Connect(function()
			refreshVisual(part)
		end),
		ancestryChanged = part.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				disconnectPart(part)
			end
		end),
	}

	refreshVisual(part)
end

local BuildingVisualController = {}

function BuildingVisualController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local placedObjectsFolder = getPlacedObjectsFolder()
	for _, child in ipairs(placedObjectsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			connectPart(child)
		end
	end

	placedObjectsFolder.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			connectPart(child)
		end
	end)

	placedObjectsFolder.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") then
			disconnectPart(child)
		end
	end)
end

return table.freeze(BuildingVisualController)

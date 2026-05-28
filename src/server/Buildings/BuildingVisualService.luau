--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsCodeFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local windmillsFolder = sharedFolder:WaitForChild("Windmills") :: Folder

local BuildingAssetUtils = require(buildingsCodeFolder:WaitForChild("BuildingAssetUtils") :: ModuleScript)
local BuildingCatalog = require(buildingsCodeFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsCodeFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local WindmillConfig = require(windmillsFolder:WaitForChild("WindmillConfig") :: ModuleScript)

type BuildingDefinition = BuildingTypes.BuildingDefinition
type BuildingId = BuildingTypes.BuildingId

local VISUAL_MODEL_NAME = "CurrentVisual"
local NEXT_VISUAL_MODEL_NAME = "NextVisual"
local PREVIOUS_VISUAL_MODEL_NAME = "PreviousVisual"
local PLACEMENT_BOX_NAME = "PlacementBox"
local VISUAL_SWAP_OVERLAP_SECONDS = 0.05

local function setBasePartVisualProperties(basePart: BasePart, isAnchored: boolean)
	basePart.Anchored = isAnchored
	basePart.CanCollide = false
	basePart.CanQuery = false
	basePart.CanTouch = false
	basePart.CastShadow = false
end

local function getRotatingWeldedParts(buildingId: BuildingId, stageModel: Model): { [BasePart]: boolean }
	if not WindmillConfig.isWindmillBuildingId(buildingId) then
		return {}
	end

	local rotatePart = stageModel:FindFirstChild("Rotate", true)
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

local BuildingVisualService = {}

function BuildingVisualService.setGrowthStageVisual(rootPart: BasePart, buildingId: BuildingId, stageModelName: string)
	local existingVisual = rootPart:FindFirstChild(VISUAL_MODEL_NAME)
	local existingNextVisual = rootPart:FindFirstChild(NEXT_VISUAL_MODEL_NAME)
	if existingNextVisual ~= nil then
		existingNextVisual:Destroy()
	end
	local existingPreviousVisual = rootPart:FindFirstChild(PREVIOUS_VISUAL_MODEL_NAME)
	if existingPreviousVisual ~= nil then
		existingPreviousVisual:Destroy()
	end

	local buildingDefinition = BuildingCatalog.getBuildingDefinition(buildingId)
	local stageModel = BuildingAssetUtils.getVisualModel(buildingDefinition, stageModelName):Clone()
	BuildingAssetUtils.normalizeStageModel(stageModel)
	stageModel.Name = NEXT_VISUAL_MODEL_NAME
	stageModel:PivotTo(rootPart.CFrame)

	local rotatingWeldedParts = getRotatingWeldedParts(buildingId, stageModel)
	for _, descendant in ipairs(stageModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			setBasePartVisualProperties(descendant, rotatingWeldedParts[descendant] ~= true)
			if descendant.Name == PLACEMENT_BOX_NAME then
				descendant.Transparency = 1
			end
		end
	end

	if existingVisual ~= nil then
		existingVisual.Name = PREVIOUS_VISUAL_MODEL_NAME
	end
	stageModel.Parent = rootPart
	stageModel.Name = VISUAL_MODEL_NAME

	if existingVisual ~= nil then
		task.delay(VISUAL_SWAP_OVERLAP_SECONDS, function()
			if existingVisual.Parent == rootPart then
				existingVisual:Destroy()
			end
		end)
	end
end

return table.freeze(BuildingVisualService)

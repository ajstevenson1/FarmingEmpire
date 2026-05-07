--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsCodeFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder

local BuildingAssetUtils = require(buildingsCodeFolder:WaitForChild("BuildingAssetUtils") :: ModuleScript)
local BuildingTypes = require(buildingsCodeFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)

type BuildingDefinition = BuildingTypes.BuildingDefinition
type ItemDefinition = InventoryTypes.ItemDefinition

export type PlacementPreviewView = {
	_selectionBox: SelectionBox,
	_previewModel: Model?,
	_previewHighlightTarget: BasePart?,
	_currentBuildingId: string?,
	show: (self: PlacementPreviewView, buildingDefinition: BuildingDefinition, _itemDefinition: ItemDefinition, placementCFrame: CFrame, isValid: boolean) -> (),
	hide: (self: PlacementPreviewView) -> (),
	destroy: (self: PlacementPreviewView) -> (),
}

local VALID_OUTLINE_COLOR = Color3.fromRGB(112, 212, 123)
local INVALID_OUTLINE_COLOR = Color3.fromRGB(205, 91, 91)
local PREVIEW_MODEL_NAME = "PlacementPreviewModel"
local PREVIEW_HIGHLIGHT_PART_NAME = "PlacementBox"
local STAGE_ZERO_MODEL_NAME = "Stage0"

local PlacementPreviewView = {}
PlacementPreviewView.__index = PlacementPreviewView

local function getStageZeroSourceModel(buildingDefinition: BuildingDefinition): Model
	return BuildingAssetUtils.getStageModel(buildingDefinition, STAGE_ZERO_MODEL_NAME)
end

local function applyPreviewVisualState(model: Model, isValid: boolean)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false

			if descendant.Name == PREVIEW_HIGHLIGHT_PART_NAME then
				descendant.Transparency = 1
			else
				descendant.Transparency = if isValid then 0.45 else 0.6
			end
		end
	end
end

local function getPreviewHighlightTarget(model: Model): BasePart?
	local candidate = model:FindFirstChild(PREVIEW_HIGHLIGHT_PART_NAME, true)
	if candidate ~= nil and candidate:IsA("BasePart") then
		return candidate
	end

	return nil
end

function PlacementPreviewView.new(): PlacementPreviewView
	local selectionBox = Instance.new("SelectionBox")
	selectionBox.Name = "PlacementPreviewSelectionBox"
	selectionBox.LineThickness = 0.05
	selectionBox.SurfaceTransparency = 1
	selectionBox.Transparency = 0
	selectionBox.Parent = Workspace

	local self = setmetatable({
		_selectionBox = selectionBox,
		_previewModel = nil,
		_previewHighlightTarget = nil,
		_currentBuildingId = nil,
	}, PlacementPreviewView) :: PlacementPreviewView

	self:hide()

	return self
end

function PlacementPreviewView:show(buildingDefinition: BuildingDefinition, _itemDefinition: ItemDefinition, placementCFrame: CFrame, isValid: boolean)
	if self._previewModel == nil or self._currentBuildingId ~= buildingDefinition.id then
		if self._previewModel ~= nil then
			self._previewModel:Destroy()
		end

		self._previewModel = getStageZeroSourceModel(buildingDefinition):Clone()
		BuildingAssetUtils.normalizeStageModel(self._previewModel)
		BuildingAssetUtils.applyVisualVariant(self._previewModel, buildingDefinition)
		self._previewModel.Name = PREVIEW_MODEL_NAME
		self._previewModel.Parent = Workspace
		self._previewHighlightTarget = getPreviewHighlightTarget(self._previewModel)
		self._currentBuildingId = buildingDefinition.id
	end

	local previewModel = self._previewModel
	assert(previewModel ~= nil, "Preview model must exist before showing placement preview")

	if previewModel.Parent == nil then
		previewModel.Parent = Workspace
	end

	previewModel:PivotTo(placementCFrame)
	applyPreviewVisualState(previewModel, isValid)

	self._selectionBox.Adornee = self._previewHighlightTarget or previewModel.PrimaryPart
	self._selectionBox.Color3 = if isValid then VALID_OUTLINE_COLOR else INVALID_OUTLINE_COLOR
	self._selectionBox.Parent = Workspace
end

function PlacementPreviewView:hide()
	if self._previewModel ~= nil then
		self._previewModel.Parent = nil
	end

	self._selectionBox.Adornee = nil
	self._selectionBox.Parent = nil
end

function PlacementPreviewView:destroy()
	if self._previewModel ~= nil then
		self._previewModel:Destroy()
		self._previewModel = nil
	end

	self._previewHighlightTarget = nil

	self._selectionBox:Destroy()
end

return PlacementPreviewView

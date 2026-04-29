--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder

local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)

type ItemDefinition = InventoryTypes.ItemDefinition

export type PlacementPreviewView = {
	_previewPart: Part,
	show: (self: PlacementPreviewView, itemDefinition: ItemDefinition, placementCFrame: CFrame, isValid: boolean) -> (),
	hide: (self: PlacementPreviewView) -> (),
	destroy: (self: PlacementPreviewView) -> (),
}

local INVALID_COLOR = Color3.fromRGB(205, 91, 91)

local PlacementPreviewView = {}
PlacementPreviewView.__index = PlacementPreviewView

function PlacementPreviewView.new(): PlacementPreviewView
	local previewPart = Instance.new("Part")
	previewPart.Name = "PlacementPreview"
	previewPart.Anchored = true
	previewPart.CanCollide = false
	previewPart.CanQuery = false
	previewPart.CanTouch = false
	previewPart.CastShadow = false
	previewPart.Material = Enum.Material.ForceField
	previewPart.TopSurface = Enum.SurfaceType.Smooth
	previewPart.BottomSurface = Enum.SurfaceType.Smooth
	previewPart.Transparency = 0.1
	previewPart.Parent = Workspace

	local self = setmetatable({
		_previewPart = previewPart,
	}, PlacementPreviewView) :: PlacementPreviewView

	self:hide()

	return self
end

function PlacementPreviewView:show(itemDefinition: ItemDefinition, placementCFrame: CFrame, isValid: boolean)
	self._previewPart.Size = itemDefinition.placementFootprint
	self._previewPart.CFrame = placementCFrame
	self._previewPart.Color = if isValid then itemDefinition.placementPreviewColor else INVALID_COLOR
	self._previewPart.Transparency = if isValid then 0.1 else 0.2
	self._previewPart.Parent = Workspace
end

function PlacementPreviewView:hide()
	self._previewPart.Parent = nil
end

function PlacementPreviewView:destroy()
	self._previewPart:Destroy()
end

return PlacementPreviewView

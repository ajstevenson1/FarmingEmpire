--!strict

local Workspace = game:GetService("Workspace")

export type StructureSelectionView = {
	_selectionBox: SelectionBox,
	show: (self: StructureSelectionView, targetPart: BasePart) -> (),
	hide: (self: StructureSelectionView) -> (),
	destroy: (self: StructureSelectionView) -> (),
}

local StructureSelectionView = {}
StructureSelectionView.__index = StructureSelectionView

function StructureSelectionView.new(name: string, outlineColor: Color3): StructureSelectionView
	local selectionBox = Instance.new("SelectionBox")
	selectionBox.Name = name
	selectionBox.Color3 = outlineColor
	selectionBox.LineThickness = 0.05
	selectionBox.SurfaceTransparency = 1
	selectionBox.Transparency = 0

	local self = setmetatable({
		_selectionBox = selectionBox,
	}, StructureSelectionView) :: StructureSelectionView

	self:hide()

	return self
end

function StructureSelectionView:show(targetPart: BasePart)
	self._selectionBox.Adornee = targetPart
	self._selectionBox.Parent = Workspace
end

function StructureSelectionView:hide()
	self._selectionBox.Adornee = nil
	self._selectionBox.Parent = nil
end

function StructureSelectionView:destroy()
	self._selectionBox:Destroy()
end

return StructureSelectionView

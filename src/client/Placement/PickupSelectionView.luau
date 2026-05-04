--!strict

local Workspace = game:GetService("Workspace")

export type PickupSelectionView = {
	_selectionBox: SelectionBox,
	show: (self: PickupSelectionView, targetPart: BasePart) -> (),
	hide: (self: PickupSelectionView) -> (),
	destroy: (self: PickupSelectionView) -> (),
}

local OUTLINE_COLOR = Color3.fromRGB(112, 212, 123)

local PickupSelectionView = {}
PickupSelectionView.__index = PickupSelectionView

function PickupSelectionView.new(): PickupSelectionView
	local selectionBox = Instance.new("SelectionBox")
	selectionBox.Name = "PickupSelectionBox"
	selectionBox.Color3 = OUTLINE_COLOR
	selectionBox.LineThickness = 0.05
	selectionBox.SurfaceTransparency = 1
	selectionBox.Transparency = 0

	local self = setmetatable({
		_selectionBox = selectionBox,
	}, PickupSelectionView) :: PickupSelectionView

	self:hide()

	return self
end

function PickupSelectionView:show(targetPart: BasePart)
	self._selectionBox.Adornee = targetPart
	self._selectionBox.Parent = Workspace
end

function PickupSelectionView:hide()
	self._selectionBox.Adornee = nil
	self._selectionBox.Parent = nil
end

function PickupSelectionView:destroy()
	self._selectionBox:Destroy()
end

return PickupSelectionView

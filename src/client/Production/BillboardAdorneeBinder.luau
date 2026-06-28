--!strict

export type BillboardAdorneeBinder = {
	_rootPart: BasePart,
	_billboardGui: BillboardGui,
	_connections: { RBXScriptConnection },
	_visualConnectionsByModel: { [Model]: { RBXScriptConnection } },
	refresh: (self: BillboardAdorneeBinder) -> (),
	destroy: (self: BillboardAdorneeBinder) -> (),
}

local CURRENT_VISUAL_MODEL_NAME = "CurrentVisual"
local BILLBOARD_PART_NAME = "Billboard"

local BillboardAdorneeBinder = {}
BillboardAdorneeBinder.__index = BillboardAdorneeBinder

local function findBillboardPart(rootPart: BasePart): BasePart?
	local currentVisual = rootPart:FindFirstChild(CURRENT_VISUAL_MODEL_NAME)
	if currentVisual == nil or not currentVisual:IsA("Model") then
		return nil
	end

	local billboardPart = currentVisual:FindFirstChild(BILLBOARD_PART_NAME, true)
	if billboardPart == nil or not billboardPart:IsA("BasePart") then
		return nil
	end

	return billboardPart
end

local function disconnectAll(connections: { RBXScriptConnection })
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end

	table.clear(connections)
end

local function disconnectVisualModel(self: BillboardAdorneeBinder, model: Model)
	local connections = self._visualConnectionsByModel[model]
	if connections == nil then
		return
	end

	disconnectAll(connections)
	self._visualConnectionsByModel[model] = nil
end

local function connectVisualModel(self: BillboardAdorneeBinder, child: Instance)
	if not child:IsA("Model") then
		return
	end

	local model = child :: Model
	if self._visualConnectionsByModel[model] ~= nil then
		return
	end

	local connections: { RBXScriptConnection } = {}
	self._visualConnectionsByModel[model] = connections

	table.insert(connections, model:GetPropertyChangedSignal("Name"):Connect(function()
		self:refresh()
	end))

	table.insert(connections, model.DescendantAdded:Connect(function(descendant: Instance)
		if descendant.Name == BILLBOARD_PART_NAME and descendant:IsA("BasePart") then
			self:refresh()
		end
	end))

	table.insert(connections, model.AncestryChanged:Connect(function(_, parent: Instance?)
		if parent ~= self._rootPart then
			disconnectVisualModel(self, model)
			self:refresh()
		end
	end))
end

function BillboardAdorneeBinder.new(rootPart: BasePart, billboardGui: BillboardGui): BillboardAdorneeBinder
	local self = setmetatable({
		_rootPart = rootPart,
		_billboardGui = billboardGui,
		_connections = {},
		_visualConnectionsByModel = {},
	}, BillboardAdorneeBinder) :: BillboardAdorneeBinder

	table.insert(self._connections, rootPart.ChildAdded:Connect(function(child: Instance)
		connectVisualModel(self, child)
		self:refresh()
	end))

	table.insert(self._connections, rootPart.ChildRemoved:Connect(function(child: Instance)
		if child:IsA("Model") then
			disconnectVisualModel(self, child)
		end

		self:refresh()
	end))

	for _, child in ipairs(rootPart:GetChildren()) do
		connectVisualModel(self, child)
	end

	self:refresh()
	return self
end

function BillboardAdorneeBinder:refresh()
	self._billboardGui.Adornee = findBillboardPart(self._rootPart) or self._rootPart
end

function BillboardAdorneeBinder:destroy()
	disconnectAll(self._connections)
	for model in pairs(self._visualConnectionsByModel) do
		disconnectVisualModel(self, model)
	end
end

return BillboardAdorneeBinder

--!strict

local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local sharedToolsFolder = sharedFolder:WaitForChild("Tools") :: Folder

local ScytheSwingVolume = require(sharedToolsFolder:WaitForChild("ScytheSwingVolume") :: ModuleScript)

export type ScytheDebugView = {
	_rootFolder: Folder,
	_nextDebugId: number,
	showSwingHitbox: (self: ScytheDebugView, originCFrame: CFrame) -> (),
	destroy: (self: ScytheDebugView) -> (),
}

local DEBUG_FOLDER_NAME = "ScytheDebug"
local DEBUG_VISUAL_PREFIX = "SwingHitbox"
local DEBUG_LIFETIME_SECONDS = 0.18
local DEBUG_SLICE_TRANSPARENCY = 0.72
local DEBUG_SLICE_COLOR = Color3.fromRGB(124, 229, 142)
local DEBUG_SLICE_MATERIAL = Enum.Material.Neon

local ScytheDebugView = {}
ScytheDebugView.__index = ScytheDebugView

local function createSlice(parent: Instance, size: Vector3, sliceCFrame: CFrame)
	local slice = Instance.new("Part")
	slice.Name = "Slice"
	slice.Anchored = true
	slice.CanCollide = false
	slice.CanQuery = false
	slice.CanTouch = false
	slice.CastShadow = false
	slice.Locked = true
	slice.Material = DEBUG_SLICE_MATERIAL
	slice.Color = DEBUG_SLICE_COLOR
	slice.Transparency = DEBUG_SLICE_TRANSPARENCY
	slice.Size = size
	slice.CFrame = sliceCFrame
	slice.Parent = parent
end

function ScytheDebugView.new(): ScytheDebugView
	local rootFolder = Instance.new("Folder")
	rootFolder.Name = DEBUG_FOLDER_NAME
	rootFolder.Parent = Workspace

	return setmetatable({
		_rootFolder = rootFolder,
		_nextDebugId = 0,
	}, ScytheDebugView) :: ScytheDebugView
end

function ScytheDebugView:showSwingHitbox(originCFrame: CFrame)
	local slices = ScytheSwingVolume.getSwingHitboxSlices(originCFrame)
	if #slices == 0 then
		return
	end

	self._nextDebugId += 1

	local debugFolder = Instance.new("Folder")
	debugFolder.Name = string.format("%s%d", DEBUG_VISUAL_PREFIX, self._nextDebugId)
	debugFolder.Parent = self._rootFolder

	for _, slice in ipairs(slices) do
		createSlice(debugFolder, slice.size, slice.cframe)
	end

	Debris:AddItem(debugFolder, DEBUG_LIFETIME_SECONDS)
end

function ScytheDebugView:destroy()
	self._rootFolder:Destroy()
end

return table.freeze({
	new = ScytheDebugView.new,
})

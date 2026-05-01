--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before starting ScytheController")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder

local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)

local SYSTEM_TOOL_ITEM_ID_ATTRIBUTE = "SystemToolItemId"
local SCYTHE_ITEM_ID = "Scythe"
local SWING_ANIMATION_NAME = "Swing"
local SWING_LOCK_DURATION_SECONDS = 0.5

type ToolConnections = {
	activated: RBXScriptConnection,
	ancestryChanged: RBXScriptConnection,
}

local hasStarted = false
local trackedTools: { [Tool]: ToolConnections } = {}
local swingTracksByTool: { [Tool]: AnimationTrack } = {}
local nextAllowedSwingTime = 0

local function getHarvestRemote(): RemoteEvent
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local harvestFolder = rootFolder:WaitForChild(RemoteNames.harvestFolderName) :: Folder
	return harvestFolder:WaitForChild(RemoteNames.requestScytheSwingEventName) :: RemoteEvent
end

local function getHumanoid(): Humanoid?
	local character = localPlayer.Character
	if character == nil then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function getAnimator(humanoid: Humanoid): Animator?
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator ~= nil then
		return animator
	end

	local candidate = Instance.new("Animator")
	candidate.Parent = humanoid
	return candidate
end

local function getSwingTrack(tool: Tool, animator: Animator): AnimationTrack?
	local cachedTrack = swingTracksByTool[tool]
	if cachedTrack ~= nil then
		return cachedTrack
	end

	local animationInstance = tool:FindFirstChild(SWING_ANIMATION_NAME)
	if animationInstance == nil or not animationInstance:IsA("Animation") then
		warn(string.format("[ScytheController] Tool %s is missing Animation %s", tool.Name, SWING_ANIMATION_NAME))
		return nil
	end

	local loadedTrack = animator:LoadAnimation(animationInstance)
	swingTracksByTool[tool] = loadedTrack
	return loadedTrack
end

local function playSwing(tool: Tool): boolean
	local now = os.clock()
	if now < nextAllowedSwingTime then
		return false
	end

	local humanoid = getHumanoid()
	if humanoid == nil then
		return false
	end

	local animator = getAnimator(humanoid)
	if animator == nil then
		return false
	end

	local swingTrack = getSwingTrack(tool, animator)
	if swingTrack == nil then
		return false
	end

	nextAllowedSwingTime = now + SWING_LOCK_DURATION_SECONDS

	swingTrack:Stop(0)
	swingTrack:Play(0.05, 1, 1)
	return true
end

local function cleanupTool(tool: Tool)
	local connections = trackedTools[tool]
	if connections == nil then
		return
	end

	connections.activated:Disconnect()
	connections.ancestryChanged:Disconnect()
	trackedTools[tool] = nil

	local swingTrack = swingTracksByTool[tool]
	if swingTrack ~= nil then
		swingTrack:Stop(0)
		swingTracksByTool[tool] = nil
	end
end

local function bindTool(tool: Tool)
	if trackedTools[tool] ~= nil then
		return
	end

	if tool:GetAttribute(SYSTEM_TOOL_ITEM_ID_ATTRIBUTE) ~= SCYTHE_ITEM_ID then
		return
	end

	trackedTools[tool] = {
		activated = tool.Activated:Connect(function()
			if playSwing(tool) then
				getHarvestRemote():FireServer()
			end
		end),
		ancestryChanged = tool.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				cleanupTool(tool)
			end
		end),
	}
end

local function scanContainer(container: Instance?)
	if container == nil then
		return
	end

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") then
			bindTool(child)
		end
	end
end

local ScytheController = {}

function ScytheController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local backpack = localPlayer:WaitForChild("Backpack")
	scanContainer(backpack)
	scanContainer(localPlayer.Character)

	backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			bindTool(child)
		end
	end)

	localPlayer.CharacterAdded:Connect(function(character)
		nextAllowedSwingTime = 0
		scanContainer(character)

		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				bindTool(child)
			end
		end)
	end)

	if localPlayer.Character ~= nil then
		local character = localPlayer.Character
		assert(character ~= nil)
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				bindTool(child)
			end
		end)
	end
end

return table.freeze(ScytheController)

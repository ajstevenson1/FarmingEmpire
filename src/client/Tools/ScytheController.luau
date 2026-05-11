--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before starting ScytheController")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local sharedToolsFolder = sharedFolder:WaitForChild("Tools") :: Folder

local AudioService = require(script.Parent.Parent.Audio.AudioService)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local ScytheConfig = require(sharedToolsFolder:WaitForChild("ScytheConfig") :: ModuleScript)

local SYSTEM_TOOL_ITEM_ID_ATTRIBUTE = "SystemToolItemId"
local SCYTHE_ITEM_ID = "Scythe"
local SWING_ANIMATION_NAME = "Swing"
local SWING_SOUND_NAME = "ScytheSwingSound"
local HARVEST_SOUND_NAME = "ScytheHarvestSound"

type ToolConnections = {
	activated: RBXScriptConnection,
	ancestryChanged: RBXScriptConnection,
}

type ToolSoundInstances = {
	swing: Sound,
	harvest: Sound,
}

local hasStarted = false
local trackedTools: { [Tool]: ToolConnections } = {}
local swingTracksByTool: { [Tool]: AnimationTrack } = {}
local soundInstancesByTool: { [Tool]: ToolSoundInstances } = {}
local nextAllowedSwingTime = 0

local function getHarvestRemote(): RemoteEvent
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local harvestFolder = rootFolder:WaitForChild(RemoteNames.harvestFolderName) :: Folder
	return harvestFolder:WaitForChild(RemoteNames.requestScytheSwingEventName) :: RemoteEvent
end

local function getHarvestConfirmedRemote(): RemoteEvent
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local harvestFolder = rootFolder:WaitForChild(RemoteNames.harvestFolderName) :: Folder
	return harvestFolder:WaitForChild(RemoteNames.scytheHarvestConfirmedEventName) :: RemoteEvent
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

local function getToolSoundParent(tool: Tool): Instance?
	local handle = tool:FindFirstChild("Handle")
	if handle ~= nil and handle:IsA("BasePart") then
		return handle
	end

	local fallbackPart = tool:FindFirstChildWhichIsA("BasePart", true)
	if fallbackPart ~= nil then
		return fallbackPart
	end

	warn(string.format("[ScytheController] Tool %s is missing a BasePart for sound playback", tool.Name))
	return nil
end

local function configureSound(sound: Sound, soundConfig: typeof(ScytheConfig.sounds.swing))
	sound.SoundId = soundConfig.soundId
	sound.Volume = soundConfig.volume
	sound.PlaybackSpeed = soundConfig.playbackSpeed
	AudioService.assignSoundToBus(sound, "SFX")
end

local function getOrCreateConfiguredSound(parent: Instance, soundName: string, soundConfig: typeof(ScytheConfig.sounds.swing)): Sound
	local existing = parent:FindFirstChild(soundName)
	if existing ~= nil then
		assert(existing:IsA("Sound"), string.format("%s already exists and is not a Sound", soundName))
		configureSound(existing, soundConfig)
		return existing
	end

	local sound = Instance.new("Sound")
	sound.Name = soundName
	configureSound(sound, soundConfig)
	sound.Parent = parent
	return sound
end

local function getToolSounds(tool: Tool): ToolSoundInstances?
	local cachedSounds = soundInstancesByTool[tool]
	if cachedSounds ~= nil then
		return cachedSounds
	end

	local soundParent = getToolSoundParent(tool)
	if soundParent == nil then
		return nil
	end

	local createdSounds: ToolSoundInstances = {
		swing = getOrCreateConfiguredSound(soundParent, SWING_SOUND_NAME, ScytheConfig.sounds.swing),
		harvest = getOrCreateConfiguredSound(soundParent, HARVEST_SOUND_NAME, ScytheConfig.sounds.harvestConfirm),
	}
	soundInstancesByTool[tool] = createdSounds
	return createdSounds
end

local function playToolSound(tool: Tool, soundKind: "swing" | "harvest")
	local toolSounds = getToolSounds(tool)
	if toolSounds == nil then
		return
	end

	local sound = toolSounds[soundKind]
	sound:Stop()
	sound.TimePosition = 0
	sound:Play()
end

local function getEquippedScytheTool(): Tool?
	local character = localPlayer.Character
	if character == nil then
		return nil
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute(SYSTEM_TOOL_ITEM_ID_ATTRIBUTE) == SCYTHE_ITEM_ID then
			return child
		end
	end

	return nil
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

	nextAllowedSwingTime = now + ScytheConfig.cooldownSeconds

	swingTrack:Stop(0)
	swingTrack:Play(0.05, 1, 1)
	playToolSound(tool, "swing")
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

	soundInstancesByTool[tool] = nil
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

function ScytheController.tryPlaySwing(): boolean
	local equippedTool = getEquippedScytheTool()
	if equippedTool == nil then
		return false
	end

	return playSwing(equippedTool)
end

function ScytheController.start()
	if hasStarted then
		return
	end

	hasStarted = true
	AudioService.start()

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

	getHarvestConfirmedRemote().OnClientEvent:Connect(function()
		local equippedTool = getEquippedScytheTool()
		if equippedTool == nil then
			return
		end

		playToolSound(equippedTool, "harvest")
	end)
end

return table.freeze(ScytheController)

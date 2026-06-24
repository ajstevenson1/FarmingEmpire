--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local audioFolder = sharedFolder:WaitForChild("Audio") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local plotsFolder = sharedFolder:WaitForChild("Plots") :: Folder
local progressionFolder = sharedFolder:WaitForChild("Progression") :: Folder

local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local PlotLocator = require(plotsFolder:WaitForChild("PlotLocator") :: ModuleScript)
local ProgressionConfig = require(progressionFolder:WaitForChild("ProgressionConfig") :: ModuleScript)
local TreeAmbientSoundConfig = require(audioFolder:WaitForChild("TreeAmbientSoundConfig") :: ModuleScript)
local AudioService = require(script.Parent.AudioService)

type TrackedTreeSound = {
	part: BasePart,
	sound: Sound?,
	baseVolume: number,
	isPlaying: boolean,
	connections: { RBXScriptConnection },
}

local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local CHARACTER_ROOT_PART_NAME = "HumanoidRootPart"
local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
local PLOT_NAME_ATTRIBUTE = "PlotName"

local localPlayer = Players.LocalPlayer
local trackedSoundsByPart: { [BasePart]: TrackedTreeSound } = {}
local pendingAttributeConnectionsByPart: { [BasePart]: { RBXScriptConnection } } = {}
local hasStarted = false

local function getCharacterRootPart(): BasePart?
	local character = localPlayer.Character
	if character == nil then
		return nil
	end

	local rootPart = character:FindFirstChild(CHARACTER_ROOT_PART_NAME)
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil
	end

	return rootPart
end

local function getPlacedObjectsFolder(): Folder
	local folder = Workspace:WaitForChild(PLACED_OBJECTS_FOLDER_NAME)
	assert(folder:IsA("Folder"), string.format("%s must be a Folder", PLACED_OBJECTS_FOLDER_NAME))
	return folder
end

local function getAssignedPlotName(): string?
	local assignedPlotName = localPlayer:GetAttribute(PlotLocator.PlayerAttributes.assignedPlotName)
	return if type(assignedPlotName) == "string" then assignedPlotName else nil
end

local function isOwnedPartOnAssignedPlot(part: BasePart): boolean
	if part:GetAttribute(OWNER_USER_ID_ATTRIBUTE) ~= localPlayer.UserId then
		return false
	end

	local assignedPlotName = getAssignedPlotName()
	return assignedPlotName ~= nil and part:GetAttribute(PLOT_NAME_ATTRIBUTE) == assignedPlotName
end

local function isTreePart(part: BasePart): boolean
	local buildingId = part:GetAttribute(BuildingAttributeNames.buildingId)
	return type(buildingId) == "string" and ProgressionConfig.isTreeBuildingId(buildingId) and isOwnedPartOnAssignedPlot(part)
end

local function hasFinalBuildingId(part: BasePart): boolean
	return type(part:GetAttribute(BuildingAttributeNames.buildingId)) == "string"
end

local function stopSound(sound: Sound?)
	if sound ~= nil and sound.IsPlaying then
		sound:Stop()
	end
end

local function configureSound(sound: Sound)
	sound.Looped = true
	sound.RollOffMinDistance = TreeAmbientSoundConfig.rollOffMinDistanceStuds
	sound.RollOffMaxDistance = TreeAmbientSoundConfig.rollOffMaxDistanceStuds
	AudioService.assignSoundToBus(sound, "SFX")
end

local function getVolumeMultiplier(distance: number): number
	if distance <= TreeAmbientSoundConfig.fullVolumeDistanceStuds then
		return 1
	end

	if distance >= TreeAmbientSoundConfig.startDistanceStuds then
		return 0
	end

	local fadeDistance = TreeAmbientSoundConfig.startDistanceStuds - TreeAmbientSoundConfig.fullVolumeDistanceStuds
	if fadeDistance <= 0 then
		return 0
	end

	local fadeProgress = (distance - TreeAmbientSoundConfig.fullVolumeDistanceStuds) / fadeDistance
	return 1 - math.clamp(fadeProgress, 0, 1)
end

local function updateSoundVolume(trackedSound: TrackedTreeSound, distance: number)
	local sound = trackedSound.sound
	if sound == nil then
		return
	end

	sound.Volume = trackedSound.baseVolume * getVolumeMultiplier(distance)
end

local function findCurrentVisualSound(part: BasePart): Sound?
	local currentVisual = part:FindFirstChild(TreeAmbientSoundConfig.currentVisualModelName)
	if currentVisual == nil or not currentVisual:IsA("Model") then
		return nil
	end

	local sound = currentVisual:FindFirstChild(TreeAmbientSoundConfig.soundName)
	if sound == nil or not sound:IsA("Sound") then
		return nil
	end

	return sound
end

local function refreshTrackedSound(trackedSound: TrackedTreeSound)
	local nextSound = findCurrentVisualSound(trackedSound.part)
	if nextSound == trackedSound.sound then
		return
	end

	stopSound(trackedSound.sound)
	trackedSound.sound = nextSound
	trackedSound.baseVolume = if nextSound ~= nil then nextSound.Volume else 1
	trackedSound.isPlaying = false

	if nextSound ~= nil then
		configureSound(nextSound)
	end
end

local function disconnectPendingAttributeConnections(part: BasePart)
	local connections = pendingAttributeConnectionsByPart[part]
	if connections == nil then
		return
	end

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end

	pendingAttributeConnectionsByPart[part] = nil
end

local function destroyTrackedSound(part: BasePart)
	local trackedSound = trackedSoundsByPart[part]
	if trackedSound ~= nil then
		stopSound(trackedSound.sound)

		for _, connection in ipairs(trackedSound.connections) do
			connection:Disconnect()
		end

		trackedSoundsByPart[part] = nil
	end

	disconnectPendingAttributeConnections(part)
end

local function trackTreePart(part: BasePart)
	if trackedSoundsByPart[part] ~= nil then
		return
	end

	if not isTreePart(part) then
		return
	end

	disconnectPendingAttributeConnections(part)

	local trackedSound: TrackedTreeSound = {
		part = part,
		sound = nil,
		baseVolume = 1,
		isPlaying = false,
		connections = {},
	}

	trackedSoundsByPart[part] = trackedSound

	table.insert(trackedSound.connections, part.ChildAdded:Connect(function()
		task.defer(function()
			if trackedSoundsByPart[part] == trackedSound then
				refreshTrackedSound(trackedSound)
			end
		end)
	end))

	table.insert(trackedSound.connections, part.ChildRemoved:Connect(function()
		task.defer(function()
			if trackedSoundsByPart[part] == trackedSound then
				refreshTrackedSound(trackedSound)
			end
		end)
	end))

	table.insert(trackedSound.connections, part:GetAttributeChangedSignal(BuildingAttributeNames.buildingId):Connect(function()
		if not isTreePart(part) then
			destroyTrackedSound(part)
		end
	end))

	table.insert(trackedSound.connections, part:GetAttributeChangedSignal(OWNER_USER_ID_ATTRIBUTE):Connect(function()
		if not isTreePart(part) then
			destroyTrackedSound(part)
		end
	end))

	table.insert(trackedSound.connections, part:GetAttributeChangedSignal(PLOT_NAME_ATTRIBUTE):Connect(function()
		if not isTreePart(part) then
			destroyTrackedSound(part)
		end
	end))

	table.insert(trackedSound.connections, part.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			destroyTrackedSound(part)
		end
	end))

	refreshTrackedSound(trackedSound)
end

local function connectPartForDeferredTracking(part: BasePart)
	if isTreePart(part) then
		trackTreePart(part)
		return
	end

	if hasFinalBuildingId(part) then
		return
	end

	if pendingAttributeConnectionsByPart[part] ~= nil then
		return
	end

	local buildingIdConnection = part:GetAttributeChangedSignal(BuildingAttributeNames.buildingId):Connect(function()
		if isTreePart(part) then
			trackTreePart(part)
		elseif hasFinalBuildingId(part) then
			disconnectPendingAttributeConnections(part)
		end
	end)
	local ownerUserIdConnection = part:GetAttributeChangedSignal(OWNER_USER_ID_ATTRIBUTE):Connect(function()
		if isTreePart(part) then
			trackTreePart(part)
		end
	end)
	local plotNameConnection = part:GetAttributeChangedSignal(PLOT_NAME_ATTRIBUTE):Connect(function()
		if isTreePart(part) then
			trackTreePart(part)
		end
	end)

	local ancestryConnection = part.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			disconnectPendingAttributeConnections(part)
		end
	end)

	pendingAttributeConnectionsByPart[part] = {
		buildingIdConnection,
		ownerUserIdConnection,
		plotNameConnection,
		ancestryConnection,
	}
end

local function refreshAllPlacedParts()
	local placedObjectsFolder = getPlacedObjectsFolder()
	for _, child in ipairs(placedObjectsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			if isTreePart(child) then
				trackTreePart(child)
			else
				destroyTrackedSound(child)
				connectPartForDeferredTracking(child)
			end
		end
	end
end

local function updateTrackedSounds()
	local rootPart = getCharacterRootPart()

	for part, trackedSound in pairs(trackedSoundsByPart) do
		if part.Parent == nil then
			destroyTrackedSound(part)
			continue
		end

		refreshTrackedSound(trackedSound)

		local sound = trackedSound.sound
		if sound == nil or rootPart == nil then
			stopSound(sound)
			trackedSound.isPlaying = false
			continue
		end

		local distance = (rootPart.Position - part.Position).Magnitude
		updateSoundVolume(trackedSound, distance)

		if trackedSound.isPlaying then
			if distance > TreeAmbientSoundConfig.stopDistanceStuds then
				sound:Stop()
				trackedSound.isPlaying = false
			end
		elseif distance <= TreeAmbientSoundConfig.startDistanceStuds then
			sound:Play()
			trackedSound.isPlaying = true
		end
	end
end

local function startUpdateLoop()
	task.spawn(function()
		while true do
			updateTrackedSounds()
			task.wait(TreeAmbientSoundConfig.updateIntervalSeconds)
		end
	end)
end

local TreeAmbientSoundController = {}

function TreeAmbientSoundController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local placedObjectsFolder = getPlacedObjectsFolder()

	for _, child in ipairs(placedObjectsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			connectPartForDeferredTracking(child)
		end
	end

	placedObjectsFolder.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			connectPartForDeferredTracking(child)
		end
	end)

	placedObjectsFolder.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") then
			destroyTrackedSound(child)
		end
	end)

	localPlayer:GetAttributeChangedSignal(PlotLocator.PlayerAttributes.assignedPlotName):Connect(refreshAllPlacedParts)
	startUpdateLoop()
end

return table.freeze(TreeAmbientSoundController)

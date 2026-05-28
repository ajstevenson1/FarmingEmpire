--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local weatherFolder = sharedFolder:WaitForChild("Weather") :: Folder
local windmillsFolder = sharedFolder:WaitForChild("Windmills") :: Folder

local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local WeatherEventConfig = require(weatherFolder:WaitForChild("WeatherEventConfig") :: ModuleScript)
local WeatherTypes = require(weatherFolder:WaitForChild("WeatherTypes") :: ModuleScript)
local WindmillConfig = require(windmillsFolder:WaitForChild("WindmillConfig") :: ModuleScript)

type WeatherSnapshot = WeatherTypes.WeatherSnapshot

type TrackedWindmill = {
	rootPart: BasePart,
	rotatePart: BasePart?,
}

local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local CURRENT_VISUAL_MODEL_NAME = "CurrentVisual"
local ROTATE_PART_NAME = "Rotate"
local BASE_ROTATION_RADIANS_PER_SECOND = math.rad(90)

local hasStarted = false
local rotationSpeedMultiplier = 1
local trackedWindmillsByRootPart: { [BasePart]: TrackedWindmill } = {}

local function getPlacedObjectsFolder(): Folder
	local folder = Workspace:WaitForChild(PLACED_OBJECTS_FOLDER_NAME)
	assert(folder:IsA("Folder"), string.format("Workspace.%s must be a Folder", PLACED_OBJECTS_FOLDER_NAME))
	return folder
end

local function getWeatherRemotes(): (RemoteEvent, RemoteFunction)
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName)
	assert(rootFolder:IsA("Folder"), "ReplicatedStorage.GameRemotes must be a Folder")

	local weatherRemoteFolder = rootFolder:WaitForChild(RemoteNames.weatherFolderName)
	assert(weatherRemoteFolder:IsA("Folder"), "GameRemotes.Weather must be a Folder")

	local weatherUpdated = weatherRemoteFolder:WaitForChild(RemoteNames.weatherUpdatedEventName)
	assert(weatherUpdated:IsA("RemoteEvent"), "GameRemotes.Weather.WeatherUpdated must be a RemoteEvent")

	local getWeatherSnapshot = weatherRemoteFolder:WaitForChild(RemoteNames.getWeatherSnapshotFunctionName)
	assert(getWeatherSnapshot:IsA("RemoteFunction"), "GameRemotes.Weather.GetWeatherSnapshot must be a RemoteFunction")

	return weatherUpdated, getWeatherSnapshot
end

local function isWeatherSnapshot(value: unknown): boolean
	if typeof(value) ~= "table" then
		return false
	end

	local snapshot = value :: { [string]: unknown }
	return (snapshot.activeEventId == nil or typeof(snapshot.activeEventId) == "string")
		and typeof(snapshot.displayMessage) == "string"
		and typeof(snapshot.state) == "string"
		and (snapshot.nextTransitionAt == nil or typeof(snapshot.nextTransitionAt) == "number")
		and typeof(snapshot.isAdminOverride) == "boolean"
end

local function getRotationSpeedMultiplier(snapshot: WeatherSnapshot): number
	local activeEventId = snapshot.activeEventId
	if activeEventId == nil then
		return 1
	end

	local eventDefinition = WeatherEventConfig.getEventDefinition(activeEventId)
	local windmillModifier = if eventDefinition ~= nil then eventDefinition.windmillModifier else nil
	local multiplier = if windmillModifier ~= nil then windmillModifier.rotationSpeedMultiplier else 1
	if multiplier ~= multiplier or multiplier == math.huge or multiplier == -math.huge or multiplier < 0 then
		return 1
	end

	return multiplier
end

local function receiveWeatherSnapshot(receivedSnapshot: unknown)
	if not isWeatherSnapshot(receivedSnapshot) then
		return
	end

	rotationSpeedMultiplier = getRotationSpeedMultiplier(receivedSnapshot :: WeatherSnapshot)
end

local function isWindmillRootPart(part: BasePart): boolean
	local buildingId = part:GetAttribute(BuildingAttributeNames.buildingId)
	return type(buildingId) == "string" and WindmillConfig.isWindmillBuildingId(buildingId)
end

local function findRotatePart(rootPart: BasePart): BasePart?
	local currentVisual = rootPart:FindFirstChild(CURRENT_VISUAL_MODEL_NAME)
	if currentVisual == nil then
		return nil
	end

	local rotatePart = currentVisual:FindFirstChild(ROTATE_PART_NAME, true)
	if rotatePart ~= nil and rotatePart:IsA("BasePart") then
		return rotatePart
	end

	return nil
end

local function trackWindmill(rootPart: BasePart)
	if trackedWindmillsByRootPart[rootPart] ~= nil then
		return
	end

	trackedWindmillsByRootPart[rootPart] = {
		rootPart = rootPart,
		rotatePart = findRotatePart(rootPart),
	}
end

local function untrackWindmill(rootPart: BasePart)
	trackedWindmillsByRootPart[rootPart] = nil
end

local function refreshTrackedPart(rootPart: BasePart)
	if isWindmillRootPart(rootPart) then
		trackWindmill(rootPart)
	else
		untrackWindmill(rootPart)
	end
end

local function connectPartForTracking(rootPart: BasePart)
	refreshTrackedPart(rootPart)

	rootPart:GetAttributeChangedSignal(BuildingAttributeNames.buildingId):Connect(function()
		refreshTrackedPart(rootPart)
	end)

	rootPart.ChildAdded:Connect(function()
		local trackedWindmill = trackedWindmillsByRootPart[rootPart]
		if trackedWindmill ~= nil then
			trackedWindmill.rotatePart = findRotatePart(rootPart)
		end
	end)

	rootPart.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			untrackWindmill(rootPart)
		end
	end)
end

local function spinTrackedWindmills(deltaTime: number)
	local rotationDelta = BASE_ROTATION_RADIANS_PER_SECOND * rotationSpeedMultiplier * deltaTime
	if rotationDelta == 0 then
		return
	end

	for rootPart, trackedWindmill in pairs(trackedWindmillsByRootPart) do
		if rootPart.Parent == nil then
			trackedWindmillsByRootPart[rootPart] = nil
			continue
		end

		local rotatePart = trackedWindmill.rotatePart
		if rotatePart == nil or rotatePart.Parent == nil then
			rotatePart = findRotatePart(rootPart)
			trackedWindmill.rotatePart = rotatePart
		end

		if rotatePart ~= nil then
			rotatePart.CFrame = rotatePart.CFrame * CFrame.Angles(rotationDelta, 0, 0)
		end
	end
end

local WindmillRotationController = {}

function WindmillRotationController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local placedObjectsFolder = getPlacedObjectsFolder()
	for _, child in ipairs(placedObjectsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			connectPartForTracking(child)
		end
	end

	placedObjectsFolder.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			connectPartForTracking(child)
		end
	end)

	placedObjectsFolder.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") then
			untrackWindmill(child)
		end
	end)

	local weatherUpdated, getWeatherSnapshot = getWeatherRemotes()
	receiveWeatherSnapshot(getWeatherSnapshot:InvokeServer())
	weatherUpdated.OnClientEvent:Connect(receiveWeatherSnapshot)

	RunService.RenderStepped:Connect(spinTrackedWindmills)
end

return table.freeze(WindmillRotationController)

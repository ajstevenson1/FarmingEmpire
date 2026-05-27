--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local weatherFolder = sharedFolder:WaitForChild("Weather") :: Folder

local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local WeatherEventConfig = require(weatherFolder:WaitForChild("WeatherEventConfig") :: ModuleScript)
local WeatherTypes = require(weatherFolder:WaitForChild("WeatherTypes") :: ModuleScript)
local WeatherEventHudView = require(script.Parent.WeatherEventHudView)

type WeatherSnapshot = WeatherTypes.WeatherSnapshot
type WeatherEventHudViewInstance = WeatherEventHudView.WeatherEventHudView

local hasStarted = false
local view: WeatherEventHudViewInstance? = nil
local latestSnapshot: WeatherSnapshot? = nil

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

local function formatSeconds(totalSeconds: number): string
	local clampedSeconds = math.max(0, math.ceil(totalSeconds))
	local minutes = math.floor(clampedSeconds / 60)
	local seconds = clampedSeconds % 60
	return string.format("%02d:%02d", minutes, seconds)
end

local function getWaitingDisplayMessage(snapshot: WeatherSnapshot): string
	local nextTransitionAt = snapshot.nextTransitionAt
	if nextTransitionAt == nil then
		return WeatherEventConfig.noWeatherMessage
	end

	return string.format("Next event in %s", formatSeconds(nextTransitionAt - Workspace:GetServerTimeNow()))
end

local function render()
	local currentView = view
	local snapshot = latestSnapshot
	if currentView == nil or snapshot == nil then
		return
	end

	if snapshot.state == "Waiting" then
		currentView:render(getWaitingDisplayMessage(snapshot))
	else
		currentView:render(snapshot.displayMessage)
	end
end

local function receiveSnapshot(receivedSnapshot: unknown)
	if not isWeatherSnapshot(receivedSnapshot) then
		return
	end

	latestSnapshot = receivedSnapshot :: WeatherSnapshot
	render()
end

local WeatherEventHudController = {}

function WeatherEventHudController.start()
	if hasStarted then
		return
	end

	hasStarted = true
	view = WeatherEventHudView.new()

	local weatherUpdated, getWeatherSnapshot = getWeatherRemotes()
	local initialSnapshot = getWeatherSnapshot:InvokeServer()
	if isWeatherSnapshot(initialSnapshot) then
		receiveSnapshot(initialSnapshot)
	else
		local currentView = view
		if currentView ~= nil then
			currentView:render(WeatherEventConfig.noWeatherMessage)
		end
	end

	weatherUpdated.OnClientEvent:Connect(receiveSnapshot)

	task.spawn(function()
		while true do
			render()
			task.wait(1)
		end
	end)
end

return table.freeze(WeatherEventHudController)

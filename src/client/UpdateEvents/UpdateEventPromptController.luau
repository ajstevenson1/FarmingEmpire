--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local updateEventsFolder = sharedFolder:WaitForChild("UpdateEvents") :: Folder

local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local UpdateEventConfig = require(updateEventsFolder:WaitForChild("UpdateEventConfig") :: ModuleScript)

local UpdateEventPromptController = {}

local hasStarted = false
local isPromptInFlight = false

local function getPromptRemote(): RemoteEvent
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local remotesFolder = rootFolder:WaitForChild(RemoteNames.updateEventsFolderName) :: Folder
	local promptRemote = remotesFolder:WaitForChild(RemoteNames.promptUpdateEventRsvpEventName)
	assert(promptRemote:IsA("RemoteEvent"), "GameRemotes.UpdateEvents.PromptUpdateEventRsvp must be a RemoteEvent")

	return promptRemote
end

local function getRsvpStatus(): Enum.RsvpStatus?
	local didCheckStatus, result = pcall(function(): Enum.RsvpStatus
		return SocialService:GetEventRsvpStatusAsync(UpdateEventConfig.eventId)
	end)

	if not didCheckStatus then
		warn(string.format("[UpdateEventPromptController] Failed to get RSVP status: %s", tostring(result)))
		return nil
	end

	return result
end

local function promptForRsvp()
	if isPromptInFlight then
		return
	end

	local currentStatus = getRsvpStatus()
	if currentStatus == nil or currentStatus == Enum.RsvpStatus.Going then
		return
	end

	isPromptInFlight = true
	local didPrompt, result = pcall(function(): Enum.RsvpStatus
		return SocialService:PromptRsvpToEventAsync(UpdateEventConfig.eventId)
	end)
	isPromptInFlight = false

	if not didPrompt then
		warn(string.format("[UpdateEventPromptController] Failed to prompt RSVP: %s", tostring(result)))
	end
end

function UpdateEventPromptController.start()
	if hasStarted then
		return
	end

	hasStarted = true
	getPromptRemote().OnClientEvent:Connect(promptForRsvp)
end

return table.freeze(UpdateEventPromptController)

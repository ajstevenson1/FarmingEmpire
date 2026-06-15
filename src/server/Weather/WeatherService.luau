--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local weatherFolder = sharedFolder:WaitForChild("Weather") :: Folder

local WeatherEventConfig = require(weatherFolder:WaitForChild("WeatherEventConfig") :: ModuleScript)
local WeatherTypes = require(weatherFolder:WaitForChild("WeatherTypes") :: ModuleScript)
local Remotes = require(script.Parent.Parent.Networking.Remotes)
local WeatherEnvironmentService = require(script.Parent.WeatherEnvironmentService)
local WeatherModifierService = require(script.Parent.WeatherModifierService)
local ProductionService = require(script.Parent.Parent.Production.ProductionService)

type WeatherEventDefinition = WeatherTypes.WeatherEventDefinition
type WeatherEventId = WeatherTypes.WeatherEventId
type WeatherCycleState = WeatherTypes.WeatherCycleState
type WeatherSnapshot = WeatherTypes.WeatherSnapshot
type ActiveEventChangedListener = (WeatherEventDefinition?) -> ()

type GlobalWeatherAction = "Start" | "Stop"

type GlobalWeatherMessage = {
	id: string,
	action: GlobalWeatherAction,
	eventId: WeatherEventId?,
	createdAtUnix: number,
}

local CYCLE_CHECK_INTERVAL_SECONDS = 1
local MESSAGE_ID_CACHE_LIMIT = 80

local hasStarted = false
local activeEventDefinition: WeatherEventDefinition? = nil
local cycleState: WeatherCycleState = "Waiting"
local nextTransitionAt: number? = nil
local isAdminOverride = false
local randomGenerator = Random.new()
local seenMessageIds: { [string]: boolean } = {}
local seenMessageIdOrder: { string } = {}
local subscriptionConnection: RBXScriptConnection? = nil
local activeEventChangedListeners: { ActiveEventChangedListener } = {}

local function getCurrentTime(): number
	return Workspace:GetServerTimeNow()
end

local function createSnapshot(): WeatherSnapshot
	if activeEventDefinition == nil then
		return {
			activeEventId = nil,
			displayMessage = WeatherEventConfig.noWeatherMessage,
			state = cycleState,
			nextTransitionAt = nextTransitionAt,
			isAdminOverride = isAdminOverride,
		}
	end

	return {
		activeEventId = activeEventDefinition.id,
		displayMessage = activeEventDefinition.displayMessage,
		state = cycleState,
		nextTransitionAt = nextTransitionAt,
		isAdminOverride = isAdminOverride,
	}
end

local function broadcastSnapshot()
	Remotes.getWeatherRemotes().weatherUpdated:FireAllClients(createSnapshot())
end

local function notifyActiveEventChanged()
	for _, listener in ipairs(activeEventChangedListeners) do
		local success, result = pcall(function()
			listener(activeEventDefinition)
		end)

		if not success then
			warn(string.format("Weather active-event listener failed: %s", tostring(result)))
		end
	end
end

local function rememberMessageId(messageId: string): boolean
	if seenMessageIds[messageId] == true then
		return false
	end

	seenMessageIds[messageId] = true
	table.insert(seenMessageIdOrder, messageId)

	while #seenMessageIdOrder > MESSAGE_ID_CACHE_LIMIT do
		local oldestMessageId = table.remove(seenMessageIdOrder, 1)
		if oldestMessageId ~= nil then
			seenMessageIds[oldestMessageId] = nil
		end
	end

	return true
end

local function isGlobalWeatherMessage(value: unknown): boolean
	if typeof(value) ~= "table" then
		return false
	end

	local message = value :: { [string]: unknown }
	return typeof(message.id) == "string"
		and typeof(message.action) == "string"
		and (message.eventId == nil or typeof(message.eventId) == "string")
		and typeof(message.createdAtUnix) == "number"
end

local function pickWeightedRandomEvent(): WeatherEventDefinition?
	local totalWeight = 0
	for _, eventDefinition in pairs(WeatherEventConfig.eventsById) do
		if eventDefinition.weight > 0 then
			totalWeight += eventDefinition.weight
		end
	end

	if totalWeight <= 0 then
		return nil
	end

	local roll = randomGenerator:NextNumber(0, totalWeight)
	local cumulativeWeight = 0
	for _, eventDefinition in pairs(WeatherEventConfig.eventsById) do
		if eventDefinition.weight > 0 then
			cumulativeWeight += eventDefinition.weight
		end

		if roll <= cumulativeWeight then
			return eventDefinition
		end
	end

	return nil
end

local function setWaitingState()
	activeEventDefinition = nil
	cycleState = "Waiting"
	isAdminOverride = false
	nextTransitionAt = getCurrentTime() + WeatherEventConfig.cycle.secondsBetweenEvents
	WeatherModifierService.setActiveEvent(nil)
	WeatherEnvironmentService.clearEvent()
	ProductionService.refreshWeatherModifiers()
	notifyActiveEventChanged()
end

local function setActiveState(eventDefinition: WeatherEventDefinition, durationSeconds: number?)
	activeEventDefinition = eventDefinition
	cycleState = "Active"
	isAdminOverride = durationSeconds == nil
	nextTransitionAt = if durationSeconds ~= nil then getCurrentTime() + durationSeconds else nil
	WeatherModifierService.setActiveEvent(eventDefinition)
	WeatherEnvironmentService.applyEvent(eventDefinition)
	ProductionService.refreshWeatherModifiers()
	notifyActiveEventChanged()
end

local function applyGlobalWeatherMessage(message: GlobalWeatherMessage)
	if not rememberMessageId(message.id) then
		return
	end

	if message.action == "Stop" then
		setWaitingState()
		broadcastSnapshot()
		return
	end

	local eventId = message.eventId
	if eventId == nil then
		return
	end

	local eventDefinition = WeatherEventConfig.getEventDefinition(eventId)
	if eventDefinition == nil then
		return
	end

	setActiveState(eventDefinition, nil)
	broadcastSnapshot()
end

local function handleMessagingServiceMessage(message: { Data: unknown })
	if not isGlobalWeatherMessage(message.Data) then
		return
	end

	applyGlobalWeatherMessage(message.Data :: GlobalWeatherMessage)
end

local function startCycleLoop()
	task.spawn(function()
		while true do
			if not isAdminOverride then
				local transitionAt = nextTransitionAt
				if transitionAt ~= nil and getCurrentTime() >= transitionAt then
					if cycleState == "Waiting" then
						local eventDefinition = pickWeightedRandomEvent()
						if eventDefinition ~= nil then
							setActiveState(eventDefinition, WeatherEventConfig.cycle.eventDurationSeconds)
							broadcastSnapshot()
						else
							setWaitingState()
							broadcastSnapshot()
						end
					elseif cycleState == "Active" then
						setWaitingState()
						broadcastSnapshot()
					end
				end
			end

			task.wait(CYCLE_CHECK_INTERVAL_SECONDS)
		end
	end)
end

local WeatherService = {}

function WeatherService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local weatherRemotes = Remotes.getWeatherRemotes()
	weatherRemotes.getWeatherSnapshot.OnServerInvoke = function(): WeatherSnapshot
		return createSnapshot()
	end

	setWaitingState()
	startCycleLoop()

	local success, result = pcall(function()
		return MessagingService:SubscribeAsync(WeatherEventConfig.globalWeatherTopicName, handleMessagingServiceMessage)
	end)

	if success then
		subscriptionConnection = result :: RBXScriptConnection
	else
		warn(string.format("Failed to subscribe to global weather events: %s", tostring(result)))
	end
end

function WeatherService.startEvent(eventId: WeatherEventId): (boolean, string)
	local eventDefinition = WeatherEventConfig.getEventDefinition(eventId)
	if eventDefinition == nil then
		return false, string.format("Unknown weather event: %s", eventId)
	end

	setActiveState(eventDefinition, nil)
	broadcastSnapshot()

	return true, string.format("Started %s weather until stopped by admin.", eventId)
end

function WeatherService.stopEvent(): (boolean, string)
	local stoppedEventId = if activeEventDefinition ~= nil then activeEventDefinition.id else nil
	setWaitingState()
	broadcastSnapshot()

	if stoppedEventId == nil then
		return true, "Weather timer reset. Next event in 10 minutes."
	end

	return true, string.format("Stopped %s weather. Next event in 10 minutes.", stoppedEventId)
end

function WeatherService.publishGlobalStartEvent(eventId: WeatherEventId): string
	local eventDefinition = WeatherEventConfig.getEventDefinition(eventId)
	if eventDefinition == nil then
		return string.format("Unknown weather event: %s", eventId)
	end

	local message: GlobalWeatherMessage = {
		id = HttpService:GenerateGUID(false),
		action = "Start",
		eventId = eventId,
		createdAtUnix = os.time(),
	}

	applyGlobalWeatherMessage(message)

	local publishSuccess, publishError = pcall(function()
		MessagingService:PublishAsync(WeatherEventConfig.globalWeatherTopicName, message)
	end)

	if not publishSuccess then
		return string.format("Started %s weather in this server, but global publish failed: %s", eventId, tostring(publishError))
	end

	return string.format("Started %s weather globally until stopped by admin.", eventId)
end

function WeatherService.publishGlobalStopEvent(): string
	local message: GlobalWeatherMessage = {
		id = HttpService:GenerateGUID(false),
		action = "Stop",
		eventId = nil,
		createdAtUnix = os.time(),
	}

	applyGlobalWeatherMessage(message)

	local publishSuccess, publishError = pcall(function()
		MessagingService:PublishAsync(WeatherEventConfig.globalWeatherTopicName, message)
	end)

	if not publishSuccess then
		return string.format("Stopped weather in this server, but global publish failed: %s", tostring(publishError))
	end

	return "Stopped global weather. All servers reset their weather timers."
end

function WeatherService.getSnapshot(): WeatherSnapshot
	return createSnapshot()
end

function WeatherService.observeActiveEventChanged(listener: ActiveEventChangedListener)
	table.insert(activeEventChangedListeners, listener)
	listener(activeEventDefinition)
end

function WeatherService.stop()
	local connection = subscriptionConnection
	if connection ~= nil then
		connection:Disconnect()
		subscriptionConnection = nil
	end

	hasStarted = false
end

return table.freeze(WeatherService)

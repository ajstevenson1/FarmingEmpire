--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local updateEventsFolder = sharedFolder:WaitForChild("UpdateEvents") :: Folder

local UpdateEventConfig = require(updateEventsFolder:WaitForChild("UpdateEventConfig") :: ModuleScript)

type ExperienceEventDateTime = {
	Day: number,
	Year: number,
	Month: number,
	Minute: number,
	Millisecond: number?,
	Hour: number,
	Second: number,
}

type ExperienceEvent = {
	StartTime: ExperienceEventDateTime,
}

local UpdateEventCountdownController = {}

local hasStarted = false
local timerLabel: TextLabel? = nil
local eventStartUnixTimestamp: number? = nil

local function formatDuration(totalSeconds: number): string
	local clampedSeconds = math.max(0, math.ceil(totalSeconds))
	local days = math.floor(clampedSeconds / 86400)
	local hours = math.floor((clampedSeconds % 86400) / 3600)
	local minutes = math.floor((clampedSeconds % 3600) / 60)
	local seconds = clampedSeconds % 60

	return string.format("%02dd:%02dh:%02dm:%02ds", days, hours, minutes, seconds)
end

local function findTimerLabel(): TextLabel?
	local model = Workspace:FindFirstChild(UpdateEventConfig.countdownModelName)
	if model == nil then
		warn(string.format("[UpdateEventCountdownController] Missing Workspace.%s.", UpdateEventConfig.countdownModelName))
		return nil
	end

	local gui = model:FindFirstChild(UpdateEventConfig.countdownGuiName, true)
	if gui == nil then
		warn(string.format(
			"[UpdateEventCountdownController] Missing %s.%s.",
			model:GetFullName(),
			UpdateEventConfig.countdownGuiName
		))
		return nil
	end

	local label = gui:FindFirstChild(UpdateEventConfig.timerLabelName, true)
	if label == nil then
		warn(string.format(
			"[UpdateEventCountdownController] Missing %s.%s.",
			gui:GetFullName(),
			UpdateEventConfig.timerLabelName
		))
		return nil
	end

	if not label:IsA("TextLabel") then
		warn(string.format("[UpdateEventCountdownController] %s must be a TextLabel.", label:GetFullName()))
		return nil
	end

	return label
end

local function isExperienceEventDateTime(value: unknown): boolean
	if typeof(value) ~= "table" then
		return false
	end

	local dateTime = value :: { [string]: unknown }
	return typeof(dateTime.Year) == "number"
		and typeof(dateTime.Month) == "number"
		and typeof(dateTime.Day) == "number"
		and typeof(dateTime.Hour) == "number"
		and typeof(dateTime.Minute) == "number"
		and typeof(dateTime.Second) == "number"
		and (dateTime.Millisecond == nil or typeof(dateTime.Millisecond) == "number")
end

local function dateTimeToUnixTimestamp(startTime: ExperienceEventDateTime): number?
	local didConvertDateTime, result = pcall(function(): number
		return DateTime.fromUniversalTime(
			startTime.Year,
			startTime.Month,
			startTime.Day,
			startTime.Hour,
			startTime.Minute,
			startTime.Second,
			startTime.Millisecond or 0
		).UnixTimestamp
	end)

	if not didConvertDateTime then
		warn(string.format("[UpdateEventCountdownController] Failed to convert event StartTime: %s", tostring(result)))
		return nil
	end

	return result
end

local function getEventStartUnixTimestamp(): number?
	local didFetchEvent, result = pcall(function(): ExperienceEvent?
		return SocialService:GetExperienceEventAsync(UpdateEventConfig.eventId) :: ExperienceEvent?
	end)

	if not didFetchEvent then
		warn(string.format("[UpdateEventCountdownController] Failed to load update event: %s", tostring(result)))
		return nil
	end

	local event = result
	if event == nil then
		warn("[UpdateEventCountdownController] Update event was not found for this experience.")
		return nil
	end

	if not isExperienceEventDateTime(event.StartTime) then
		warn("[UpdateEventCountdownController] Update event returned an invalid StartTime.")
		return nil
	end

	local startTime = event.StartTime
	return dateTimeToUnixTimestamp(startTime)
end

local function render()
	local label = timerLabel
	if label == nil then
		return
	end

	local startUnixTimestamp = eventStartUnixTimestamp
	if startUnixTimestamp == nil then
		label.Text = UpdateEventConfig.unavailableTimerText
		return
	end

	label.Text = formatDuration(startUnixTimestamp - Workspace:GetServerTimeNow())
end

local function startRenderLoop()
	task.spawn(function()
		while true do
			render()
			task.wait(1)
		end
	end)
end

function UpdateEventCountdownController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	timerLabel = findTimerLabel()
	if timerLabel == nil then
		return
	end

	timerLabel.Text = UpdateEventConfig.unavailableTimerText
	task.spawn(function()
		eventStartUnixTimestamp = getEventStartUnixTimestamp()
		render()
	end)
	startRenderLoop()
end

return table.freeze(UpdateEventCountdownController)

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local weatherFolder = sharedFolder:WaitForChild("Weather") :: Folder

local WeatherEventConfig = require(weatherFolder:WaitForChild("WeatherEventConfig") :: ModuleScript)
local WeatherService = require(script.Parent.Parent.Parent.Weather.WeatherService)

local function normalizeAction(action: string): string
	return string.lower(action)
end

return function(_context, action: string, eventName: string?): string
	local normalizedAction = normalizeAction(action)
	if normalizedAction == "stop" then
		return WeatherService.publishGlobalStopEvent()
	end

	if normalizedAction ~= "start" then
		return "Use globalweather start Rain or globalweather stop."
	end

	if eventName == nil or eventName == "" then
		return "Choose a weather event, such as Rain."
	end

	local eventDefinition = WeatherEventConfig.getEventDefinitionByName(eventName)
	if eventDefinition == nil then
		return string.format("Unknown weather event: %s", eventName)
	end

	return WeatherService.publishGlobalStartEvent(eventDefinition.id)
end

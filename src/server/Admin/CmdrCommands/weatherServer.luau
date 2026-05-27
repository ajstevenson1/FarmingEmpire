--!strict

local WeatherService = require(script.Parent.Parent.Parent.Weather.WeatherService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local weatherFolder = sharedFolder:WaitForChild("Weather") :: Folder

local WeatherEventConfig = require(weatherFolder:WaitForChild("WeatherEventConfig") :: ModuleScript)

local function normalizeAction(action: string): string
	return string.lower(action)
end

return function(_context, action: string, eventName: string?): string
	local normalizedAction = normalizeAction(action)
	if normalizedAction == "stop" then
		local _, message = WeatherService.stopEvent()
		return message
	end

	if normalizedAction ~= "start" then
		return "Use weather start Rain or weather stop."
	end

	if eventName == nil or eventName == "" then
		return "Choose a weather event, such as Rain."
	end

	local eventDefinition = WeatherEventConfig.getEventDefinitionByName(eventName)
	if eventDefinition == nil then
		return string.format("Unknown weather event: %s", eventName)
	end

	local _, message = WeatherService.startEvent(eventDefinition.id)
	return message
end

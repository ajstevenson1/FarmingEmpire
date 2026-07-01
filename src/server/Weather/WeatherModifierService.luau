--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local weatherFolder = sharedFolder:WaitForChild("Weather") :: Folder

local WeatherTypes = require(weatherFolder:WaitForChild("WeatherTypes") :: ModuleScript)

type WeatherEventDefinition = WeatherTypes.WeatherEventDefinition

local activeTreeSpeedMultiplier = 1
local activeGlobalOutputMultiplier = 1

local MIN_PRODUCTION_MULTIPLIER = 0.001

local WeatherModifierService = {}

local function getSafeMultiplier(multiplier: number?): number
	return if multiplier ~= nil then math.max(MIN_PRODUCTION_MULTIPLIER, multiplier) else 1
end

function WeatherModifierService.setActiveEvent(eventDefinition: WeatherEventDefinition?)
	local productionModifier = if eventDefinition ~= nil then eventDefinition.productionModifier else nil
	activeTreeSpeedMultiplier = if productionModifier ~= nil then getSafeMultiplier(productionModifier.treeSpeedMultiplier) else 1
	activeGlobalOutputMultiplier = if productionModifier ~= nil then getSafeMultiplier(productionModifier.globalOutputMultiplier) else 1
end

function WeatherModifierService.getTreeSpeedMultiplier(): number
	return activeTreeSpeedMultiplier
end

function WeatherModifierService.getGlobalOutputMultiplier(): number
	return activeGlobalOutputMultiplier
end

return table.freeze(WeatherModifierService)

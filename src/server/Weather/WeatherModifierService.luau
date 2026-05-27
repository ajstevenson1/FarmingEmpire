--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local weatherFolder = sharedFolder:WaitForChild("Weather") :: Folder

local WeatherTypes = require(weatherFolder:WaitForChild("WeatherTypes") :: ModuleScript)

type WeatherEventDefinition = WeatherTypes.WeatherEventDefinition

local activeTreeSpeedMultiplier = 1

local WeatherModifierService = {}

function WeatherModifierService.setActiveEvent(eventDefinition: WeatherEventDefinition?)
	local productionModifier = if eventDefinition ~= nil then eventDefinition.productionModifier else nil
	activeTreeSpeedMultiplier = if productionModifier ~= nil then math.max(0.001, productionModifier.treeSpeedMultiplier) else 1
end

function WeatherModifierService.getTreeSpeedMultiplier(): number
	return activeTreeSpeedMultiplier
end

return table.freeze(WeatherModifierService)

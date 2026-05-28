--!strict

local WeatherTypes = require(script.Parent.WeatherTypes)

type WeatherEventDefinition = WeatherTypes.WeatherEventDefinition
type WeatherEventId = WeatherTypes.WeatherEventId
type WeatherCycleConfig = WeatherTypes.WeatherCycleConfig

export type WeatherEventConfig = {
	noWeatherMessage: string,
	defaultSkyName: string,
	globalWeatherTopicName: string,
	cycle: WeatherCycleConfig,
	eventsById: { [WeatherEventId]: WeatherEventDefinition },
	getEventDefinition: (eventId: WeatherEventId) -> WeatherEventDefinition?,
	getEventDefinitionByName: (eventName: string) -> WeatherEventDefinition?,
}

local WeatherEventConfig = {}

WeatherEventConfig.noWeatherMessage = "No weather"
WeatherEventConfig.defaultSkyName = "Sky"
WeatherEventConfig.globalWeatherTopicName = "GlobalWeatherEvents_v1"
WeatherEventConfig.cycle = table.freeze({
	secondsBetweenEvents = 10 * 60,
	eventDurationSeconds = 3 * 60,
})

WeatherEventConfig.eventsById = table.freeze({
	Rain = table.freeze({
		id = "Rain",
		weight = 100,
		displayMessage = '<b><font color="#7CCBFF">Rain event!</font></b> Apple production is 50% faster. Windmills spin 100% faster.',
		sky = table.freeze({
			activeSkyName = "Rain",
			defaultSkyName = "Sky",
		}),
		particles = table.freeze({
			topParticleName = "RainTop",
			topTargetName = "WeatherPart",
			bottomParticleName = "RainBottom",
			bottomTargetName = "Base",
			cloneCount = 8,
		}),
		clouds = table.freeze({
			tweenSeconds = 8,
			cover = 0.82,
			density = 0.55,
			color = Color3.fromRGB(165, 180, 195),
		}),
		productionModifier = table.freeze({
			treeSpeedMultiplier = 1.5,
		}),
		windmillModifier = table.freeze({
			rotationSpeedMultiplier = 2,
		}),
	}),
})

function WeatherEventConfig.getEventDefinition(eventId: WeatherEventId): WeatherEventDefinition?
	return WeatherEventConfig.eventsById[eventId]
end

function WeatherEventConfig.getEventDefinitionByName(eventName: string): WeatherEventDefinition?
	local normalizedEventName = string.lower(eventName)
	for _, eventDefinition in pairs(WeatherEventConfig.eventsById) do
		if string.lower(eventDefinition.id) == normalizedEventName then
			return eventDefinition
		end
	end

	return nil
end

return table.freeze(WeatherEventConfig) :: WeatherEventConfig

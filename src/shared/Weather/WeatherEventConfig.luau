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
		displayMessage = '<b><font color="#7CCBFF">Rain event!</font></b> Apple production is 50% faster.',
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
	Money = table.freeze({
		id = "Money",
		weight = 85,
		displayMessage = '<b><font color="#FFE15A">Money event!</font></b> Cash is falling from the sky.',
		sky = table.freeze({
			activeSkyName = "Sky",
			defaultSkyName = "Sky",
		}),
		particles = table.freeze({
			topParticleName = "Money",
			topTargetName = "WeatherPart",
			bottomParticleName = nil,
			bottomTargetName = nil,
			cloneCount = 8,
		}),
		moneyDrops = table.freeze({
			spawnIntervalSeconds = 1,
			spawnAreaTargetName = "WeatherPart",
			spawnAreaScale = 0.4,
			collectionRadiusStuds = 6,
			serverValidationRadiusStuds = 14,
			fallSeconds = 1.75,
			tiers = table.freeze({
				table.freeze({
					id = "Small",
					modelName = "SmallMoney",
					rewardCash = 500,
					lifetimeSeconds = 30,
					weight = 67,
				}),
				table.freeze({
					id = "Medium",
					modelName = "MediumMoney",
					rewardCash = 5000,
					lifetimeSeconds = 25,
					weight = 30,
				}),
				table.freeze({
					id = "Big",
					modelName = "BigMoney",
					rewardCash = 50000,
					lifetimeSeconds = 20,
					weight = 3,
				}),
			}),
		}),
	}),
	Fireworks = table.freeze({
		id = "Fireworks",
		weight = 60,
		displayMessage = '<b><font color="#FF8CFF">Fireworks event!</font></b> Fireworks are lighting up the sky. All production is doubled.',
		sky = table.freeze({
			activeSkyName = "Sky",
			defaultSkyName = "Sky",
		}),
		effects = table.freeze({
			sourceFolderName = "Fireworks",
			targetName = "WeatherPart",
			playSounds = true,
		}),
		productionModifier = table.freeze({
			globalOutputMultiplier = 2,
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

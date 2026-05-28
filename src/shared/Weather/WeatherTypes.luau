--!strict

export type WeatherEventId = "Rain"

export type WeatherSkyConfig = {
	activeSkyName: string,
	defaultSkyName: string,
}

export type WeatherParticlesConfig = {
	topParticleName: string,
	topTargetName: string,
	bottomParticleName: string,
	bottomTargetName: string,
	cloneCount: number,
}

export type WeatherCloudConfig = {
	tweenSeconds: number,
	cover: number?,
	density: number?,
	color: Color3?,
}

export type WeatherProductionModifierConfig = {
	treeSpeedMultiplier: number,
}

export type WeatherWindmillModifierConfig = {
	rotationSpeedMultiplier: number,
}

export type WeatherCycleConfig = {
	secondsBetweenEvents: number,
	eventDurationSeconds: number,
}

export type WeatherEventDefinition = {
	id: WeatherEventId,
	weight: number,
	displayMessage: string,
	sky: WeatherSkyConfig,
	particles: WeatherParticlesConfig,
	clouds: WeatherCloudConfig?,
	productionModifier: WeatherProductionModifierConfig?,
	windmillModifier: WeatherWindmillModifierConfig?,
}

export type WeatherCycleState = "Waiting" | "Active"

export type WeatherSnapshot = {
	activeEventId: WeatherEventId?,
	displayMessage: string,
	state: WeatherCycleState,
	nextTransitionAt: number?,
	isAdminOverride: boolean,
}

return {}

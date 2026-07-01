--!strict

export type WeatherEventId = "Rain" | "Money" | "Fireworks"

export type WeatherSkyConfig = {
	activeSkyName: string,
	defaultSkyName: string,
}

export type WeatherParticlesConfig = {
	topParticleName: string,
	topTargetName: string,
	bottomParticleName: string?,
	bottomTargetName: string?,
	cloneCount: number,
}

export type WeatherFolderEffectsConfig = {
	sourceFolderName: string,
	targetName: string,
	playSounds: boolean?,
}

export type WeatherMoneyDropTierConfig = {
	id: string,
	modelName: string,
	rewardCash: number,
	lifetimeSeconds: number,
	weight: number,
}

export type WeatherMoneyDropConfig = {
	spawnIntervalSeconds: number,
	spawnAreaTargetName: string,
	spawnAreaScale: number?,
	collectionRadiusStuds: number,
	serverValidationRadiusStuds: number,
	fallSeconds: number,
	tiers: { WeatherMoneyDropTierConfig },
}

export type WeatherCloudConfig = {
	tweenSeconds: number,
	cover: number?,
	density: number?,
	color: Color3?,
}

export type WeatherProductionModifierConfig = {
	treeSpeedMultiplier: number?,
	globalOutputMultiplier: number?,
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
	particles: WeatherParticlesConfig?,
	effects: WeatherFolderEffectsConfig?,
	clouds: WeatherCloudConfig?,
	productionModifier: WeatherProductionModifierConfig?,
	windmillModifier: WeatherWindmillModifierConfig?,
	moneyDrops: WeatherMoneyDropConfig?,
}

export type MoneyDropSpawnPayload = {
	id: string,
	tierId: string,
	modelName: string,
	rewardCash: number,
	spawnPosition: Vector3,
	expiresAt: number,
	lifetimeSeconds: number,
	fallSeconds: number,
	collectionRadiusStuds: number,
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

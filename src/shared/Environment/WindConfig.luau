--!strict

export type WindLineConfig = {
	direction: Vector3,
	speedStudsPerSecond: number,
	lifetimeSeconds: number,
	spawnRatePerSecond: number,
	maxActiveLines: number,
	spawnPitchDegreesMin: number,
	spawnPitchDegreesMax: number,
	spawnYawDegreesMin: number,
	spawnYawDegreesMax: number,
	spawnDistanceStudsMin: number,
	spawnDistanceStudsMax: number,
	widthStuds: number,
	heightStuds: number,
	maxTrailLengthStuds: number,
	transparency: number,
	waveAmplitudeStuds: Vector3,
	waveSpeedMultiplier: number,
	lifetimeJitterSeconds: number,
	speedJitterStudsPerSecond: number,
}

export type WindConfig = {
	lines: WindLineConfig,
}

local WindConfig: WindConfig = table.freeze({
	lines = table.freeze({
		direction = Vector3.new(1, 0, 0),
		speedStudsPerSecond = 6,
		lifetimeSeconds = 3,
		spawnRatePerSecond = 25,
		maxActiveLines = 80,
		spawnPitchDegreesMin = -30,
		spawnPitchDegreesMax = 70,
		spawnYawDegreesMin = -80,
		spawnYawDegreesMax = 80,
		spawnDistanceStudsMin = 20,
		spawnDistanceStudsMax = 60,
		widthStuds = 0.1,
		heightStuds = 0.1,
		maxTrailLengthStuds = 20,
		transparency = 0.7,
		waveAmplitudeStuds = Vector3.new(0.5, 0.8, 0.5),
		waveSpeedMultiplier = 0.2,
		lifetimeJitterSeconds = 1,
		speedJitterStudsPerSecond = 1,
	}),
})

return WindConfig

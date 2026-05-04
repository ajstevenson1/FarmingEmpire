--!strict

export type ScytheConfig = {
	cooldownSeconds: number,
	swingHalfAngleDegrees: number,
	swingRange: number,
	swingVerticalTolerance: number,
}

local ScytheConfig: ScytheConfig = table.freeze({
	cooldownSeconds = 0.5,
	swingHalfAngleDegrees = 60,
	swingRange = 7,
	swingVerticalTolerance = 6,
})

return ScytheConfig

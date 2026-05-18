--!strict

export type Config = {
	recoveryTriggerY: number,
	minimumHeightAboveDestroyHeightStuds: number,
	teleportHeightAbovePlotCenterStuds: number,
}

local FallRecoveryConfig: Config = {
	recoveryTriggerY = -2500,
	minimumHeightAboveDestroyHeightStuds = 100,
	teleportHeightAbovePlotCenterStuds = 400,
}

return table.freeze(FallRecoveryConfig)

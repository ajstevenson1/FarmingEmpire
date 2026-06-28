--!strict

export type UpdateEventConfig = {
	eventId: string,
	plateName: string,
	touchPartName: string,
	touchCooldownSeconds: number,
	countdownModelName: string,
	countdownGuiName: string,
	timerLabelName: string,
	unavailableTimerText: string,
}

local UpdateEventConfig: UpdateEventConfig = {
	eventId = "1069104286614553176",
	plateName = "UpdatePlate",
	touchPartName = "Touch",
	touchCooldownSeconds = 3,
	countdownModelName = "UpdateGUI",
	countdownGuiName = "UpdateGUI",
	timerLabelName = "TimerLabel",
	unavailableTimerText = "--d:--h:--m:--s",
}

return table.freeze(UpdateEventConfig) :: UpdateEventConfig

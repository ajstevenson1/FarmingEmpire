--!strict

export type ToastStyle = {
	textColor: Color3,
	strokeColor: Color3,
}

export type NotificationConfig = {
	adminAnnouncementTopicName: string,
	adminAnnouncementMaxLength: number,
	adminAnnouncementDurationSeconds: number,
	adminAnnouncementTypewriterCharactersPerSecond: number,
	toastDurationSeconds: number,
	toastFadeDelaySeconds: number,
	toastFadeSeconds: number,
	toastMaxActive: number,
	toastStyles: {
		Success: ToastStyle,
		Error: ToastStyle,
		Info: ToastStyle,
		Reward: ToastStyle,
	},
}

local NotificationConfig = {
	adminAnnouncementTopicName = "GlobalAdminAnnouncements_v1",
	adminAnnouncementMaxLength = 220,
	adminAnnouncementDurationSeconds = 7,
	adminAnnouncementTypewriterCharactersPerSecond = 34,
	toastDurationSeconds = 3,
	toastFadeDelaySeconds = 2,
	toastFadeSeconds = 1,
	toastMaxActive = 5,
	toastStyles = {
		Success = table.freeze({
			textColor = Color3.fromRGB(70, 235, 92),
			strokeColor = Color3.fromRGB(18, 103, 35),
		}),
		Error = table.freeze({
			textColor = Color3.fromRGB(255, 84, 84),
			strokeColor = Color3.fromRGB(112, 18, 28),
		}),
		Info = table.freeze({
			textColor = Color3.fromRGB(255, 255, 255),
			strokeColor = Color3.fromRGB(62, 72, 92),
		}),
		Reward = table.freeze({
			textColor = Color3.fromRGB(255, 222, 86),
			strokeColor = Color3.fromRGB(132, 91, 12),
		}),
	},
}

return table.freeze(NotificationConfig) :: NotificationConfig

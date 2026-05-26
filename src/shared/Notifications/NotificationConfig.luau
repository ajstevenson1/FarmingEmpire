--!strict

export type NotificationConfig = {
	adminAnnouncementTopicName: string,
	adminAnnouncementMaxLength: number,
	adminAnnouncementDurationSeconds: number,
	adminAnnouncementTypewriterCharactersPerSecond: number,
}

local NotificationConfig = {
	adminAnnouncementTopicName = "GlobalAdminAnnouncements_v1",
	adminAnnouncementMaxLength = 220,
	adminAnnouncementDurationSeconds = 7,
	adminAnnouncementTypewriterCharactersPerSecond = 34,
}

return table.freeze(NotificationConfig) :: NotificationConfig

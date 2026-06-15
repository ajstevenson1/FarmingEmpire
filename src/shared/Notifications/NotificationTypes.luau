--!strict

export type NotificationKind = "AdminAnnouncement" | "Toast" | "Tutorial" | "General"
export type NotificationEffect = "Typewriter" | "Instant"
export type NotificationVariant = "Success" | "Error" | "Info" | "Reward"

export type NotificationPayload = {
	id: string,
	kind: NotificationKind,
	text: string,
	effect: NotificationEffect,
	durationSeconds: number,
	typewriterCharactersPerSecond: number?,
	variant: NotificationVariant?,
}

return {}

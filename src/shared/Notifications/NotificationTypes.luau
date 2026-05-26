--!strict

export type NotificationKind = "AdminAnnouncement" | "Tutorial" | "General"
export type NotificationEffect = "Typewriter" | "Instant"

export type NotificationPayload = {
	id: string,
	kind: NotificationKind,
	text: string,
	effect: NotificationEffect,
	durationSeconds: number,
	typewriterCharactersPerSecond: number?,
}

return {}

--!strict

local AdminAnnouncementService = require(script.Parent.Parent.Parent.Notifications.AdminAnnouncementService)

return function(context, text: string): string
	return AdminAnnouncementService.publishGlobalAnnouncement(context.Executor, text)
end

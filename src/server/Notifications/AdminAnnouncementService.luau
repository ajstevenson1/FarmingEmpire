--!strict

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local notificationsFolder = sharedFolder:WaitForChild("Notifications") :: Folder

local NotificationConfig = require(notificationsFolder:WaitForChild("NotificationConfig") :: ModuleScript)
local Remotes = require(script.Parent.Parent.Networking.Remotes)

type NotificationPayload = {
	id: string,
	kind: "AdminAnnouncement",
	text: string,
	effect: "Typewriter",
	durationSeconds: number,
	typewriterCharactersPerSecond: number,
}

type AnnouncementMessage = {
	id: string,
	text: string,
	createdAtUnix: number,
}

local MESSAGE_ID_CACHE_LIMIT = 80

local hasStarted = false
local seenMessageIds: { [string]: boolean } = {}
local seenMessageIdOrder: { string } = {}
local subscriptionConnection: RBXScriptConnection? = nil

local function rememberMessageId(messageId: string): boolean
	if seenMessageIds[messageId] == true then
		return false
	end

	seenMessageIds[messageId] = true
	table.insert(seenMessageIdOrder, messageId)

	while #seenMessageIdOrder > MESSAGE_ID_CACHE_LIMIT do
		local oldestMessageId = table.remove(seenMessageIdOrder, 1)
		if oldestMessageId ~= nil then
			seenMessageIds[oldestMessageId] = nil
		end
	end

	return true
end

local function trimToMaxLength(text: string, maxLength: number): string
	if #text <= maxLength then
		return text
	end

	return string.sub(text, 1, maxLength)
end

local function normalizeAnnouncementText(text: string): string
	local withoutControlCharacters = string.gsub(text, "[%c]", " ")
	local collapsedWhitespace = string.gsub(withoutControlCharacters, "%s+", " ")
	return string.gsub(collapsedWhitespace, "^%s*(.-)%s*$", "%1")
end

local function buildPayload(message: AnnouncementMessage): NotificationPayload
	return {
		id = message.id,
		kind = "AdminAnnouncement",
		text = message.text,
		effect = "Typewriter",
		durationSeconds = NotificationConfig.adminAnnouncementDurationSeconds,
		typewriterCharactersPerSecond = NotificationConfig.adminAnnouncementTypewriterCharactersPerSecond,
	}
end

local function broadcastToServer(message: AnnouncementMessage)
	if not rememberMessageId(message.id) then
		return
	end

	Remotes.getNotificationRemotes().notificationReceived:FireAllClients(buildPayload(message))
end

local function isAnnouncementMessage(value: unknown): boolean
	if typeof(value) ~= "table" then
		return false
	end

	local message = value :: { [string]: unknown }
	return typeof(message.id) == "string" and typeof(message.text) == "string" and typeof(message.createdAtUnix) == "number"
end

local function handleMessagingServiceMessage(message: { Data: unknown })
	if not isAnnouncementMessage(message.Data) then
		return
	end

	local announcementMessage = message.Data :: AnnouncementMessage
	broadcastToServer(announcementMessage)
end

local function filterAnnouncementText(executor: Player, text: string): (boolean, string)
	local success, filterResult = pcall(function()
		return TextService:FilterStringAsync(text, executor.UserId, Enum.TextFilterContext.PublicChat)
	end)

	if not success then
		return false, "Failed to filter announcement."
	end

	local textFilterResult = filterResult :: TextFilterResult
	local broadcastSuccess, filteredText = pcall(function()
		return textFilterResult:GetNonChatStringForBroadcastAsync()
	end)

	if not broadcastSuccess then
		return false, "Failed to prepare filtered announcement."
	end

	return true, filteredText
end

local AdminAnnouncementService = {}

function AdminAnnouncementService.start()
	if hasStarted then
		return
	end

	hasStarted = true
	Remotes.getNotificationRemotes()

	local success, result = pcall(function()
		return MessagingService:SubscribeAsync(NotificationConfig.adminAnnouncementTopicName, handleMessagingServiceMessage)
	end)

	if success then
		subscriptionConnection = result :: RBXScriptConnection
	else
		warn(string.format("Failed to subscribe to admin announcements: %s", tostring(result)))
	end
end

function AdminAnnouncementService.publishGlobalAnnouncement(executor: Player, requestedText: string): string
	local normalizedText = trimToMaxLength(
		normalizeAnnouncementText(requestedText),
		NotificationConfig.adminAnnouncementMaxLength
	)

	if normalizedText == "" then
		return "Announcement text cannot be empty."
	end

	local filterSuccess, filteredTextOrError = filterAnnouncementText(executor, normalizedText)
	if not filterSuccess then
		return filteredTextOrError
	end

	local message: AnnouncementMessage = {
		id = HttpService:GenerateGUID(false),
		text = filteredTextOrError,
		createdAtUnix = os.time(),
	}

	broadcastToServer(message)

	local publishSuccess, publishError = pcall(function()
		MessagingService:PublishAsync(NotificationConfig.adminAnnouncementTopicName, message)
	end)

	if not publishSuccess then
		return string.format("Showed announcement in this server, but global publish failed: %s", tostring(publishError))
	end

	return "Created global announcement."
end

function AdminAnnouncementService.stop()
	local connection = subscriptionConnection
	if connection ~= nil then
		connection:Disconnect()
		subscriptionConnection = nil
	end

	hasStarted = false
end

return table.freeze(AdminAnnouncementService)

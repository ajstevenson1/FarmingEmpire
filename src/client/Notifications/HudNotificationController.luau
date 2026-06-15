--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local notificationsFolder = sharedFolder:WaitForChild("Notifications") :: Folder

local NotificationConfig = require(notificationsFolder:WaitForChild("NotificationConfig") :: ModuleScript)
local NotificationTypes = require(notificationsFolder:WaitForChild("NotificationTypes") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local HudNotificationView = require(script.Parent.HudNotificationView)

type NotificationEffect = NotificationTypes.NotificationEffect
type NotificationPayload = NotificationTypes.NotificationPayload
type NotificationVariant = NotificationTypes.NotificationVariant
type HudNotificationView = HudNotificationView.HudNotificationView

local hasStarted = false
local isProcessingAdminAnnouncementQueue = false
local adminAnnouncementQueue: { NotificationPayload } = {}
local notificationView: HudNotificationView? = nil

local function getNotificationReceivedRemote(): RemoteEvent
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName)
	assert(rootFolder:IsA("Folder"), "ReplicatedStorage.GameRemotes must be a Folder")

	local notificationsRemoteFolder = rootFolder:WaitForChild(RemoteNames.notificationsFolderName)
	assert(notificationsRemoteFolder:IsA("Folder"), "GameRemotes.Notifications must be a Folder")

	local notificationReceived = notificationsRemoteFolder:WaitForChild(RemoteNames.notificationReceivedEventName)
	assert(notificationReceived:IsA("RemoteEvent"), "GameRemotes.Notifications.NotificationReceived must be a RemoteEvent")

	return notificationReceived
end

local function getNotificationView(): HudNotificationView
	if notificationView == nil then
		notificationView = HudNotificationView.new()
	end

	return notificationView :: HudNotificationView
end

local function isKnownKind(value: string): boolean
	return value == "AdminAnnouncement" or value == "Toast" or value == "Tutorial" or value == "General"
end

local function isKnownEffect(value: string): boolean
	return value == "Typewriter" or value == "Instant"
end

local function isKnownVariant(value: string): boolean
	return value == "Success" or value == "Error" or value == "Info" or value == "Reward"
end

local function isNotificationPayload(value: unknown): boolean
	if typeof(value) ~= "table" then
		return false
	end

	local payload = value :: { [string]: unknown }
	local id = payload.id
	local kind = payload.kind
	local text = payload.text
	local effect = payload.effect
	local durationSeconds = payload.durationSeconds
	if typeof(id) ~= "string" then
		return false
	end

	if typeof(kind) ~= "string" or not isKnownKind(kind) then
		return false
	end

	if typeof(text) ~= "string" then
		return false
	end

	if typeof(effect) ~= "string" or not isKnownEffect(effect) then
		return false
	end

	if typeof(durationSeconds) ~= "number" then
		return false
	end

	local variant = payload.variant
	return variant == nil or (typeof(variant) == "string" and isKnownVariant(variant))
end

local function processAdminAnnouncementQueue()
	if isProcessingAdminAnnouncementQueue then
		return
	end

	isProcessingAdminAnnouncementQueue = true

	while #adminAnnouncementQueue > 0 do
		local notification = table.remove(adminAnnouncementQueue, 1)
		if notification ~= nil then
			getNotificationView():showAdminAnnouncement(notification)
		end
	end

	isProcessingAdminAnnouncementQueue = false
end

local function routeNotification(notification: NotificationPayload)
	if notification.kind == "AdminAnnouncement" then
		table.insert(adminAnnouncementQueue, notification)
		task.spawn(processAdminAnnouncementQueue)
		return
	end

	getNotificationView():showToast(notification)
end

local function handleNotificationReceived(receivedPayload: unknown)
	if not isNotificationPayload(receivedPayload) then
		return
	end

	routeNotification(receivedPayload :: NotificationPayload)
end

local function buildLocalToastPayload(text: string, variant: NotificationVariant?, durationSeconds: number?): NotificationPayload
	return {
		id = HttpService:GenerateGUID(false),
		kind = "Toast",
		text = text,
		effect = "Instant" :: NotificationEffect,
		durationSeconds = durationSeconds or NotificationConfig.toastDurationSeconds,
		variant = variant,
	}
end

local HudNotificationController = {}

function HudNotificationController.start()
	if hasStarted then
		return
	end

	hasStarted = true
	getNotificationView()
	getNotificationReceivedRemote().OnClientEvent:Connect(handleNotificationReceived)
end

function HudNotificationController.showToast(text: string, variant: NotificationVariant?, durationSeconds: number?)
	if text == "" then
		return
	end

	routeNotification(buildLocalToastPayload(text, variant, durationSeconds))
end

return table.freeze(HudNotificationController)

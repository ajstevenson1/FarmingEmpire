--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local notificationsFolder = sharedFolder:WaitForChild("Notifications") :: Folder

local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local NotificationTypes = require(notificationsFolder:WaitForChild("NotificationTypes") :: ModuleScript)
local HudNotificationView = require(script.Parent.HudNotificationView)

type NotificationPayload = NotificationTypes.NotificationPayload
type HudNotificationView = HudNotificationView.HudNotificationView

local hasStarted = false
local isProcessingQueue = false
local notificationQueue: { NotificationPayload } = {}
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

local function isNotificationPayload(value: unknown): boolean
	if typeof(value) ~= "table" then
		return false
	end

	local payload = value :: { [string]: unknown }
	return typeof(payload.id) == "string"
		and typeof(payload.kind) == "string"
		and typeof(payload.text) == "string"
		and typeof(payload.effect) == "string"
		and typeof(payload.durationSeconds) == "number"
end

local function processQueue()
	if isProcessingQueue then
		return
	end

	isProcessingQueue = true

	while #notificationQueue > 0 do
		local notification = table.remove(notificationQueue, 1)
		if notification ~= nil then
			local view = notificationView
			assert(view ~= nil, "HudNotificationView must exist before processing notifications")
			view:show(notification)
		end
	end

	isProcessingQueue = false
end

local function enqueueNotification(receivedPayload: unknown)
	if not isNotificationPayload(receivedPayload) then
		return
	end

	table.insert(notificationQueue, receivedPayload :: NotificationPayload)
	task.spawn(processQueue)
end

local HudNotificationController = {}

function HudNotificationController.start()
	if hasStarted then
		return
	end

	hasStarted = true
	notificationView = HudNotificationView.new()
	getNotificationReceivedRemote().OnClientEvent:Connect(enqueueNotification)
end

return table.freeze(HudNotificationController)

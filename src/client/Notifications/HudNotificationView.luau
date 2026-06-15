--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local notificationsFolder = sharedFolder:WaitForChild("Notifications") :: Folder
local NotificationConfig = require(notificationsFolder:WaitForChild("NotificationConfig") :: ModuleScript)
local NotificationTypes = require(notificationsFolder:WaitForChild("NotificationTypes") :: ModuleScript)

type NotificationPayload = NotificationTypes.NotificationPayload
type NotificationVariant = NotificationTypes.NotificationVariant
type ToastStyle = NotificationConfig.ToastStyle

type Widgets = {
	adminContainer: GuiObject,
	adminTextLabel: TextLabel,
	toastContainer: GuiObject,
	toastTemplate: TextLabel,
}

export type HudNotificationView = {
	_widgets: Widgets,
	_activeToasts: { TextLabel },
	_toastSequence: number,
	showAdminAnnouncement: (self: HudNotificationView, notification: NotificationPayload) -> (),
	showToast: (self: HudNotificationView, notification: NotificationPayload) -> (),
}

local HUD_NAME = "HUD"
local ADMIN_NOTIFICATION_NAME = "AdminAbuse"
local TOAST_NOTIFICATION_NAME = "Notification"
local TEXT_LABEL_NAME = "Text"
local STROKE_NAME = "Stroke"

local DEFAULT_TYPEWRITER_CHARACTERS_PER_SECOND = 32
local DEFAULT_ADMIN_DURATION_SECONDS = 5
local DEFAULT_TOAST_VARIANT: NotificationVariant = "Info"
local TOAST_FADE_EASING = TweenInfo.new(
	NotificationConfig.toastFadeSeconds,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)

local HudNotificationView = {}
HudNotificationView.__index = HudNotificationView

local function getTextStroke(textLabel: TextLabel): UIStroke?
	local namedStroke = textLabel:FindFirstChild(STROKE_NAME)
	if namedStroke ~= nil then
		assert(namedStroke:IsA("UIStroke"), string.format("%s.%s must be a UIStroke", textLabel:GetFullName(), STROKE_NAME))
		return namedStroke
	end

	return textLabel:FindFirstChildOfClass("UIStroke")
end

local function getRequiredTextLabel(parent: Instance, childName: string, pathForError: string): TextLabel
	local child = parent:WaitForChild(childName)
	assert(child:IsA("TextLabel"), string.format("%s must be a TextLabel", pathForError))
	return child
end

local function getWidgets(): Widgets
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before creating HudNotificationView")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild("GUI")
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")

	local hud = rootGui:WaitForChild(HUD_NAME)
	assert(hud:IsA("GuiObject"), "GUI.HUD must be a GuiObject")

	local adminNotification = hud:WaitForChild(ADMIN_NOTIFICATION_NAME)
	assert(adminNotification:IsA("GuiObject"), "GUI.HUD.AdminAbuse must be a GuiObject")

	local toastNotification = hud:WaitForChild(TOAST_NOTIFICATION_NAME)
	assert(toastNotification:IsA("GuiObject"), "GUI.HUD.Notification must be a GuiObject")

	return {
		adminContainer = adminNotification,
		adminTextLabel = getRequiredTextLabel(adminNotification, TEXT_LABEL_NAME, "GUI.HUD.AdminAbuse.Text"),
		toastContainer = toastNotification,
		toastTemplate = getRequiredTextLabel(toastNotification, TEXT_LABEL_NAME, "GUI.HUD.Notification.Text"),
	}
end

local function getUtf8Length(text: string): number
	local success, length = pcall(function()
		return utf8.len(text)
	end)

	if success and typeof(length) == "number" then
		return length
	end

	return #text
end

local function getTextPrefix(text: string, characterCount: number, totalCharacterCount: number): string
	if characterCount <= 0 then
		return ""
	end

	if characterCount >= totalCharacterCount then
		return text
	end

	local success, byteIndex = pcall(function()
		return utf8.offset(text, characterCount + 1)
	end)

	if success and typeof(byteIndex) == "number" then
		return string.sub(text, 1, byteIndex - 1)
	end

	return string.sub(text, 1, characterCount)
end

local function playTypewriter(textLabel: TextLabel, text: string, charactersPerSecond: number)
	local totalCharacterCount = getUtf8Length(text)
	if totalCharacterCount <= 0 then
		textLabel.Text = ""
		return
	end

	local secondsPerCharacter = 1 / math.max(charactersPerSecond, 1)
	for characterIndex = 1, totalCharacterCount do
		textLabel.Text = getTextPrefix(text, characterIndex, totalCharacterCount)
		task.wait(secondsPerCharacter)
	end
end

local function getToastStyle(variant: NotificationVariant?): ToastStyle
	local toastVariant = variant or DEFAULT_TOAST_VARIANT
	return NotificationConfig.toastStyles[toastVariant]
end

local function getDisplayDurationSeconds(notification: NotificationPayload, defaultDurationSeconds: number): number
	return if notification.durationSeconds > 0 then notification.durationSeconds else defaultDurationSeconds
end

local function removeActiveToast(self: HudNotificationView, toast: TextLabel)
	for index, activeToast in ipairs(self._activeToasts) do
		if activeToast == toast then
			table.remove(self._activeToasts, index)
			break
		end
	end

	if toast.Parent ~= nil then
		toast:Destroy()
	end
end

local function enforceToastLimit(self: HudNotificationView)
	while #self._activeToasts > NotificationConfig.toastMaxActive do
		local oldestToast = table.remove(self._activeToasts, 1)
		if oldestToast ~= nil and oldestToast.Parent ~= nil then
			oldestToast:Destroy()
		end
	end
end

local function applyToastStyle(toast: TextLabel, variant: NotificationVariant?)
	local style = getToastStyle(variant)
	toast.TextColor3 = style.textColor

	local stroke = getTextStroke(toast)
	if stroke ~= nil then
		stroke.Color = style.strokeColor
		stroke.Transparency = 0
	end
end

local function resetToastTransparency(toast: TextLabel)
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0

	local stroke = getTextStroke(toast)
	if stroke ~= nil then
		stroke.Transparency = 0
	end
end

local function fadeToast(toast: TextLabel)
	if toast.Parent == nil then
		return
	end

	TweenService:Create(toast, TOAST_FADE_EASING, {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	local stroke = getTextStroke(toast)
	if stroke ~= nil then
		TweenService:Create(stroke, TOAST_FADE_EASING, {
			Transparency = 1,
		}):Play()
	end
end

function HudNotificationView.new(): HudNotificationView
	local self = setmetatable({
		_widgets = getWidgets(),
		_activeToasts = {},
		_toastSequence = 0,
	}, HudNotificationView) :: HudNotificationView

	self._widgets.adminContainer.Visible = false
	self._widgets.adminTextLabel.Text = ""
	self._widgets.toastContainer.Visible = true
	self._widgets.toastTemplate.Text = ""
	self._widgets.toastTemplate.Visible = false

	return self
end

function HudNotificationView:showAdminAnnouncement(notification: NotificationPayload)
	local widgets = self._widgets
	widgets.adminContainer.Visible = true

	if notification.effect == "Typewriter" then
		widgets.adminTextLabel.Text = ""
		playTypewriter(
			widgets.adminTextLabel,
			notification.text,
			notification.typewriterCharactersPerSecond or DEFAULT_TYPEWRITER_CHARACTERS_PER_SECOND
		)
	else
		widgets.adminTextLabel.Text = notification.text
	end

	task.wait(getDisplayDurationSeconds(notification, DEFAULT_ADMIN_DURATION_SECONDS))

	widgets.adminTextLabel.Text = ""
	widgets.adminContainer.Visible = false
end

function HudNotificationView:showToast(notification: NotificationPayload)
	self._toastSequence += 1

	local toast = self._widgets.toastTemplate:Clone()
	toast.Name = string.format("Notification%d", self._toastSequence)
	toast.LayoutOrder = self._toastSequence
	toast.Text = notification.text
	toast.Visible = true
	resetToastTransparency(toast)
	applyToastStyle(toast, notification.variant)
	toast.Parent = self._widgets.toastContainer

	table.insert(self._activeToasts, toast)
	enforceToastLimit(self)

	local displayDurationSeconds = getDisplayDurationSeconds(notification, NotificationConfig.toastDurationSeconds)
	local fadeDelaySeconds = math.min(NotificationConfig.toastFadeDelaySeconds, displayDurationSeconds)
	task.delay(fadeDelaySeconds, function()
		fadeToast(toast)
	end)

	task.delay(displayDurationSeconds, function()
		removeActiveToast(self, toast)
	end)
end

return HudNotificationView

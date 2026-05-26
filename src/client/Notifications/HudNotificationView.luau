--!strict

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local notificationsFolder = sharedFolder:WaitForChild("Notifications") :: Folder
local NotificationTypes = require(notificationsFolder:WaitForChild("NotificationTypes") :: ModuleScript)

type NotificationPayload = NotificationTypes.NotificationPayload

type Widgets = {
	container: GuiObject,
	textLabel: TextLabel,
}

export type HudNotificationView = {
	_widgets: Widgets,
	show: (self: HudNotificationView, notification: NotificationPayload) -> (),
}

local HUD_NAME = "HUD"
local NOTIFICATION_NAME = "Notification"
local TEXT_LABEL_NAME = "Text"

local DEFAULT_TYPEWRITER_CHARACTERS_PER_SECOND = 32
local DEFAULT_DURATION_SECONDS = 5

local HudNotificationView = {}
HudNotificationView.__index = HudNotificationView

local function getWidgets(): Widgets
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before creating HudNotificationView")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild("GUI")
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")

	local hud = rootGui:WaitForChild(HUD_NAME)
	assert(hud:IsA("GuiObject"), "GUI.HUD must be a GuiObject")

	local notification = hud:WaitForChild(NOTIFICATION_NAME)
	assert(notification:IsA("GuiObject"), "GUI.HUD.Notification must be a GuiObject")

	local textLabel = notification:WaitForChild(TEXT_LABEL_NAME)
	assert(textLabel:IsA("TextLabel"), "GUI.HUD.Notification.Text must be a TextLabel")

	return {
		container = notification,
		textLabel = textLabel,
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

function HudNotificationView.new(): HudNotificationView
	local self = setmetatable({
		_widgets = getWidgets(),
	}, HudNotificationView) :: HudNotificationView

	self._widgets.container.Visible = false
	self._widgets.textLabel.Text = ""

	return self
end

function HudNotificationView:show(notification: NotificationPayload)
	local widgets = self._widgets
	widgets.container.Visible = true

	if notification.effect == "Typewriter" then
		widgets.textLabel.Text = ""
		playTypewriter(
			widgets.textLabel,
			notification.text,
			notification.typewriterCharactersPerSecond or DEFAULT_TYPEWRITER_CHARACTERS_PER_SECOND
		)
	else
		widgets.textLabel.Text = notification.text
	end

	local displayDurationSeconds = if notification.durationSeconds > 0
		then notification.durationSeconds
		else DEFAULT_DURATION_SECONDS
	task.wait(displayDurationSeconds)

	widgets.textLabel.Text = ""
	widgets.container.Visible = false
end

return HudNotificationView

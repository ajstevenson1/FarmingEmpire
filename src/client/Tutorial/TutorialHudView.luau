--!strict

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local tutorialFolder = sharedFolder:WaitForChild("Tutorial") :: Folder
local TutorialTypes = require(tutorialFolder:WaitForChild("TutorialTypes") :: ModuleScript)

type TutorialStepDefinition = TutorialTypes.TutorialStepDefinition

type Widgets = {
	rootGui: ScreenGui,
	container: GuiObject,
	textLabel: TextLabel,
	skipOpenButton: GuiButton,
	skipModal: GuiObject,
	skipConfirmButton: GuiButton,
	skipBackButton: GuiButton,
}

export type TutorialHudView = {
	_widgets: Widgets,
	_stepVersion: number,
	_isTyping: boolean,
	_fullText: string,
	_tapToContinue: boolean,
	_autoContinueDelaySeconds: number?,
	_continueCallbacks: { () -> () },
	_skipCallbacks: { () -> () },
	_scheduleAutoContinue: (self: TutorialHudView, stepVersion: number, delaySeconds: number) -> (),
	_playTypewriter: (self: TutorialHudView, stepVersion: number, text: string) -> (),
	showStep: (self: TutorialHudView, step: TutorialStepDefinition) -> (),
	hide: (self: TutorialHudView) -> (),
	connectContinueRequested: (self: TutorialHudView, callback: () -> ()) -> (),
	connectSkipRequested: (self: TutorialHudView, callback: () -> ()) -> (),
	destroy: (self: TutorialHudView) -> (),
}

local HUD_NAME = "HUD"
local TUTORIAL_NAME = "Tutorial"
local TEXT_LABEL_NAME = "Text"
local SKIP_BUTTON_NAME = "Skip"
local FRAMES_NAME = "Frames"
local SKIP_TUTORIAL_FRAME_NAME = "SkipTutorial"
local MODAL_FRAME_NAME = "Frame"
local BACK_BUTTON_NAME = "Back"

local TYPEWRITER_CHARACTERS_PER_SECOND = 20
local NOTIFICATION_Z_INDEX = 20
local AUTO_CONTINUE_DELAY_SECONDS = 2

local TutorialHudView = {}
TutorialHudView.__index = TutorialHudView

local function getWidgets(): Widgets
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before creating TutorialHudView")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild("GUI")
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")

	local hud = rootGui:WaitForChild(HUD_NAME)
	assert(hud:IsA("GuiObject"), "GUI.HUD must be a GuiObject")

	local tutorial = hud:WaitForChild(TUTORIAL_NAME)
	assert(tutorial:IsA("GuiObject"), "GUI.HUD.Tutorial must be a GuiObject")

	local textLabel = tutorial:WaitForChild(TEXT_LABEL_NAME)
	assert(textLabel:IsA("TextLabel"), "GUI.HUD.Tutorial.Text must be a TextLabel")

	local skipOpenButton = tutorial:WaitForChild(SKIP_BUTTON_NAME)
	assert(skipOpenButton:IsA("GuiButton"), "GUI.HUD.Tutorial.Skip must be a GuiButton")

	local frames = rootGui:WaitForChild(FRAMES_NAME)
	assert(frames:IsA("GuiObject"), "PlayerGui.GUI.Frames must be a GuiObject")

	local skipModal = frames:WaitForChild(SKIP_TUTORIAL_FRAME_NAME)
	assert(skipModal:IsA("GuiObject"), "GUI.Frames.SkipTutorial must be a GuiObject")

	local modalFrame = skipModal:WaitForChild(MODAL_FRAME_NAME)
	assert(modalFrame:IsA("GuiObject"), "GUI.Frames.SkipTutorial.Frame must be a GuiObject")

	local skipConfirmButton = modalFrame:WaitForChild(SKIP_BUTTON_NAME)
	assert(skipConfirmButton:IsA("GuiButton"), "GUI.Frames.SkipTutorial.Frame.Skip must be a GuiButton")

	local skipBackButton = modalFrame:WaitForChild(BACK_BUTTON_NAME)
	assert(skipBackButton:IsA("GuiButton"), "GUI.Frames.SkipTutorial.Frame.Back must be a GuiButton")

	return {
		rootGui = rootGui,
		container = tutorial,
		textLabel = textLabel,
		skipOpenButton = skipOpenButton,
		skipModal = skipModal,
		skipConfirmButton = skipConfirmButton,
		skipBackButton = skipBackButton,
	}
end

local function raiseZIndex(instance: Instance)
	if instance:IsA("GuiObject") then
		instance.ZIndex = math.max(instance.ZIndex, NOTIFICATION_Z_INDEX)
	end

	for _, child in ipairs(instance:GetChildren()) do
		raiseZIndex(child)
	end
end

local function getVisibleCharacterCount(richText: string): number
	local count = 0
	local index = 1
	while index <= #richText do
		local character = string.sub(richText, index, index)
		if character == "<" then
			local closeIndex = string.find(richText, ">", index, true)
			if closeIndex == nil then
				count += 1
				index += 1
			else
				index = closeIndex + 1
			end
		else
			count += 1
			index += 1
		end
	end

	return count
end

local function getRichTextPrefix(richText: string, visibleCharacters: number): string
	local output: { string } = {}
	local openClosingTags: { string } = {}
	local visibleCount = 0
	local index = 1

	while index <= #richText and visibleCount < visibleCharacters do
		local character = string.sub(richText, index, index)
		if character == "<" then
			local closeIndex = string.find(richText, ">", index, true)
			if closeIndex == nil then
				table.insert(output, character)
				visibleCount += 1
				index += 1
			else
				local tagText = string.sub(richText, index, closeIndex)
				table.insert(output, tagText)
				local tagBody = string.sub(tagText, 2, #tagText - 1)
				if string.sub(tagBody, 1, 1) == "/" then
					table.remove(openClosingTags)
				else
					local tagName = string.match(tagBody, "^(%w+)")
					if tagName ~= nil then
						table.insert(openClosingTags, 1, string.format("</%s>", tagName))
					end
				end
				index = closeIndex + 1
			end
		else
			table.insert(output, character)
			visibleCount += 1
			index += 1
		end
	end

	for _, closingTag in ipairs(openClosingTags) do
		table.insert(output, closingTag)
	end

	return table.concat(output)
end

function TutorialHudView.new(): TutorialHudView
	local widgets = getWidgets()
	raiseZIndex(widgets.container)
	widgets.textLabel.RichText = true
	widgets.container.Visible = false
	widgets.skipModal.Visible = false

	local self = setmetatable({
		_widgets = widgets,
		_stepVersion = 0,
		_isTyping = false,
		_fullText = "",
		_tapToContinue = false,
		_autoContinueDelaySeconds = nil,
		_continueCallbacks = {},
		_skipCallbacks = {},
	}, TutorialHudView) :: TutorialHudView

	widgets.skipOpenButton.Activated:Connect(function()
		if widgets.container.Visible then
			widgets.skipModal.Visible = true
		end
	end)

	widgets.skipBackButton.Activated:Connect(function()
		widgets.skipModal.Visible = false
	end)

	widgets.skipConfirmButton.Activated:Connect(function()
		widgets.skipModal.Visible = false
		for _, callback in ipairs(self._skipCallbacks) do
			callback()
		end
	end)

	return self
end

function TutorialHudView:_scheduleAutoContinue(stepVersion: number, delaySeconds: number)
	task.delay(delaySeconds, function()
		if self._stepVersion ~= stepVersion or self._isTyping then
			return
		end

		for _, callback in ipairs(self._continueCallbacks) do
			callback()
		end
	end)
end

function TutorialHudView:_playTypewriter(stepVersion: number, text: string)
	self._isTyping = true

	local visibleCharacterCount = getVisibleCharacterCount(text)
	if visibleCharacterCount <= 0 then
		self._widgets.textLabel.Text = ""
		self._isTyping = false
		return
	end

	local secondsPerCharacter = 1 / TYPEWRITER_CHARACTERS_PER_SECOND
	for characterIndex = 1, visibleCharacterCount do
		if self._stepVersion ~= stepVersion or not self._isTyping then
			return
		end

		self._widgets.textLabel.Text = getRichTextPrefix(text, characterIndex)
		task.wait(secondsPerCharacter)
	end

	if self._stepVersion ~= stepVersion then
		return
	end

	self._widgets.textLabel.Text = text
	self._isTyping = false
	if self._tapToContinue then
		self:_scheduleAutoContinue(stepVersion, AUTO_CONTINUE_DELAY_SECONDS)
	elseif self._autoContinueDelaySeconds ~= nil then
		self:_scheduleAutoContinue(stepVersion, self._autoContinueDelaySeconds)
	end
end

function TutorialHudView:showStep(step: TutorialStepDefinition)
	self._stepVersion += 1
	local stepVersion = self._stepVersion
	self._fullText = step.text
	self._tapToContinue = step.tapToContinue
	self._autoContinueDelaySeconds = step.autoContinueDelaySeconds
	self._isTyping = false

	self._widgets.container.Visible = true
	self._widgets.textLabel.Text = ""
	task.spawn(function()
		self:_playTypewriter(stepVersion, step.text)
	end)

	if step.autoDismissSeconds ~= nil then
		task.delay(step.autoDismissSeconds, function()
			if self._stepVersion == stepVersion then
				self:hide()
			end
		end)
	end
end

function TutorialHudView:hide()
	self._stepVersion += 1
	self._isTyping = false
	self._tapToContinue = false
	self._autoContinueDelaySeconds = nil
	self._fullText = ""
	self._widgets.textLabel.Text = ""
	self._widgets.container.Visible = false
	self._widgets.skipModal.Visible = false
end

function TutorialHudView:connectContinueRequested(callback: () -> ())
	table.insert(self._continueCallbacks, callback)
end

function TutorialHudView:connectSkipRequested(callback: () -> ())
	table.insert(self._skipCallbacks, callback)
end

function TutorialHudView:destroy()
	self:hide()
	table.clear(self._continueCallbacks)
	table.clear(self._skipCallbacks)
end

return TutorialHudView

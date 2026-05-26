--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local tutorialFolder = sharedFolder:WaitForChild("Tutorial") :: Folder
local TutorialTypes = require(tutorialFolder:WaitForChild("TutorialTypes") :: ModuleScript)

type TutorialStepDefinition = TutorialTypes.TutorialStepDefinition

type Widgets = {
	rootGui: ScreenGui,
	container: GuiObject,
	textLabel: TextLabel,
	tapToContinueLabel: TextLabel,
}

export type TutorialHudView = {
	_widgets: Widgets,
	_stepVersion: number,
	_isTyping: boolean,
	_fullText: string,
	_tapToContinue: boolean,
	_continueCallbacks: { () -> () },
	_inputConnection: RBXScriptConnection?,
	_animateTapToContinue: (self: TutorialHudView, stepVersion: number) -> (),
	_playTypewriter: (self: TutorialHudView, stepVersion: number, text: string) -> (),
	showStep: (self: TutorialHudView, step: TutorialStepDefinition) -> (),
	hide: (self: TutorialHudView) -> (),
	connectContinueRequested: (self: TutorialHudView, callback: () -> ()) -> (),
	destroy: (self: TutorialHudView) -> (),
}

local HUD_NAME = "HUD"
local TUTORIAL_NAME = "Tutorial"
local TEXT_LABEL_NAME = "Text"
local TAP_TO_CONTINUE_LABEL_NAME = "TapToContinue"

local TYPEWRITER_CHARACTERS_PER_SECOND = 20
local NOTIFICATION_Z_INDEX = 20

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

	local tapToContinueLabel = tutorial:WaitForChild(TAP_TO_CONTINUE_LABEL_NAME)
	assert(tapToContinueLabel:IsA("TextLabel"), "GUI.HUD.Tutorial.TapToContinue must be a TextLabel")

	return {
		rootGui = rootGui,
		container = tutorial,
		textLabel = textLabel,
		tapToContinueLabel = tapToContinueLabel,
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

local function isPrimaryPointerInput(inputObject: InputObject): boolean
	return inputObject.UserInputType == Enum.UserInputType.MouseButton1
		or inputObject.UserInputType == Enum.UserInputType.Touch
end

function TutorialHudView.new(): TutorialHudView
	local widgets = getWidgets()
	raiseZIndex(widgets.container)
	widgets.textLabel.RichText = true
	widgets.tapToContinueLabel.RichText = true
	widgets.tapToContinueLabel.Visible = false
	widgets.container.Visible = false

	local self = setmetatable({
		_widgets = widgets,
		_stepVersion = 0,
		_isTyping = false,
		_fullText = "",
		_tapToContinue = false,
		_continueCallbacks = {},
		_inputConnection = nil,
	}, TutorialHudView) :: TutorialHudView

	self._inputConnection = UserInputService.InputBegan:Connect(function(inputObject: InputObject, _gameProcessed: boolean)
		if not isPrimaryPointerInput(inputObject) or not widgets.container.Visible then
			return
		end

		if self._isTyping then
			self._isTyping = false
			self._stepVersion += 1
			widgets.textLabel.Text = self._fullText
			widgets.tapToContinueLabel.Visible = self._tapToContinue
			return
		end

		if self._tapToContinue then
			for _, callback in ipairs(self._continueCallbacks) do
				callback()
			end
		end
	end)

	return self
end

function TutorialHudView:_animateTapToContinue(stepVersion: number)
	local dotCount = 1
	local dotFrames = { ".", ". .", ". . ." }
	while self._stepVersion == stepVersion and self._tapToContinue and not self._isTyping do
		self._widgets.tapToContinueLabel.Text = "Tap to continue" .. dotFrames[dotCount]
		dotCount = if dotCount >= 3 then 1 else dotCount + 1
		task.wait(0.35)
	end
end

function TutorialHudView:_playTypewriter(stepVersion: number, text: string)
	self._isTyping = true
	self._widgets.tapToContinueLabel.Visible = false

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
	self._widgets.tapToContinueLabel.Visible = self._tapToContinue
	if self._tapToContinue then
		task.spawn(function()
			self:_animateTapToContinue(stepVersion)
		end)
	end
end

function TutorialHudView:showStep(step: TutorialStepDefinition)
	self._stepVersion += 1
	local stepVersion = self._stepVersion
	self._fullText = step.text
	self._tapToContinue = step.tapToContinue
	self._isTyping = false

	self._widgets.container.Visible = true
	self._widgets.textLabel.Text = ""
	self._widgets.tapToContinueLabel.Visible = false
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
	self._fullText = ""
	self._widgets.textLabel.Text = ""
	self._widgets.tapToContinueLabel.Visible = false
	self._widgets.container.Visible = false
end

function TutorialHudView:connectContinueRequested(callback: () -> ())
	table.insert(self._continueCallbacks, callback)
end

function TutorialHudView:destroy()
	self:hide()
	if self._inputConnection ~= nil then
		self._inputConnection:Disconnect()
		self._inputConnection = nil
	end
	table.clear(self._continueCallbacks)
end

return TutorialHudView

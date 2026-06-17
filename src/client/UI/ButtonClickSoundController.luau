--!strict

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local AudioService = require(script.Parent.Parent.Audio.AudioService)

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local uiFolder = sharedFolder:WaitForChild("UI") :: Folder
local ButtonSoundConfig = require(uiFolder:WaitForChild("ButtonSoundConfig") :: ModuleScript)

type GuiButtonLike = TextButton | ImageButton
type ButtonSoundKey = "Click" | "Buy" | "Store"

export type ButtonClickSoundController = {
	start: () -> (),
	destroy: () -> (),
}

local ROOT_GUI_NAME = "GUI"

local hasStarted = false
local rootConnection: RBXScriptConnection? = nil
local boundConnectionsByButton: { [GuiButtonLike]: RBXScriptConnection } = {}
local soundPoolsByKey: { [ButtonSoundKey]: { Sound } } = {
	Click = {},
	Buy = {},
	Store = {},
}
local nextSoundIndexByKey: { [ButtonSoundKey]: number } = {
	Click = 1,
	Buy = 1,
	Store = 1,
}

local function isGuiButtonLike(instance: Instance): boolean
	return instance:IsA("TextButton") or instance:IsA("ImageButton")
end

local function getSoundName(soundKey: ButtonSoundKey): string
	if soundKey == "Buy" then
		return ButtonSoundConfig.BuySoundName
	end

	if soundKey == "Store" then
		return ButtonSoundConfig.StoreOpenSoundName
	end

	return ButtonSoundConfig.ClickSoundName
end

local function getSoundId(soundKey: ButtonSoundKey): string
	if soundKey == "Buy" then
		return ButtonSoundConfig.BuySoundId
	end

	if soundKey == "Store" then
		return ButtonSoundConfig.StoreOpenSoundId
	end

	return ButtonSoundConfig.ClickSoundId
end

local function createButtonSound(soundKey: ButtonSoundKey, index: number): Sound
	local sound = Instance.new("Sound")
	sound.Name = string.format("%s%d", getSoundName(soundKey), index)
	sound.SoundId = getSoundId(soundKey)
	sound.Volume = ButtonSoundConfig.Volume
	sound.PlaybackSpeed = 1
	sound.Looped = false
	AudioService.assignSoundToBus(sound, "SFX")
	sound.Parent = SoundService
	return sound
end

local function getButtonSound(soundKey: ButtonSoundKey, index: number): Sound
	local soundPool = soundPoolsByKey[soundKey]
	local existing = soundPool[index]
	if existing ~= nil then
		return existing
	end

	local created = createButtonSound(soundKey, index)
	soundPool[index] = created
	return created
end

local function playButtonSound(soundKey: ButtonSoundKey)
	local poolSize = math.max(1, ButtonSoundConfig.PoolSize)
	local nextSoundIndex = nextSoundIndexByKey[soundKey]
	local sound = getButtonSound(soundKey, nextSoundIndex)
	nextSoundIndexByKey[soundKey] = (nextSoundIndex % poolSize) + 1

	sound:Stop()
	sound.TimePosition = 0
	sound:Play()
end

local function getButtonSoundKey(button: GuiButtonLike): ButtonSoundKey
	if CollectionService:HasTag(button, ButtonSoundConfig.StoreTagName) then
		return "Store"
	end

	if CollectionService:HasTag(button, ButtonSoundConfig.BuyTagName) then
		return "Buy"
	end

	return "Click"
end

local function shouldSuppressButtonSound(button: GuiButtonLike): boolean
	return button:GetAttribute(ButtonSoundConfig.SuppressSoundAttributeName) == true
end

local function unbindButton(button: GuiButtonLike)
	local connection = boundConnectionsByButton[button]
	if connection == nil then
		return
	end

	connection:Disconnect()
	boundConnectionsByButton[button] = nil
end

local function bindButton(button: GuiButtonLike)
	if boundConnectionsByButton[button] ~= nil then
		return
	end

	boundConnectionsByButton[button] = button.Activated:Connect(function()
		if shouldSuppressButtonSound(button) then
			return
		end

		playButtonSound(getButtonSoundKey(button))
	end)

	button.Destroying:Connect(function()
		unbindButton(button)
	end)
end

local function bindDescendantTree(rootGui: ScreenGui)
	for _, descendant in ipairs(rootGui:GetDescendants()) do
		if isGuiButtonLike(descendant) then
			bindButton(descendant :: GuiButtonLike)
		end
	end
end

local ButtonClickSoundController = {} :: ButtonClickSoundController

function ButtonClickSoundController.start()
	if hasStarted then
		return
	end

	hasStarted = true
	AudioService.start()

	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before starting ButtonClickSoundController")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild(ROOT_GUI_NAME)
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")

	bindDescendantTree(rootGui)

	rootConnection = rootGui.DescendantAdded:Connect(function(descendant: Instance)
		if isGuiButtonLike(descendant) then
			bindButton(descendant :: GuiButtonLike)
			return
		end

		local current: Instance? = descendant.Parent
		while current ~= nil and current ~= rootGui do
			if isGuiButtonLike(current) then
				bindButton(current :: GuiButtonLike)
				return
			end

			current = current.Parent
		end
	end)
end

function ButtonClickSoundController.destroy()
	if rootConnection ~= nil then
		rootConnection:Disconnect()
		rootConnection = nil
	end

	for button in pairs(table.clone(boundConnectionsByButton)) do
		unbindButton(button)
	end

	for _, soundPool in pairs(soundPoolsByKey) do
		for _, sound in ipairs(soundPool) do
			sound:Destroy()
		end
		table.clear(soundPool)
	end
	nextSoundIndexByKey.Click = 1
	nextSoundIndexByKey.Buy = 1
	nextSoundIndexByKey.Store = 1

	hasStarted = false
end

return table.freeze(ButtonClickSoundController)

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local AudioService = require(script.Parent.Parent.Audio.AudioService)

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local uiFolder = sharedFolder:WaitForChild("UI") :: Folder
local ButtonSoundConfig = require(uiFolder:WaitForChild("ButtonSoundConfig") :: ModuleScript)

type GuiButtonLike = TextButton | ImageButton

export type ButtonClickSoundController = {
	start: () -> (),
	destroy: () -> (),
}

local ROOT_GUI_NAME = "GUI"

local hasStarted = false
local rootConnection: RBXScriptConnection? = nil
local boundConnectionsByButton: { [GuiButtonLike]: RBXScriptConnection } = {}
local soundPool: { Sound } = {}
local nextSoundIndex = 1

local function isGuiButtonLike(instance: Instance): boolean
	return instance:IsA("TextButton") or instance:IsA("ImageButton")
end

local function createClickSound(index: number): Sound
	local sound = Instance.new("Sound")
	sound.Name = string.format("%s%d", ButtonSoundConfig.ClickSoundName, index)
	sound.SoundId = ButtonSoundConfig.ClickSoundId
	sound.Volume = ButtonSoundConfig.Volume
	sound.PlaybackSpeed = 1
	sound.Looped = false
	AudioService.assignSoundToBus(sound, "SFX")
	sound.Parent = SoundService
	return sound
end

local function getClickSound(index: number): Sound
	local existing = soundPool[index]
	if existing ~= nil then
		return existing
	end

	local created = createClickSound(index)
	soundPool[index] = created
	return created
end

local function playClickSound()
	local poolSize = math.max(1, ButtonSoundConfig.PoolSize)
	local sound = getClickSound(nextSoundIndex)
	nextSoundIndex = (nextSoundIndex % poolSize) + 1

	sound:Stop()
	sound.TimePosition = 0
	sound:Play()
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
		playClickSound()
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

	for _, sound in ipairs(soundPool) do
		sound:Destroy()
	end
	table.clear(soundPool)

	hasStarted = false
end

return table.freeze(ButtonClickSoundController)

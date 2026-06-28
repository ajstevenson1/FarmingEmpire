--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local updateEventsFolder = sharedFolder:WaitForChild("UpdateEvents") :: Folder

local UpdateEventConfig = require(updateEventsFolder:WaitForChild("UpdateEventConfig") :: ModuleScript)
local Remotes = require(script.Parent.Parent.Networking.Remotes)

local UpdateEventPlateService = {}

local hasStarted = false
local nextAllowedPromptAtByPlayer: { [Player]: number } = {}

local function getCurrentTime(): number
	return Workspace:GetServerTimeNow()
end

local function findPlayerFromTouchedPart(touchedPart: BasePart): Player?
	local current: Instance? = touchedPart
	while current ~= nil and current ~= Workspace do
		if current:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(current)
			if player ~= nil then
				return player
			end
		end

		current = current.Parent
	end

	return nil
end

local function findTouchPart(): BasePart?
	local plate = Workspace:FindFirstChild(UpdateEventConfig.plateName)
	if plate == nil then
		warn(string.format("[UpdateEventPlateService] Missing Workspace.%s.", UpdateEventConfig.plateName))
		return nil
	end

	local touchPart = plate:FindFirstChild(UpdateEventConfig.touchPartName, true)
	if touchPart == nil then
		warn(string.format(
			"[UpdateEventPlateService] Missing %s.%s.",
			plate:GetFullName(),
			UpdateEventConfig.touchPartName
		))
		return nil
	end

	if not touchPart:IsA("BasePart") then
		warn(string.format("[UpdateEventPlateService] %s must be a BasePart.", touchPart:GetFullName()))
		return nil
	end

	if not touchPart.CanTouch then
		warn(string.format("[UpdateEventPlateService] %s needs CanTouch enabled.", touchPart:GetFullName()))
	end

	return touchPart
end

local function canPromptPlayer(player: Player, currentTime: number): boolean
	local nextAllowedPromptAt = nextAllowedPromptAtByPlayer[player] or 0
	if currentTime < nextAllowedPromptAt then
		return false
	end

	nextAllowedPromptAtByPlayer[player] = currentTime + UpdateEventConfig.touchCooldownSeconds
	return true
end

local function processTouchForPlayer(player: Player, promptRemote: RemoteEvent)
	if not canPromptPlayer(player, getCurrentTime()) then
		return
	end

	promptRemote:FireClient(player)
end

function UpdateEventPlateService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local touchPart = findTouchPart()
	if touchPart == nil then
		return
	end

	local promptRemote = Remotes.getUpdateEventRemotes().promptUpdateEventRsvp
	touchPart.Touched:Connect(function(touchedPart: BasePart)
		local player = findPlayerFromTouchedPart(touchedPart)
		if player == nil then
			return
		end

		processTouchForPlayer(player, promptRemote)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		nextAllowedPromptAtByPlayer[player] = nil
	end)
end

return table.freeze(UpdateEventPlateService)

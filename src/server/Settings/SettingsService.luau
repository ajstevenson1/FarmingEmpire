--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local settingsFolder = sharedFolder:WaitForChild("Settings") :: Folder

local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)
local Remotes = require(script.Parent.Parent.Networking.Remotes)
local SettingsConfig = require(settingsFolder:WaitForChild("SettingsConfig") :: ModuleScript)

type SettingId = SettingsConfig.SettingId
type SettingsValues = SettingsConfig.SettingsValues

local hasStarted = false

local function buildSnapshot(player: Player): SettingsValues
	return PlayerDataService.getSettings(player)
end

local function handleSettingChanged(player: Player, requestedSettingId: unknown, requestedValue: unknown)
	if not SettingsConfig.isSettingId(requestedSettingId) then
		return
	end

	local settingId = requestedSettingId :: SettingId
	local sanitizedValue = SettingsConfig.sanitizeSettingValue(settingId, requestedValue)
	PlayerDataService.setSettingValue(player, settingId, sanitizedValue)
end

local SettingsService = {}

function SettingsService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local settingsRemotes = Remotes.getSettingsRemotes()
	settingsRemotes.getSettingsSnapshot.OnServerInvoke = function(player: Player): SettingsValues
		return buildSnapshot(player)
	end

	settingsRemotes.settingChanged.OnServerEvent:Connect(handleSettingChanged)
end

return table.freeze(SettingsService)

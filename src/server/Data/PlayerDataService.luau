--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local PlayerDataStore = require(script.Parent.PlayerDataStore)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)

type PlayerData = PlayerDataStore.PlayerData
type ResourceId = ResourceTypes.ResourceId

type PlayerDataRecord = {
	data: PlayerData,
	canSave: boolean,
	isDirty: boolean,
	isSaving: boolean,
	revision: number,
}

local AUTOSAVE_INTERVAL_SECONDS = 120

local playerDataRecords: { [Player]: PlayerDataRecord } = {}
local loadingPlayers: { [Player]: boolean } = {}
local hasStarted = false

local function sanitizeAmount(amount: number): number
	if amount ~= amount or amount == math.huge or amount < 0 then
		return 0
	end

	return math.floor(amount)
end

local function markDirty(record: PlayerDataRecord)
	record.isDirty = true
	record.revision += 1
end

local function loadPlayerData(player: Player): PlayerDataRecord
	local existingRecord = playerDataRecords[player]
	if existingRecord ~= nil then
		return existingRecord
	end

	while loadingPlayers[player] == true do
		task.wait()

		local loadedRecord = playerDataRecords[player]
		if loadedRecord ~= nil then
			return loadedRecord
		end
	end

	loadingPlayers[player] = true
	local result = PlayerDataStore.loadAsync(player.UserId)
	local record: PlayerDataRecord = {
		data = result.data,
		canSave = result.didLoad,
		isDirty = false,
		isSaving = false,
		revision = 0,
	}

	playerDataRecords[player] = record
	loadingPlayers[player] = nil

	if not result.didLoad then
		warn(string.format("Using temporary unsaved data for %s because their profile failed to load.", player.Name))
	end

	return record
end

local function savePlayerData(player: Player, forceSave: boolean): boolean
	local record = playerDataRecords[player]
	if record == nil or not record.canSave then
		return false
	end

	if not forceSave and not record.isDirty then
		return true
	end

	while record.isSaving do
		task.wait()
	end

	local savedRevision = record.revision
	record.isSaving = true
	local didSave = PlayerDataStore.saveAsync(player.UserId, record.data)
	record.isSaving = false

	if didSave and record.revision == savedRevision then
		record.isDirty = false
	end

	return didSave
end

local function removePlayerData(player: Player)
	while loadingPlayers[player] == true do
		task.wait()
	end

	savePlayerData(player, true)
	playerDataRecords[player] = nil
	loadingPlayers[player] = nil
end

local function startAutosaveLoop()
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL_SECONDS)

			for player in pairs(playerDataRecords) do
				savePlayerData(player, false)
			end
		end
	end)
end

local PlayerDataService = {}

function PlayerDataService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	Players.PlayerAdded:Connect(function(player: Player)
		loadPlayerData(player)
	end)

	Players.PlayerRemoving:Connect(removePlayerData)

	game:BindToClose(function()
		for player in pairs(playerDataRecords) do
			savePlayerData(player, true)
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		loadPlayerData(player)
	end

	startAutosaveLoop()
end

function PlayerDataService.waitForData(player: Player): PlayerData
	return loadPlayerData(player).data
end

function PlayerDataService.getCash(player: Player): number
	local record = loadPlayerData(player)
	return record.data.economy.cash
end

function PlayerDataService.setCash(player: Player, cash: number)
	local record = loadPlayerData(player)
	record.data.economy.cash = sanitizeAmount(cash)
	markDirty(record)
end

function PlayerDataService.getResourceAmount(player: Player, resourceId: ResourceId): number
	local record = loadPlayerData(player)
	return record.data.resources[resourceId] or 0
end

function PlayerDataService.setResourceAmount(player: Player, resourceId: ResourceId, amount: number)
	local record = loadPlayerData(player)
	record.data.resources[resourceId] = sanitizeAmount(amount)
	markDirty(record)
end

function PlayerDataService.getResourceAmounts(player: Player): { [ResourceId]: number }
	local record = loadPlayerData(player)
	local amountsByResourceId: { [ResourceId]: number } = {}

	for resourceId, amount in pairs(record.data.resources) do
		amountsByResourceId[resourceId] = amount
	end

	return amountsByResourceId
end

function PlayerDataService.saveNow(player: Player): boolean
	return savePlayerData(player, true)
end

return table.freeze(PlayerDataService)

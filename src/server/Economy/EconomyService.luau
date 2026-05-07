--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local economyFolder = sharedFolder:WaitForChild("Economy") :: Folder

local EconomyTypes = require(economyFolder:WaitForChild("EconomyTypes") :: ModuleScript)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)
local Remotes = require(script.Parent.Parent.Networking.Remotes)

type EconomySnapshot = EconomyTypes.EconomySnapshot

local hasStarted = false

local function buildSnapshot(player: Player): EconomySnapshot
	return {
		cash = PlayerDataService.getCash(player),
	}
end

local function pushEconomyUpdate(player: Player)
	local economyRemotes = Remotes.getEconomyRemotes()
	economyRemotes.economyUpdated:FireClient(player, buildSnapshot(player))
end

local function initializePlayer(player: Player)
	PlayerDataService.waitForData(player)
	pushEconomyUpdate(player)
end

local EconomyService = {}

function EconomyService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local economyRemotes = Remotes.getEconomyRemotes()
	economyRemotes.getEconomySnapshot.OnServerInvoke = function(player: Player): EconomySnapshot
		return buildSnapshot(player)
	end

	Players.PlayerAdded:Connect(initializePlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		initializePlayer(player)
	end
end

function EconomyService.addCash(player: Player, amount: number)
	if amount <= 0 then
		return
	end

	PlayerDataService.setCash(player, PlayerDataService.getCash(player) + amount)
	pushEconomyUpdate(player)
end

function EconomyService.trySpendCash(player: Player, amount: number): boolean
	if amount <= 0 then
		return false
	end

	local currentCash = PlayerDataService.getCash(player)
	if currentCash < amount then
		pushEconomyUpdate(player)
		return false
	end

	PlayerDataService.setCash(player, currentCash - amount)
	pushEconomyUpdate(player)
	return true
end

function EconomyService.getCash(player: Player): number
	return PlayerDataService.getCash(player)
end

return table.freeze(EconomyService)

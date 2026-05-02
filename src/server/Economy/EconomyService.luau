--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local economyFolder = sharedFolder:WaitForChild("Economy") :: Folder

local EconomyTypes = require(economyFolder:WaitForChild("EconomyTypes") :: ModuleScript)
local Remotes = require(script.Parent.Parent.Networking.Remotes)

type EconomySnapshot = EconomyTypes.EconomySnapshot

type PlayerEconomyState = {
	cash: number,
}

local playerEconomies: { [Player]: PlayerEconomyState } = {}
local hasStarted = false

local function createEconomyState(): PlayerEconomyState
	return {
		cash = 0,
	}
end

local function getPlayerEconomyState(player: Player): PlayerEconomyState
	local existingState = playerEconomies[player]
	if existingState ~= nil then
		return existingState
	end

	local newState = createEconomyState()
	playerEconomies[player] = newState
	return newState
end

local function buildSnapshot(state: PlayerEconomyState): EconomySnapshot
	return {
		cash = state.cash,
	}
end

local function pushEconomyUpdate(player: Player)
	local economyRemotes = Remotes.getEconomyRemotes()
	economyRemotes.economyUpdated:FireClient(player, buildSnapshot(getPlayerEconomyState(player)))
end

local function initializePlayer(player: Player)
	playerEconomies[player] = createEconomyState()
	pushEconomyUpdate(player)
end

local function cleanupPlayer(player: Player)
	playerEconomies[player] = nil
end

local EconomyService = {}

function EconomyService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local economyRemotes = Remotes.getEconomyRemotes()
	economyRemotes.getEconomySnapshot.OnServerInvoke = function(player: Player): EconomySnapshot
		return buildSnapshot(getPlayerEconomyState(player))
	end

	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(cleanupPlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		initializePlayer(player)
	end
end

function EconomyService.addCash(player: Player, amount: number)
	if amount <= 0 then
		return
	end

	local state = getPlayerEconomyState(player)
	state.cash += amount
	pushEconomyUpdate(player)
end

function EconomyService.getCash(player: Player): number
	return getPlayerEconomyState(player).cash
end

return table.freeze(EconomyService)

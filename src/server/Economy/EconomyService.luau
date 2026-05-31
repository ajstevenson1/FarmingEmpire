--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local economyFolder = sharedFolder:WaitForChild("Economy") :: Folder

local EconomyTypes = require(economyFolder:WaitForChild("EconomyTypes") :: ModuleScript)
local CashBoostService = require(script.Parent.Parent.Monetization.CashBoostService)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)
local Remotes = require(script.Parent.Parent.Networking.Remotes)

type EconomySnapshot = EconomyTypes.EconomySnapshot
type CashChangedListener = (Player, number) -> ()

local hasStarted = false
local cashChangedListeners: { CashChangedListener } = {}

local function buildSnapshot(player: Player): EconomySnapshot
	return {
		cash = PlayerDataService.getCash(player),
		lifetimeCashEarned = PlayerDataService.getLifetimeCashEarned(player),
	}
end

local function pushEconomyUpdate(player: Player)
	local economyRemotes = Remotes.getEconomyRemotes()
	economyRemotes.economyUpdated:FireClient(player, buildSnapshot(player))
end

local function notifyCashChanged(player: Player, cash: number)
	for _, listener in ipairs(cashChangedListeners) do
		local success, result = pcall(function()
			listener(player, cash)
		end)

		if not success then
			warn(string.format("Cash-changed listener failed for %s: %s", player.Name, tostring(result)))
		end
	end
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

	local newCash = PlayerDataService.getCash(player) + amount
	PlayerDataService.setCash(player, newCash)
	PlayerDataService.addLifetimeCashEarned(player, amount)
	pushEconomyUpdate(player)
	notifyCashChanged(player, newCash)
end

function EconomyService.addEarnedCash(player: Player, amount: number)
	if amount <= 0 then
		return
	end

	EconomyService.addCash(player, math.floor(amount * CashBoostService.getCashMultiplier(player)))
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

	local newCash = currentCash - amount
	PlayerDataService.setCash(player, newCash)
	pushEconomyUpdate(player)
	notifyCashChanged(player, newCash)
	return true
end

function EconomyService.getCash(player: Player): number
	return PlayerDataService.getCash(player)
end

function EconomyService.observeCashChanged(listener: CashChangedListener)
	table.insert(cashChangedListeners, listener)
end

return table.freeze(EconomyService)

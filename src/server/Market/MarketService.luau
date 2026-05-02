--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local economyFolder = sharedFolder:WaitForChild("Economy") :: Folder

local EconomyTypes = require(economyFolder:WaitForChild("EconomyTypes") :: ModuleScript)
local MarketConfig = require(economyFolder:WaitForChild("MarketConfig") :: ModuleScript)
local EconomyService = require(script.Parent.Parent.Economy.EconomyService)
local ResourceService = require(script.Parent.Parent.Resources.ResourceService)
local Remotes = require(script.Parent.Parent.Networking.Remotes)

type MarketSnapshot = EconomyTypes.MarketSnapshot

local randomGenerator = Random.new()
local hasStarted = false
local currentCiderSellPrice = 0
local nextPriceChangeAt = 0

local function getCurrentTime(): number
	return Workspace:GetServerTimeNow()
end

local function rollNextPrice(excludedPrice: number?): number
	local nextPrice = randomGenerator:NextInteger(MarketConfig.minCiderSellPrice, MarketConfig.maxCiderSellPrice)
	if excludedPrice ~= nil and MarketConfig.minCiderSellPrice < MarketConfig.maxCiderSellPrice then
		while nextPrice == excludedPrice do
			nextPrice = randomGenerator:NextInteger(MarketConfig.minCiderSellPrice, MarketConfig.maxCiderSellPrice)
		end
	end

	return nextPrice
end

local function buildSnapshot(): MarketSnapshot
	return {
		ciderSellPrice = currentCiderSellPrice,
		nextPriceChangeAt = nextPriceChangeAt,
	}
end

local function pushMarketUpdate()
	Remotes.getMarketRemotes().marketUpdated:FireAllClients(buildSnapshot())
end

local function setNextPrice()
	currentCiderSellPrice = rollNextPrice(currentCiderSellPrice)
	nextPriceChangeAt = getCurrentTime() + MarketConfig.priceChangeIntervalSeconds
	pushMarketUpdate()
end

local function handleSellAllCider(player: Player)
	local ciderToSell = ResourceService.getResourceAmount(player, "Cider")
	if ciderToSell <= 0 then
		return
	end

	if not ResourceService.tryConsumeResource(player, "Cider", ciderToSell) then
		return
	end

	EconomyService.addCash(player, ciderToSell * currentCiderSellPrice)
end

local function startPriceLoop()
	task.spawn(function()
		while true do
			local timeUntilNextChange = math.max(0, nextPriceChangeAt - getCurrentTime())
			task.wait(timeUntilNextChange)
			setNextPrice()
		end
	end)
end

local MarketService = {}

function MarketService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local marketRemotes = Remotes.getMarketRemotes()
	marketRemotes.getMarketSnapshot.OnServerInvoke = function(_player: Player): MarketSnapshot
		return buildSnapshot()
	end
	marketRemotes.sellAllCider.OnServerEvent:Connect(handleSellAllCider)

	currentCiderSellPrice = rollNextPrice(nil)
	nextPriceChangeAt = getCurrentTime() + MarketConfig.priceChangeIntervalSeconds
	pushMarketUpdate()
	startPriceLoop()
end

return table.freeze(MarketService)

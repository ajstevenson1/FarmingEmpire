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

local CIDER_SELL_MODEL_NAME = "CiderSell"
local TOUCH_PART_NAME = "Touch"
local MAX_SELL_DISTANCE_STUDS = 40

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

local function findCiderSellTouchPart(): BasePart?
	local model = Workspace:FindFirstChild(CIDER_SELL_MODEL_NAME)
	if model == nil then
		warn(string.format("[MarketService] Missing Workspace.%s.", CIDER_SELL_MODEL_NAME))
		return nil
	end

	local touchPart = model:FindFirstChild(TOUCH_PART_NAME)
	if touchPart == nil then
		warn(string.format("[MarketService] Missing %s.%s.", model:GetFullName(), TOUCH_PART_NAME))
		return nil
	end

	if not touchPart:IsA("BasePart") then
		warn(string.format("[MarketService] %s must be a BasePart.", touchPart:GetFullName()))
		return nil
	end

	return touchPart
end

local function isPlayerCloseEnoughToSell(player: Player): boolean
	local character = player.Character
	if character == nil then
		return false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return false
	end

	local touchPart = findCiderSellTouchPart()
	if touchPart == nil then
		return false
	end

	return (rootPart.Position - touchPart.Position).Magnitude <= MAX_SELL_DISTANCE_STUDS
end

local function handleSellAllCider(player: Player)
	if not isPlayerCloseEnoughToSell(player) then
		return
	end

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

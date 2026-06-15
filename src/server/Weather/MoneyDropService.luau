--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local formattingFolder = sharedFolder:WaitForChild("Formatting") :: Folder
local notificationsFolder = sharedFolder:WaitForChild("Notifications") :: Folder
local weatherFolder = sharedFolder:WaitForChild("Weather") :: Folder

local NotificationConfig = require(notificationsFolder:WaitForChild("NotificationConfig") :: ModuleScript)
local NotificationTypes = require(notificationsFolder:WaitForChild("NotificationTypes") :: ModuleScript)
local NumberFormatter = require(formattingFolder:WaitForChild("NumberFormatter") :: ModuleScript)
local WeatherTypes = require(weatherFolder:WaitForChild("WeatherTypes") :: ModuleScript)
local EconomyService = require(script.Parent.Parent.Economy.EconomyService)
local Remotes = require(script.Parent.Parent.Networking.Remotes)
local WeatherService = require(script.Parent.WeatherService)

type NotificationEffect = NotificationTypes.NotificationEffect
type NotificationPayload = NotificationTypes.NotificationPayload
type WeatherEventDefinition = WeatherTypes.WeatherEventDefinition
type WeatherMoneyDropConfig = WeatherTypes.WeatherMoneyDropConfig
type WeatherMoneyDropTierConfig = WeatherTypes.WeatherMoneyDropTierConfig
type MoneyDropSpawnPayload = WeatherTypes.MoneyDropSpawnPayload

type ActiveMoneyDrop = {
	id: string,
	tierId: string,
	rewardCash: number,
	spawnPosition: Vector3,
	expiresAt: number,
	serverValidationRadiusStuds: number,
}

local hasStarted = false
local randomGenerator = Random.new()
local activeConfig: WeatherMoneyDropConfig? = nil
local activeSessionId = 0
local activeDropsByPlayer: { [Player]: { [string]: ActiveMoneyDrop } } = {}

local function getCurrentTime(): number
	return Workspace:GetServerTimeNow()
end

local function sendPickupNotification(player: Player, rewardCash: number)
	local payload: NotificationPayload = {
		id = HttpService:GenerateGUID(false),
		kind = "Toast",
		text = string.format("You picked up $%s!", NumberFormatter.formatFull(rewardCash)),
		effect = "Instant" :: NotificationEffect,
		durationSeconds = NotificationConfig.toastDurationSeconds,
		variant = "Reward",
	}

	Remotes.getNotificationRemotes().notificationReceived:FireClient(player, payload)
end

local function getHumanoidRootPart(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil
	end

	return rootPart
end

local function getOrCreatePlayerDrops(player: Player): { [string]: ActiveMoneyDrop }
	local drops = activeDropsByPlayer[player]
	if drops ~= nil then
		return drops
	end

	drops = {}
	activeDropsByPlayer[player] = drops
	return drops
end

local function chooseTier(dropConfig: WeatherMoneyDropConfig): WeatherMoneyDropTierConfig?
	local totalWeight = 0
	for _, tier in ipairs(dropConfig.tiers) do
		if tier.weight > 0 then
			totalWeight += tier.weight
		end
	end

	if totalWeight <= 0 then
		return nil
	end

	local roll = randomGenerator:NextNumber(0, totalWeight)
	local cumulativeWeight = 0
	for _, tier in ipairs(dropConfig.tiers) do
		if tier.weight > 0 then
			cumulativeWeight += tier.weight
		end

		if roll <= cumulativeWeight then
			return tier
		end
	end

	return nil
end

local function getSpawnAreaPart(targetName: string): BasePart?
	local target = Workspace:FindFirstChild(targetName)
	if target == nil then
		warn(string.format("Money weather spawn target Workspace.%s was not found.", targetName))
		return nil
	end

	if not target:IsA("BasePart") then
		warn(string.format("Money weather spawn target Workspace.%s must be a BasePart.", targetName))
		return nil
	end

	return target
end

local function getRandomSpawnPosition(dropConfig: WeatherMoneyDropConfig): Vector3?
	local spawnAreaPart = getSpawnAreaPart(dropConfig.spawnAreaTargetName)
	if spawnAreaPart == nil then
		return nil
	end

	local spawnAreaScale = math.clamp(dropConfig.spawnAreaScale or 1, 0.01, 1)
	local halfSize = spawnAreaPart.Size * 0.5 * spawnAreaScale
	local localPosition = Vector3.new(
		randomGenerator:NextNumber(-halfSize.X, halfSize.X),
		halfSize.Y,
		randomGenerator:NextNumber(-halfSize.Z, halfSize.Z)
	)

	return spawnAreaPart.CFrame:PointToWorldSpace(localPosition)
end

local function resolveDrop(player: Player, dropId: string, reason: string, rewardCash: number?)
	local playerDrops = activeDropsByPlayer[player]
	if playerDrops ~= nil then
		playerDrops[dropId] = nil
	end

	if player.Parent == Players then
		Remotes.getWeatherRemotes().moneyDropResolved:FireClient(player, dropId, reason, rewardCash)
	end
end

local function clearPlayerDrops(player: Player, reason: string)
	local playerDrops = activeDropsByPlayer[player]
	if playerDrops == nil then
		return
	end

	local dropsToResolve: { ActiveMoneyDrop } = {}
	for _, drop in pairs(playerDrops) do
		table.insert(dropsToResolve, drop)
	end

	for _, drop in ipairs(dropsToResolve) do
		local dropId = drop.id
		resolveDrop(player, dropId, reason, drop.rewardCash)
	end

	activeDropsByPlayer[player] = nil
end

local function clearAllDrops(reason: string)
	local playersToClear: { Player } = {}
	for player in pairs(activeDropsByPlayer) do
		table.insert(playersToClear, player)
	end

	for _, player in ipairs(playersToClear) do
		clearPlayerDrops(player, reason)
	end
end

local function pruneExpiredDrops(currentTime: number)
	for player, playerDrops in pairs(activeDropsByPlayer) do
		local expiredDrops: { ActiveMoneyDrop } = {}
		for _, drop in pairs(playerDrops) do
			if currentTime >= drop.expiresAt then
				table.insert(expiredDrops, drop)
			end
		end

		for _, drop in ipairs(expiredDrops) do
			resolveDrop(player, drop.id, "Expired", drop.rewardCash)
		end

		if next(playerDrops) == nil then
			activeDropsByPlayer[player] = nil
		end
	end
end

local function createDropForPlayer(player: Player, dropConfig: WeatherMoneyDropConfig, currentTime: number)
	local tier = chooseTier(dropConfig)
	if tier == nil then
		return
	end

	local spawnPosition = getRandomSpawnPosition(dropConfig)
	if spawnPosition == nil then
		return
	end

	local dropId = HttpService:GenerateGUID(false)
	local expiresAt = currentTime + tier.lifetimeSeconds
	local activeDrop: ActiveMoneyDrop = {
		id = dropId,
		tierId = tier.id,
		rewardCash = tier.rewardCash,
		spawnPosition = spawnPosition,
		expiresAt = expiresAt,
		serverValidationRadiusStuds = dropConfig.serverValidationRadiusStuds,
	}

	getOrCreatePlayerDrops(player)[dropId] = activeDrop

	local payload: MoneyDropSpawnPayload = {
		id = dropId,
		tierId = tier.id,
		modelName = tier.modelName,
		rewardCash = tier.rewardCash,
		spawnPosition = spawnPosition,
		expiresAt = expiresAt,
		lifetimeSeconds = tier.lifetimeSeconds,
		fallSeconds = dropConfig.fallSeconds,
		collectionRadiusStuds = dropConfig.collectionRadiusStuds,
	}

	Remotes.getWeatherRemotes().moneyDropSpawned:FireClient(player, payload)
end

local function getHorizontalDistance(firstPosition: Vector3, secondPosition: Vector3): number
	local delta = firstPosition - secondPosition
	return Vector3.new(delta.X, 0, delta.Z).Magnitude
end

local function handlePickupRequest(player: Player, requestedDropId: unknown)
	if typeof(requestedDropId) ~= "string" then
		return
	end

	local playerDrops = activeDropsByPlayer[player]
	if playerDrops == nil then
		return
	end

	local drop = playerDrops[requestedDropId]
	if drop == nil then
		return
	end

	local currentTime = getCurrentTime()
	if currentTime >= drop.expiresAt then
		resolveDrop(player, drop.id, "Expired", drop.rewardCash)
		return
	end

	local rootPart = getHumanoidRootPart(player)
	if rootPart == nil then
		return
	end

	if getHorizontalDistance(rootPart.Position, drop.spawnPosition) > drop.serverValidationRadiusStuds then
		return
	end

	resolveDrop(player, drop.id, "Collected", drop.rewardCash)
	EconomyService.addCash(player, drop.rewardCash)
	sendPickupNotification(player, drop.rewardCash)
end

local function startSpawnLoop(sessionId: number)
	task.spawn(function()
		while activeSessionId == sessionId do
			local dropConfig = activeConfig
			if dropConfig == nil then
				return
			end

			local currentTime = getCurrentTime()
			pruneExpiredDrops(currentTime)

			for _, player in ipairs(Players:GetPlayers()) do
				createDropForPlayer(player, dropConfig, currentTime)
			end

			task.wait(dropConfig.spawnIntervalSeconds)
		end
	end)
end

local function handleActiveEventChanged(eventDefinition: WeatherEventDefinition?)
	activeSessionId += 1
	clearAllDrops("Cleared")

	local dropConfig = if eventDefinition ~= nil then eventDefinition.moneyDrops else nil
	activeConfig = dropConfig

	if dropConfig ~= nil then
		startSpawnLoop(activeSessionId)
	end
end

local MoneyDropService = {}

function MoneyDropService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local weatherRemotes = Remotes.getWeatherRemotes()
	weatherRemotes.requestMoneyDropPickup.OnServerEvent:Connect(handlePickupRequest)
	WeatherService.observeActiveEventChanged(handleActiveEventChanged)

	Players.PlayerRemoving:Connect(function(player: Player)
		clearPlayerDrops(player, "Cleared")
	end)
end

return table.freeze(MoneyDropService)

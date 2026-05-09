--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local leaderboardsFolder = sharedFolder:WaitForChild("Leaderboards") :: Folder

local CashLeaderboardConfig = require(leaderboardsFolder:WaitForChild("CashLeaderboardConfig") :: ModuleScript)
local LeaderboardTypes = require(leaderboardsFolder:WaitForChild("LeaderboardTypes") :: ModuleScript)
local EconomyService = require(script.Parent.Parent.Economy.EconomyService)
local CashLeaderboardRenderer = require(script.Parent.CashLeaderboardRenderer)
local CashLeaderboardStore = require(script.Parent.CashLeaderboardStore)

type CashLeaderboardEntry = LeaderboardTypes.CashLeaderboardEntry

local hasStarted = false
local pendingCashByUserId: { [number]: number } = {}
local latestCashByUserId: { [number]: number } = {}
local latestStoredEntries: { CashLeaderboardEntry } = {}

local function sanitizeCash(cash: number): number
	if cash ~= cash or cash == math.huge or cash == -math.huge or cash < 0 then
		return 0
	end

	return math.floor(cash)
end

local function queueCashWrite(userId: number, cash: number)
	local sanitizedCash = sanitizeCash(cash)
	latestCashByUserId[userId] = sanitizedCash
	pendingCashByUserId[userId] = sanitizedCash
end

local function flushQueuedCash()
	local cashToWrite: { [number]: number } = pendingCashByUserId
	pendingCashByUserId = {}

	for userId, cash in pairs(cashToWrite) do
		local didWrite = CashLeaderboardStore.setCashAsync(userId, cash)
		if not didWrite then
			pendingCashByUserId[userId] = cash
		end
	end
end

local function getOnlineEntry(player: Player): CashLeaderboardEntry?
	local latestCash = latestCashByUserId[player.UserId]
	if latestCash == nil then
		local success, cashOrError = pcall(function(): number
			return EconomyService.getCash(player)
		end)

		if not success then
			warn(string.format("Failed to read online cash for %s: %s", player.Name, tostring(cashOrError)))
			return nil
		end

		latestCash = sanitizeCash(cashOrError :: number)
		latestCashByUserId[player.UserId] = latestCash
	end

	return {
		userId = player.UserId,
		playerName = player.Name,
		cash = latestCash,
	}
end

local function mergeWithOnlinePlayers(storedEntries: { CashLeaderboardEntry }): { CashLeaderboardEntry }
	local entriesByUserId: { [number]: CashLeaderboardEntry } = {}
	for _, entry in ipairs(storedEntries) do
		entriesByUserId[entry.userId] = entry
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local onlineEntry = getOnlineEntry(player)
		if onlineEntry ~= nil then
			entriesByUserId[player.UserId] = onlineEntry
		end
	end

	local entries: { CashLeaderboardEntry } = {}
	for _, entry in pairs(entriesByUserId) do
		table.insert(entries, entry)
	end

	table.sort(entries, function(leftEntry: CashLeaderboardEntry, rightEntry: CashLeaderboardEntry): boolean
		if leftEntry.cash == rightEntry.cash then
			return leftEntry.playerName < rightEntry.playerName
		end

		return leftEntry.cash > rightEntry.cash
	end)

	while #entries > CashLeaderboardConfig.entriesToDisplay do
		table.remove(entries)
	end

	return entries
end

local function renderBoard()
	local entries = mergeWithOnlinePlayers(latestStoredEntries)
	CashLeaderboardRenderer.render(entries, os.time())
end

local function refreshStoredEntries()
	latestStoredEntries = CashLeaderboardStore.getTopCashAsync(CashLeaderboardConfig.entriesToDisplay)
	renderBoard()
end

local function initializePlayer(player: Player)
	local success, cashOrError = pcall(function(): number
		return EconomyService.getCash(player)
	end)

	if success then
		queueCashWrite(player.UserId, cashOrError :: number)
		renderBoard()
	else
		warn(string.format("Failed to initialize cash leaderboard entry for %s: %s", player.Name, tostring(cashOrError)))
	end
end

local function removePlayer(player: Player)
	local latestCash = latestCashByUserId[player.UserId]
	if latestCash ~= nil then
		queueCashWrite(player.UserId, latestCash)
		CashLeaderboardStore.setCashAsync(player.UserId, latestCash)
	end

	latestCashByUserId[player.UserId] = nil
end

local function startWriteLoop()
	task.spawn(function()
		while true do
			task.wait(CashLeaderboardConfig.writeFlushIntervalSeconds)
			flushQueuedCash()
		end
	end)
end

local function startRefreshLoop()
	task.spawn(function()
		while true do
			refreshStoredEntries()
			task.wait(CashLeaderboardConfig.refreshIntervalSeconds)
		end
	end)
end

local CashLeaderboardService = {}

function CashLeaderboardService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	EconomyService.observeCashChanged(function(player: Player, cash: number)
		queueCashWrite(player.UserId, cash)
		renderBoard()
	end)

	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(removePlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(initializePlayer, player)
	end

	startWriteLoop()
	startRefreshLoop()
end

return table.freeze(CashLeaderboardService)

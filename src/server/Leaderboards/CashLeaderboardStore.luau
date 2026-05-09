--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local leaderboardsFolder = sharedFolder:WaitForChild("Leaderboards") :: Folder

local CashLeaderboardConfig = require(leaderboardsFolder:WaitForChild("CashLeaderboardConfig") :: ModuleScript)
local LeaderboardTypes = require(leaderboardsFolder:WaitForChild("LeaderboardTypes") :: ModuleScript)

type CashLeaderboardEntry = LeaderboardTypes.CashLeaderboardEntry

local orderedDataStore = DataStoreService:GetOrderedDataStore(CashLeaderboardConfig.orderedDataStoreName)
local playerNamesByUserId: { [number]: string } = {}

local function sanitizeCash(cash: number): number
	if cash ~= cash or cash == math.huge or cash == -math.huge or cash < 0 then
		return 0
	end

	return math.floor(cash)
end

local function getPlayerName(userId: number): string
	local cachedName = playerNamesByUserId[userId]
	if cachedName ~= nil then
		return cachedName
	end

	local onlinePlayer = Players:GetPlayerByUserId(userId)
	if onlinePlayer ~= nil then
		playerNamesByUserId[userId] = onlinePlayer.Name
		return onlinePlayer.Name
	end

	local success, result = pcall(function(): string
		return Players:GetNameFromUserIdAsync(userId)
	end)

	if success then
		local playerName = result :: string
		playerNamesByUserId[userId] = playerName
		return playerName
	end

	warn(string.format("Failed to resolve leaderboard name for userId %d: %s", userId, tostring(result)))
	return `Player {userId}`
end

local CashLeaderboardStore = {}

function CashLeaderboardStore.setCashAsync(userId: number, cash: number): boolean
	local sanitizedCash = sanitizeCash(cash)
	local success, result = pcall(function()
		orderedDataStore:SetAsync(tostring(userId), sanitizedCash)
	end)

	if not success then
		warn(string.format("Failed to update cash leaderboard for userId %d: %s", userId, tostring(result)))
		return false
	end

	return true
end

function CashLeaderboardStore.getTopCashAsync(limit: number): { CashLeaderboardEntry }
	local success, pagesOrError = pcall(function()
		return orderedDataStore:GetSortedAsync(false, limit)
	end)

	if not success then
		warn(string.format("Failed to load cash leaderboard: %s", tostring(pagesOrError)))
		return {}
	end

	local entries: { CashLeaderboardEntry } = {}
	local pages = pagesOrError :: DataStorePages
	local currentPage = pages:GetCurrentPage()
	for _, item in ipairs(currentPage) do
		local userId = tonumber(item.key)
		local cash = item.value
		if userId ~= nil and type(cash) == "number" then
			table.insert(entries, {
				userId = userId,
				playerName = getPlayerName(userId),
				cash = sanitizeCash(cash),
			})
		end
	end

	return entries
end

return table.freeze(CashLeaderboardStore)

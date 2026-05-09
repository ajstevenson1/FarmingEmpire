--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local leaderboardsFolder = sharedFolder:WaitForChild("Leaderboards") :: Folder

local LeaderboardTypes = require(leaderboardsFolder:WaitForChild("LeaderboardTypes") :: ModuleScript)

type NumberLeaderboardEntry = LeaderboardTypes.NumberLeaderboardEntry

export type NumberLeaderboardStore = {
	getValueAsync: (self: NumberLeaderboardStore, userId: number) -> number,
	incrementValueAsync: (self: NumberLeaderboardStore, userId: number, amount: number) -> number?,
	getTopValuesAsync: (self: NumberLeaderboardStore, limit: number) -> { NumberLeaderboardEntry },
}

local playerNamesByUserId: { [number]: string } = {}

local function sanitizeValue(value: number): number
	if value ~= value or value == math.huge or value == -math.huge or value < 0 then
		return 0
	end

	return math.floor(value)
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

local Store = {}
Store.__index = Store

function Store:getValueAsync(userId: number): number
	local success, result = pcall(function(): unknown
		return self._orderedDataStore:GetAsync(tostring(userId))
	end)

	if not success then
		warn(string.format("[%s] Failed to load value for userId %d: %s", self._warningPrefix, userId, tostring(result)))
		return 0
	end

	if type(result) ~= "number" then
		return 0
	end

	return sanitizeValue(result)
end

function Store:incrementValueAsync(userId: number, amount: number): number?
	local sanitizedAmount = sanitizeValue(amount)
	if sanitizedAmount <= 0 then
		return nil
	end

	local success, result = pcall(function(): unknown
		return self._orderedDataStore:IncrementAsync(tostring(userId), sanitizedAmount)
	end)

	if not success then
		warn(string.format("[%s] Failed to increment value for userId %d: %s", self._warningPrefix, userId, tostring(result)))
		return nil
	end

	if type(result) ~= "number" then
		return nil
	end

	return sanitizeValue(result)
end

function Store:getTopValuesAsync(limit: number): { NumberLeaderboardEntry }
	local success, pagesOrError = pcall(function()
		return self._orderedDataStore:GetSortedAsync(false, limit)
	end)

	if not success then
		warn(string.format("[%s] Failed to load leaderboard: %s", self._warningPrefix, tostring(pagesOrError)))
		return {}
	end

	local entries: { NumberLeaderboardEntry } = {}
	local pages = pagesOrError :: DataStorePages
	local currentPage = pages:GetCurrentPage()
	for _, item in ipairs(currentPage) do
		local userId = tonumber(item.key)
		local value = item.value
		if userId ~= nil and type(value) == "number" then
			table.insert(entries, {
				userId = userId,
				playerName = getPlayerName(userId),
				value = sanitizeValue(value),
			})
		end
	end

	return entries
end

local NumberLeaderboardStoreFactory = {}

function NumberLeaderboardStoreFactory.create(orderedDataStoreName: string, warningPrefix: string): NumberLeaderboardStore
	return setmetatable({
		_orderedDataStore = DataStoreService:GetOrderedDataStore(orderedDataStoreName),
		_warningPrefix = warningPrefix,
	}, Store) :: NumberLeaderboardStore
end

return table.freeze(NumberLeaderboardStoreFactory)

--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local leaderboardsFolder = sharedFolder:WaitForChild("Leaderboards") :: Folder

local LeaderboardTypes = require(leaderboardsFolder:WaitForChild("LeaderboardTypes") :: ModuleScript)
local TimeSpentLeaderboardConfig = require(leaderboardsFolder:WaitForChild("TimeSpentLeaderboardConfig") :: ModuleScript)

type TimeSpentLeaderboardEntry = LeaderboardTypes.TimeSpentLeaderboardEntry

local orderedDataStore = DataStoreService:GetOrderedDataStore(TimeSpentLeaderboardConfig.orderedDataStoreName)
local playerNamesByUserId: { [number]: string } = {}

local function sanitizeSeconds(seconds: number): number
	if seconds ~= seconds or seconds == math.huge or seconds == -math.huge or seconds < 0 then
		return 0
	end

	return math.floor(seconds)
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

	warn(string.format("Failed to resolve time leaderboard name for userId %d: %s", userId, tostring(result)))
	return `Player {userId}`
end

local TimeSpentLeaderboardStore = {}

function TimeSpentLeaderboardStore.getSecondsAsync(userId: number): number
	local success, result = pcall(function(): unknown
		return orderedDataStore:GetAsync(tostring(userId))
	end)

	if not success then
		warn(string.format("Failed to load time spent for userId %d: %s", userId, tostring(result)))
		return 0
	end

	if type(result) ~= "number" then
		return 0
	end

	return sanitizeSeconds(result)
end

function TimeSpentLeaderboardStore.setSecondsAsync(userId: number, totalSeconds: number): boolean
	local sanitizedSeconds = sanitizeSeconds(totalSeconds)
	local success, result = pcall(function()
		orderedDataStore:SetAsync(tostring(userId), sanitizedSeconds)
	end)

	if not success then
		warn(string.format("Failed to update time spent leaderboard for userId %d: %s", userId, tostring(result)))
		return false
	end

	return true
end

function TimeSpentLeaderboardStore.getTopSecondsAsync(limit: number): { TimeSpentLeaderboardEntry }
	local success, pagesOrError = pcall(function()
		return orderedDataStore:GetSortedAsync(false, limit)
	end)

	if not success then
		warn(string.format("Failed to load time spent leaderboard: %s", tostring(pagesOrError)))
		return {}
	end

	local entries: { TimeSpentLeaderboardEntry } = {}
	local pages = pagesOrError :: DataStorePages
	local currentPage = pages:GetCurrentPage()
	for _, item in ipairs(currentPage) do
		local userId = tonumber(item.key)
		local totalSeconds = item.value
		if userId ~= nil and type(totalSeconds) == "number" then
			table.insert(entries, {
				userId = userId,
				playerName = getPlayerName(userId),
				totalSeconds = sanitizeSeconds(totalSeconds),
			})
		end
	end

	return entries
end

return table.freeze(TimeSpentLeaderboardStore)

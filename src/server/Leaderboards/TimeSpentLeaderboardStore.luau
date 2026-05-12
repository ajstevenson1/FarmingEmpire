--!strict

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local leaderboardsFolder = sharedFolder:WaitForChild("Leaderboards") :: Folder

local LeaderboardTypes = require(leaderboardsFolder:WaitForChild("LeaderboardTypes") :: ModuleScript)
local LeaderboardIdentityResolver = require(script.Parent.LeaderboardIdentityResolver)
local TimeSpentLeaderboardConfig = require(leaderboardsFolder:WaitForChild("TimeSpentLeaderboardConfig") :: ModuleScript)

type TimeSpentLeaderboardEntry = LeaderboardTypes.TimeSpentLeaderboardEntry

local orderedDataStore = DataStoreService:GetOrderedDataStore(TimeSpentLeaderboardConfig.orderedDataStoreName)
local MAX_TOP_FETCH_COUNT = 100
local TOP_FETCH_MULTIPLIER = 3

local function sanitizeSeconds(seconds: number): number
	if seconds ~= seconds or seconds == math.huge or seconds == -math.huge or seconds < 0 then
		return 0
	end

	return math.floor(seconds)
end

local function getPlayerName(userId: number): string
	return LeaderboardIdentityResolver.getPlayerName(userId, "Failed to resolve time leaderboard name")
end

local TimeSpentLeaderboardStore = {}

function TimeSpentLeaderboardStore.getSecondsAsync(userId: number): number
	if not LeaderboardIdentityResolver.shouldPersistUserId(userId) then
		return 0
	end

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
	if not LeaderboardIdentityResolver.shouldPersistUserId(userId) then
		return true
	end

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
	local requestedLimit = math.max(0, math.floor(limit))
	if requestedLimit <= 0 then
		return {}
	end

	local fetchCount = math.min(MAX_TOP_FETCH_COUNT, math.max(requestedLimit, requestedLimit * TOP_FETCH_MULTIPLIER))
	local success, pagesOrError = pcall(function()
		return orderedDataStore:GetSortedAsync(false, fetchCount)
	end)

	if not success then
		warn(string.format("Failed to load time spent leaderboard: %s", tostring(pagesOrError)))
		return {}
	end

	local entries: { TimeSpentLeaderboardEntry } = {}
	local pages = pagesOrError :: DataStorePages
	while true do
		local currentPage = pages:GetCurrentPage()
		for _, item in ipairs(currentPage) do
			local userId = tonumber(item.key)
			local totalSeconds = item.value
			if userId ~= nil and LeaderboardIdentityResolver.shouldPersistUserId(userId) and type(totalSeconds) == "number" then
				table.insert(entries, {
					userId = userId,
					playerName = getPlayerName(userId),
					totalSeconds = sanitizeSeconds(totalSeconds),
				})
				if #entries >= requestedLimit then
					return entries
				end
			end
		end

		if pages.IsFinished then
			break
		end

		local didAdvance, advanceError = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)
		if not didAdvance then
			warn(string.format("Failed to advance time spent leaderboard pages: %s", tostring(advanceError)))
			break
		end
	end

	return entries
end

return table.freeze(TimeSpentLeaderboardStore)

--!strict

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local leaderboardsFolder = sharedFolder:WaitForChild("Leaderboards") :: Folder

local CashLeaderboardConfig = require(leaderboardsFolder:WaitForChild("CashLeaderboardConfig") :: ModuleScript)
local LeaderboardTypes = require(leaderboardsFolder:WaitForChild("LeaderboardTypes") :: ModuleScript)
local LeaderboardIdentityResolver = require(script.Parent.LeaderboardIdentityResolver)

type CashLeaderboardEntry = LeaderboardTypes.CashLeaderboardEntry

local orderedDataStore = DataStoreService:GetOrderedDataStore(CashLeaderboardConfig.orderedDataStoreName)
local MAX_TOP_FETCH_COUNT = 100
local TOP_FETCH_MULTIPLIER = 3

local function sanitizeCash(cash: number): number
	if cash ~= cash or cash == math.huge or cash == -math.huge or cash < 0 then
		return 0
	end

	return math.floor(cash)
end

local function getPlayerName(userId: number): string
	return LeaderboardIdentityResolver.getPlayerName(userId, "Failed to resolve leaderboard name")
end

local CashLeaderboardStore = {}

function CashLeaderboardStore.setCashAsync(userId: number, cash: number): boolean
	if not LeaderboardIdentityResolver.shouldPersistUserId(userId) then
		return true
	end

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
	local requestedLimit = math.max(0, math.floor(limit))
	if requestedLimit <= 0 then
		return {}
	end

	local fetchCount = math.min(MAX_TOP_FETCH_COUNT, math.max(requestedLimit, requestedLimit * TOP_FETCH_MULTIPLIER))
	local success, pagesOrError = pcall(function()
		return orderedDataStore:GetSortedAsync(false, fetchCount)
	end)

	if not success then
		warn(string.format("Failed to load cash leaderboard: %s", tostring(pagesOrError)))
		return {}
	end

	local entries: { CashLeaderboardEntry } = {}
	local pages = pagesOrError :: DataStorePages
	while true do
		local currentPage = pages:GetCurrentPage()
		for _, item in ipairs(currentPage) do
			local userId = tonumber(item.key)
			local cash = item.value
			if userId ~= nil and LeaderboardIdentityResolver.shouldPersistUserId(userId) and type(cash) == "number" then
				table.insert(entries, {
					userId = userId,
					playerName = getPlayerName(userId),
					cash = sanitizeCash(cash),
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
			warn(string.format("Failed to advance cash leaderboard pages: %s", tostring(advanceError)))
			break
		end
	end

	return entries
end

return table.freeze(CashLeaderboardStore)

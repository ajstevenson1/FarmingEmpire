--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local leaderboardsFolder = sharedFolder:WaitForChild("Leaderboards") :: Folder

local LeaderboardTypes = require(leaderboardsFolder:WaitForChild("LeaderboardTypes") :: ModuleScript)
local TimeSpentLeaderboardConfig = require(leaderboardsFolder:WaitForChild("TimeSpentLeaderboardConfig") :: ModuleScript)
local TimeSpentLeaderboardRenderer = require(script.Parent.TimeSpentLeaderboardRenderer)
local TimeSpentLeaderboardStore = require(script.Parent.TimeSpentLeaderboardStore)

type TimeSpentLeaderboardEntry = LeaderboardTypes.TimeSpentLeaderboardEntry

type SessionRecord = {
	baseSeconds: number,
	joinUnix: number,
	playerName: string,
}

local hasStarted = false
local sessionRecordsByUserId: { [number]: SessionRecord } = {}
local pendingSecondsByUserId: { [number]: number } = {}
local latestStoredEntries: { TimeSpentLeaderboardEntry } = {}

local function sanitizeSeconds(seconds: number): number
	if seconds ~= seconds or seconds == math.huge or seconds == -math.huge or seconds < 0 then
		return 0
	end

	return math.floor(seconds)
end

local function getTotalSeconds(userId: number): number?
	local record = sessionRecordsByUserId[userId]
	if record == nil then
		return nil
	end

	return sanitizeSeconds(record.baseSeconds + (os.time() - record.joinUnix))
end

local function queueTimeWrite(userId: number, totalSeconds: number)
	pendingSecondsByUserId[userId] = sanitizeSeconds(totalSeconds)
end

local function flushQueuedSeconds()
	local secondsToWrite: { [number]: number } = pendingSecondsByUserId
	pendingSecondsByUserId = {}

	for userId, totalSeconds in pairs(secondsToWrite) do
		local didWrite = TimeSpentLeaderboardStore.setSecondsAsync(userId, totalSeconds)
		if not didWrite then
			pendingSecondsByUserId[userId] = totalSeconds
		end
	end
end

local function getOnlineEntry(player: Player): TimeSpentLeaderboardEntry?
	local totalSeconds = getTotalSeconds(player.UserId)
	if totalSeconds == nil then
		return nil
	end

	return {
		userId = player.UserId,
		playerName = player.Name,
		totalSeconds = totalSeconds,
	}
end

local function mergeWithOnlinePlayers(storedEntries: { TimeSpentLeaderboardEntry }): { TimeSpentLeaderboardEntry }
	local entriesByUserId: { [number]: TimeSpentLeaderboardEntry } = {}
	for _, entry in ipairs(storedEntries) do
		entriesByUserId[entry.userId] = entry
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local onlineEntry = getOnlineEntry(player)
		if onlineEntry ~= nil then
			entriesByUserId[player.UserId] = onlineEntry
		end
	end

	local entries: { TimeSpentLeaderboardEntry } = {}
	for _, entry in pairs(entriesByUserId) do
		table.insert(entries, entry)
	end

	table.sort(entries, function(leftEntry: TimeSpentLeaderboardEntry, rightEntry: TimeSpentLeaderboardEntry): boolean
		if leftEntry.totalSeconds == rightEntry.totalSeconds then
			return leftEntry.playerName < rightEntry.playerName
		end

		return leftEntry.totalSeconds > rightEntry.totalSeconds
	end)

	while #entries > TimeSpentLeaderboardConfig.entriesToDisplay do
		table.remove(entries)
	end

	return entries
end

local function renderBoard()
	TimeSpentLeaderboardRenderer.render(mergeWithOnlinePlayers(latestStoredEntries), os.time())
end

local function refreshStoredEntries()
	latestStoredEntries = TimeSpentLeaderboardStore.getTopSecondsAsync(TimeSpentLeaderboardConfig.entriesToDisplay)
	renderBoard()
end

local function initializePlayer(player: Player)
	local baseSeconds = TimeSpentLeaderboardStore.getSecondsAsync(player.UserId)
	sessionRecordsByUserId[player.UserId] = {
		baseSeconds = baseSeconds,
		joinUnix = os.time(),
		playerName = player.Name,
	}

	queueTimeWrite(player.UserId, baseSeconds)
	renderBoard()
end

local function removePlayer(player: Player)
	local totalSeconds = getTotalSeconds(player.UserId)
	if totalSeconds ~= nil then
		queueTimeWrite(player.UserId, totalSeconds)
		TimeSpentLeaderboardStore.setSecondsAsync(player.UserId, totalSeconds)
	end

	sessionRecordsByUserId[player.UserId] = nil
end

local function queueOnlinePlayerTimes()
	for _, player in ipairs(Players:GetPlayers()) do
		local totalSeconds = getTotalSeconds(player.UserId)
		if totalSeconds ~= nil then
			queueTimeWrite(player.UserId, totalSeconds)
		end
	end
end

local function startWriteLoop()
	task.spawn(function()
		while true do
			task.wait(TimeSpentLeaderboardConfig.writeFlushIntervalSeconds)
			queueOnlinePlayerTimes()
			flushQueuedSeconds()
		end
	end)
end

local function startRefreshLoop()
	task.spawn(function()
		while true do
			refreshStoredEntries()
			task.wait(TimeSpentLeaderboardConfig.refreshIntervalSeconds)
		end
	end)
end

local TimeSpentLeaderboardService = {}

function TimeSpentLeaderboardService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(removePlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(initializePlayer, player)
	end

	startWriteLoop()
	startRefreshLoop()
end

return table.freeze(TimeSpentLeaderboardService)

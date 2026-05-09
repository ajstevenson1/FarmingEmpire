--!strict

local Players = game:GetService("Players")

local NumberLeaderboardRendererFactory = require(script.Parent.NumberLeaderboardRendererFactory)
local NumberLeaderboardStoreFactory = require(script.Parent.NumberLeaderboardStoreFactory)

type NumberLeaderboardEntry = {
	userId: number,
	playerName: string,
	value: number,
}

type NumberLeaderboardConfig = NumberLeaderboardRendererFactory.NumberLeaderboardConfig & {
	orderedDataStoreName: string,
	writeFlushIntervalSeconds: number,
}

export type AccumulatingLeaderboardService = {
	start: (self: AccumulatingLeaderboardService) -> (),
	recordAmount: (self: AccumulatingLeaderboardService, player: Player, amount: number) -> (),
}

local Service = {}
Service.__index = Service

local function sanitizeAmount(amount: number): number
	if amount ~= amount or amount == math.huge or amount == -math.huge or amount < 0 then
		return 0
	end

	return math.floor(amount)
end

function Service:_queueIncrement(userId: number, amount: number)
	local sanitizedAmount = sanitizeAmount(amount)
	if sanitizedAmount <= 0 then
		return
	end

	self._pendingIncrementsByUserId[userId] = (self._pendingIncrementsByUserId[userId] or 0) + sanitizedAmount
	if self._latestValuesByUserId[userId] == nil then
		self._latestValuesByUserId[userId] = self._store:getValueAsync(userId)
	end

	self._latestValuesByUserId[userId] += sanitizedAmount
end

function Service:_flushQueuedIncrements()
	local incrementsToWrite: { [number]: number } = self._pendingIncrementsByUserId
	self._pendingIncrementsByUserId = {}

	for userId, amount in pairs(incrementsToWrite) do
		local updatedValue = self._store:incrementValueAsync(userId, amount)
		if updatedValue == nil then
			self._pendingIncrementsByUserId[userId] = amount
		else
			self._latestValuesByUserId[userId] = updatedValue
		end
	end
end

function Service:_getOnlineEntry(player: Player): NumberLeaderboardEntry?
	local latestValue = self._latestValuesByUserId[player.UserId]
	if latestValue == nil then
		latestValue = self._store:getValueAsync(player.UserId)
		self._latestValuesByUserId[player.UserId] = latestValue
	end

	return {
		userId = player.UserId,
		playerName = player.Name,
		value = latestValue,
	}
end

function Service:_mergeWithOnlinePlayers(storedEntries: { NumberLeaderboardEntry }): { NumberLeaderboardEntry }
	local entriesByUserId: { [number]: NumberLeaderboardEntry } = {}
	for _, entry in ipairs(storedEntries) do
		entriesByUserId[entry.userId] = entry
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local onlineEntry = self:_getOnlineEntry(player)
		if onlineEntry ~= nil then
			entriesByUserId[player.UserId] = onlineEntry
		end
	end

	local entries: { NumberLeaderboardEntry } = {}
	for _, entry in pairs(entriesByUserId) do
		table.insert(entries, entry)
	end

	table.sort(entries, function(leftEntry: NumberLeaderboardEntry, rightEntry: NumberLeaderboardEntry): boolean
		if leftEntry.value == rightEntry.value then
			return leftEntry.playerName < rightEntry.playerName
		end

		return leftEntry.value > rightEntry.value
	end)

	while #entries > self._config.entriesToDisplay do
		table.remove(entries)
	end

	return entries
end

function Service:_renderBoard()
	self._renderer:render(self:_mergeWithOnlinePlayers(self._latestStoredEntries), os.time())
end

function Service:_refreshStoredEntries()
	self._latestStoredEntries = self._store:getTopValuesAsync(self._config.entriesToDisplay)
	self:_renderBoard()
end

function Service:_initializePlayer(player: Player)
	self._latestValuesByUserId[player.UserId] = self._store:getValueAsync(player.UserId)
	self:_renderBoard()
end

function Service:_removePlayer(player: Player)
	self:_flushQueuedIncrements()
	self._latestValuesByUserId[player.UserId] = nil
end

function Service:_startWriteLoop()
	task.spawn(function()
		while true do
			task.wait(self._config.writeFlushIntervalSeconds)
			self:_flushQueuedIncrements()
		end
	end)
end

function Service:_startRefreshLoop()
	task.spawn(function()
		while true do
			self:_refreshStoredEntries()
			task.wait(self._config.refreshIntervalSeconds)
		end
	end)
end

function Service:start()
	if self._hasStarted then
		return
	end

	self._hasStarted = true

	Players.PlayerAdded:Connect(function(player: Player)
		self:_initializePlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self:_removePlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:_initializePlayer(player)
		end)
	end

	self:_startWriteLoop()
	self:_startRefreshLoop()
end

function Service:recordAmount(player: Player, amount: number)
	self:_queueIncrement(player.UserId, amount)
	self:_renderBoard()
end

local AccumulatingLeaderboardServiceFactory = {}

function AccumulatingLeaderboardServiceFactory.create(
	config: NumberLeaderboardConfig,
	warningPrefix: string,
	scorePrefix: string,
	emptyText: string
): AccumulatingLeaderboardService
	return setmetatable({
		_config = config,
		_store = NumberLeaderboardStoreFactory.create(config.orderedDataStoreName, warningPrefix),
		_renderer = NumberLeaderboardRendererFactory.create(config, scorePrefix, emptyText),
		_pendingIncrementsByUserId = {},
		_latestValuesByUserId = {},
		_latestStoredEntries = {},
		_hasStarted = false,
	}, Service) :: AccumulatingLeaderboardService
end

return table.freeze(AccumulatingLeaderboardServiceFactory)

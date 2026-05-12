--!strict

local Players = game:GetService("Players")

local TEST_PLAYER_NAME_PREFIX = "Test Player"

local cachedNamesByUserId: { [number]: string } = {}

local function buildTestPlayerName(userId: number): string
	local normalizedUserId = math.abs(math.floor(userId))
	if normalizedUserId == 0 then
		return TEST_PLAYER_NAME_PREFIX
	end

	return string.format("%s %d", TEST_PLAYER_NAME_PREFIX, normalizedUserId)
end

local LeaderboardIdentityResolver = {}

function LeaderboardIdentityResolver.shouldPersistUserId(userId: number): boolean
	return userId > 0
end

function LeaderboardIdentityResolver.getPlayerName(userId: number, warningMessagePrefix: string): string
	local cachedName = cachedNamesByUserId[userId]
	if cachedName ~= nil then
		return cachedName
	end

	local onlinePlayer = Players:GetPlayerByUserId(userId)
	if onlinePlayer ~= nil then
		cachedNamesByUserId[userId] = onlinePlayer.Name
		return onlinePlayer.Name
	end

	if not LeaderboardIdentityResolver.shouldPersistUserId(userId) then
		local testPlayerName = buildTestPlayerName(userId)
		cachedNamesByUserId[userId] = testPlayerName
		return testPlayerName
	end

	local success, result = pcall(function(): string
		return Players:GetNameFromUserIdAsync(userId)
	end)

	if success then
		local playerName = result :: string
		cachedNamesByUserId[userId] = playerName
		return playerName
	end

	warn(string.format("%s for userId %d: %s", warningMessagePrefix, userId, tostring(result)))
	return string.format("Player %d", userId)
end

return table.freeze(LeaderboardIdentityResolver)

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local playtimeRewardsFolder = sharedFolder:WaitForChild("PlaytimeRewards") :: Folder

local DailyRewardsConfig = require(playtimeRewardsFolder:WaitForChild("DailyRewardsConfig") :: ModuleScript)
local PlaytimeRewardsConfig = require(playtimeRewardsFolder:WaitForChild("PlaytimeRewardsConfig") :: ModuleScript)
local PlaytimeRewardsTypes = require(playtimeRewardsFolder:WaitForChild("PlaytimeRewardsTypes") :: ModuleScript)
local EconomyService = require(script.Parent.Parent.Economy.EconomyService)
local InventoryService = require(script.Parent.Parent.Inventory.InventoryService)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)
local Remotes = require(script.Parent.Parent.Networking.Remotes)
local ResourceService = require(script.Parent.Parent.Resources.ResourceService)

type DailyRewardDefinition = PlaytimeRewardsTypes.DailyRewardDefinition
type DailyRewardSnapshot = PlaytimeRewardsTypes.DailyRewardSnapshot
type DailyRewardsSnapshot = PlaytimeRewardsTypes.DailyRewardsSnapshot
type PlayerDailyRewardsData = PlaytimeRewardsTypes.PlayerDailyRewardsData
type PlayerPlaytimeRewardsData = PlaytimeRewardsTypes.PlayerPlaytimeRewardsData
type PlaytimeRewardDefinition = PlaytimeRewardsTypes.PlaytimeRewardDefinition
type PlaytimeRewardEntry = PlaytimeRewardsTypes.PlaytimeRewardEntry
type PlaytimeRewardSnapshot = PlaytimeRewardsTypes.PlaytimeRewardSnapshot
type PlaytimeRewardState = PlaytimeRewardsTypes.PlaytimeRewardState
type PlaytimeRewardsClaimResult = PlaytimeRewardsTypes.PlaytimeRewardsClaimResult
type PlaytimeRewardsClaimStatus = PlaytimeRewardsTypes.PlaytimeRewardsClaimStatus
type PlaytimeRewardsSnapshot = PlaytimeRewardsTypes.PlaytimeRewardsSnapshot
type RewardCategory = PlaytimeRewardsTypes.RewardCategory
type RewardsSnapshot = PlaytimeRewardsTypes.RewardsSnapshot

local hasStarted = false
local claimInProgressByPlayer: { [Player]: boolean } = {}
local sessionStartTimesByPlayer: { [Player]: number } = {}

local function getCurrentUnixTime(): number
	return Workspace:GetServerTimeNow()
end

local function sanitizeDuration(duration: number): number
	if duration ~= duration or duration == math.huge or duration == -math.huge or duration < 0 then
		return 0
	end

	return duration
end

local function sanitizeAmount(amount: number): number
	if amount ~= amount or amount == math.huge or amount == -math.huge or amount < 0 then
		return 0
	end

	return math.floor(amount)
end

local function cloneRewardEntry(rewardEntry: PlaytimeRewardEntry): PlaytimeRewardEntry
	if rewardEntry.kind == "Cash" then
		return {
			kind = "Cash",
			amount = rewardEntry.amount,
			imageAssetId = rewardEntry.imageAssetId or "",
		}
	elseif rewardEntry.kind == "Resource" then
		return {
			kind = "Resource",
			resourceId = rewardEntry.resourceId,
			amount = rewardEntry.amount,
			imageAssetId = rewardEntry.imageAssetId or "",
		}
	end

	return {
		kind = "Item",
		itemId = rewardEntry.itemId,
		amount = rewardEntry.amount,
		imageAssetId = rewardEntry.imageAssetId or "",
	}
end

local function cloneRewardEntries(rewardEntries: { PlaytimeRewardEntry }): { PlaytimeRewardEntry }
	local clone: { PlaytimeRewardEntry } = table.create(#rewardEntries)
	for _, rewardEntry in ipairs(rewardEntries) do
		table.insert(clone, cloneRewardEntry(rewardEntry))
	end
	return clone
end

local function clonePlaytimeRewardDefinition(definition: PlaytimeRewardDefinition): PlaytimeRewardDefinition
	return {
		rewardIndex = definition.rewardIndex,
		displayName = definition.displayName,
		requiredPlaytimeSeconds = definition.requiredPlaytimeSeconds,
		rewards = cloneRewardEntries(definition.rewards),
	}
end

local function cloneDailyRewardDefinition(definition: DailyRewardDefinition): DailyRewardDefinition
	return {
		rewardIndex = definition.rewardIndex,
		displayName = definition.displayName,
		rewards = cloneRewardEntries(definition.rewards),
	}
end

local function sanitizePlaytimeData(progressData: PlayerPlaytimeRewardsData): PlayerPlaytimeRewardsData
	local claimedRewardIndexes: { [number]: boolean } = {}
	for rewardIndex, isClaimed in pairs(progressData.claimedRewardIndexes) do
		if isClaimed and PlaytimeRewardsConfig.isRewardIndexInRange(rewardIndex) then
			claimedRewardIndexes[rewardIndex] = true
		end
	end

	return {
		accumulatedPlaytimeSeconds = sanitizeDuration(progressData.accumulatedPlaytimeSeconds),
		claimedRewardIndexes = claimedRewardIndexes,
		totalClaims = sanitizeAmount(progressData.totalClaims),
	}
end

local function sanitizeDailyData(dailyData: PlayerDailyRewardsData): PlayerDailyRewardsData
	local claimedRewardIndexes: { [number]: boolean } = {}
	for rewardIndex, isClaimed in pairs(dailyData.claimedRewardIndexes) do
		if isClaimed and DailyRewardsConfig.isRewardIndexInRange(rewardIndex) then
			claimedRewardIndexes[rewardIndex] = true
		end
	end

	return {
		claimedRewardIndexes = claimedRewardIndexes,
		lastClaimUnixTime = sanitizeDuration(dailyData.lastClaimUnixTime),
		nextRewardIndex = DailyRewardsConfig.sanitizeRewardIndex(dailyData.nextRewardIndex),
		totalClaims = sanitizeAmount(dailyData.totalClaims),
	}
end

local function cloneClaimedPlaytimeRewardIndexes(claimedRewardIndexes: { [number]: boolean }): { [number]: boolean }
	local clone: { [number]: boolean } = {}
	for rewardIndex, isClaimed in pairs(claimedRewardIndexes) do
		if isClaimed and PlaytimeRewardsConfig.isRewardIndexInRange(rewardIndex) then
			clone[rewardIndex] = true
		end
	end

	return clone
end

local function cloneClaimedDailyRewardIndexes(claimedRewardIndexes: { [number]: boolean }): { [number]: boolean }
	local clone: { [number]: boolean } = {}
	for rewardIndex, isClaimed in pairs(claimedRewardIndexes) do
		if isClaimed and DailyRewardsConfig.isRewardIndexInRange(rewardIndex) then
			clone[rewardIndex] = true
		end
	end

	return clone
end

local function areAllDailyRewardsClaimed(dailyData: PlayerDailyRewardsData): boolean
	for rewardIndex = 1, DailyRewardsConfig.getCycleLength() do
		if dailyData.claimedRewardIndexes[rewardIndex] ~= true then
			return false
		end
	end

	return true
end

local function getCurrentPlaytimeSeconds(player: Player, progressData: PlayerPlaytimeRewardsData): number
	local sessionStartTime = sessionStartTimesByPlayer[player]
	if sessionStartTime == nil then
		return progressData.accumulatedPlaytimeSeconds
	end

	return progressData.accumulatedPlaytimeSeconds + math.max(0, getCurrentUnixTime() - sessionStartTime)
end

local function buildPersistedPlaytimeData(player: Player, progressData: PlayerPlaytimeRewardsData): PlayerPlaytimeRewardsData
	return {
		accumulatedPlaytimeSeconds = getCurrentPlaytimeSeconds(player, progressData),
		claimedRewardIndexes = cloneClaimedPlaytimeRewardIndexes(progressData.claimedRewardIndexes),
		totalClaims = progressData.totalClaims,
	}
end

local function persistCurrentPlaytime(player: Player): PlayerPlaytimeRewardsData
	local progressData = sanitizePlaytimeData(PlayerDataService.getPlaytimeRewardsData(player))
	local updatedProgressData = buildPersistedPlaytimeData(player, progressData)
	sessionStartTimesByPlayer[player] = getCurrentUnixTime()
	PlayerDataService.setPlaytimeRewardsData(player, updatedProgressData)
	return updatedProgressData
end

local function getPlaytimeClaimableRewardIndex(progressData: PlayerPlaytimeRewardsData, currentPlaytimeSeconds: number): number?
	for _, definition in ipairs(PlaytimeRewardsConfig.getRewardDefinitions()) do
		if progressData.claimedRewardIndexes[definition.rewardIndex] ~= true
			and currentPlaytimeSeconds >= definition.requiredPlaytimeSeconds
		then
			return definition.rewardIndex
		end
	end

	return nil
end

local function getDailySecondsRemaining(dailyData: PlayerDailyRewardsData, now: number): number
	if dailyData.lastClaimUnixTime <= 0 then
		return 0
	end

	return math.max(0, math.ceil((dailyData.lastClaimUnixTime + DailyRewardsConfig.getCooldownSeconds()) - now))
end

local function getDailyClaimableRewardIndex(dailyData: PlayerDailyRewardsData, now: number): number?
	if getDailySecondsRemaining(dailyData, now) > 0 then
		return nil
	end

	return dailyData.nextRewardIndex
end

local function getPlaytimeRewardState(rewardIndex: number, requiredPlaytimeSeconds: number, progressData: PlayerPlaytimeRewardsData, currentPlaytimeSeconds: number): PlaytimeRewardState
	if progressData.claimedRewardIndexes[rewardIndex] == true then
		return "Claimed"
	end

	if currentPlaytimeSeconds >= requiredPlaytimeSeconds then
		return "Claimable"
	end

	return "Locked"
end

local function getDailyRewardState(rewardIndex: number, dailyData: PlayerDailyRewardsData, now: number): PlaytimeRewardState
	if dailyData.claimedRewardIndexes[rewardIndex] == true then
		return "Claimed"
	end

	if getDailyClaimableRewardIndex(dailyData, now) == rewardIndex then
		return "Claimable"
	end

	return "Locked"
end

local function buildPlaytimeRewardSnapshots(progressData: PlayerPlaytimeRewardsData, currentPlaytimeSeconds: number): { PlaytimeRewardSnapshot }
	local rewardSnapshots: { PlaytimeRewardSnapshot } = {}

	for _, definition in ipairs(PlaytimeRewardsConfig.getRewardDefinitions()) do
		local secondsRemaining = math.max(0, math.ceil(definition.requiredPlaytimeSeconds - currentPlaytimeSeconds))
		table.insert(rewardSnapshots, {
			rewardIndex = definition.rewardIndex,
			displayName = definition.displayName,
			requiredPlaytimeSeconds = definition.requiredPlaytimeSeconds,
			rewards = cloneRewardEntries(definition.rewards),
			secondsRemaining = secondsRemaining,
			state = getPlaytimeRewardState(definition.rewardIndex, definition.requiredPlaytimeSeconds, progressData, currentPlaytimeSeconds),
		})
	end

	return rewardSnapshots
end

local function buildDailyRewardSnapshots(dailyData: PlayerDailyRewardsData, now: number): { DailyRewardSnapshot }
	local rewardSnapshots: { DailyRewardSnapshot } = {}
	local dailySecondsRemaining = getDailySecondsRemaining(dailyData, now)

	for _, definition in ipairs(DailyRewardsConfig.getRewardDefinitions()) do
		local state = getDailyRewardState(definition.rewardIndex, dailyData, now)
		table.insert(rewardSnapshots, {
			rewardIndex = definition.rewardIndex,
			displayName = definition.displayName,
			rewards = cloneRewardEntries(definition.rewards),
			secondsRemaining = if state == "Locked" and definition.rewardIndex == dailyData.nextRewardIndex then dailySecondsRemaining else 0,
			state = state,
		})
	end

	return rewardSnapshots
end

local function getNextPlaytimeRewardSecondsRemaining(progressData: PlayerPlaytimeRewardsData, currentPlaytimeSeconds: number): number?
	local lowestSecondsRemaining: number? = nil
	for _, definition in ipairs(PlaytimeRewardsConfig.getRewardDefinitions()) do
		if progressData.claimedRewardIndexes[definition.rewardIndex] ~= true then
			local secondsRemaining = math.max(0, math.ceil(definition.requiredPlaytimeSeconds - currentPlaytimeSeconds))
			if lowestSecondsRemaining == nil or secondsRemaining < lowestSecondsRemaining then
				lowestSecondsRemaining = secondsRemaining
			end
		end
	end

	return lowestSecondsRemaining
end

local function buildPlaytimeSnapshot(player: Player, progressData: PlayerPlaytimeRewardsData): PlaytimeRewardsSnapshot
	local sanitizedProgressData = sanitizePlaytimeData(progressData)
	local currentPlaytimeSeconds = getCurrentPlaytimeSeconds(player, sanitizedProgressData)

	return {
		canClaim = getPlaytimeClaimableRewardIndex(sanitizedProgressData, currentPlaytimeSeconds) ~= nil,
		claimableRewardIndex = getPlaytimeClaimableRewardIndex(sanitizedProgressData, currentPlaytimeSeconds),
		currentPlaytimeSeconds = currentPlaytimeSeconds,
		cycleLength = PlaytimeRewardsConfig.getCycleLength(),
		rewardSnapshots = buildPlaytimeRewardSnapshots(sanitizedProgressData, currentPlaytimeSeconds),
		nextRewardSecondsRemaining = getNextPlaytimeRewardSecondsRemaining(sanitizedProgressData, currentPlaytimeSeconds),
		snapshotServerTime = getCurrentUnixTime(),
		totalClaims = sanitizedProgressData.totalClaims,
	}
end

local function buildDailySnapshot(dailyData: PlayerDailyRewardsData): DailyRewardsSnapshot
	local sanitizedDailyData = sanitizeDailyData(dailyData)
	local now = getCurrentUnixTime()
	local dailySecondsRemaining = getDailySecondsRemaining(sanitizedDailyData, now)
	if dailySecondsRemaining <= 0 and areAllDailyRewardsClaimed(sanitizedDailyData) then
		sanitizedDailyData.claimedRewardIndexes = {}
	end

	local claimableRewardIndex = getDailyClaimableRewardIndex(sanitizedDailyData, now)

	return {
		canClaim = claimableRewardIndex ~= nil,
		claimableRewardIndex = claimableRewardIndex,
		cycleLength = DailyRewardsConfig.getCycleLength(),
		nextRewardSecondsRemaining = if claimableRewardIndex == nil then dailySecondsRemaining else 0,
		rewardSnapshots = buildDailyRewardSnapshots(sanitizedDailyData, now),
		snapshotServerTime = now,
		totalClaims = sanitizedDailyData.totalClaims,
	}
end

local function buildRewardsSnapshot(player: Player): RewardsSnapshot
	return {
		playtime = buildPlaytimeSnapshot(player, PlayerDataService.getPlaytimeRewardsData(player)),
		daily = buildDailySnapshot(PlayerDataService.getDailyRewardsData(player)),
	}
end

local function pushSnapshot(player: Player)
	local playtimeRewardsRemotes = Remotes.getPlaytimeRewardsRemotes()
	playtimeRewardsRemotes.playtimeRewardsUpdated:FireClient(player, buildRewardsSnapshot(player))
end

local function initializePlayer(player: Player)
	PlayerDataService.waitForData(player)
	sessionStartTimesByPlayer[player] = getCurrentUnixTime()
	pushSnapshot(player)
end

local function cleanupPlayer(player: Player)
	claimInProgressByPlayer[player] = nil
	sessionStartTimesByPlayer[player] = nil
end

local function grantRewardEntries(player: Player, rewardEntries: { PlaytimeRewardEntry })
	for _, rewardEntry in ipairs(rewardEntries) do
		if rewardEntry.kind == "Cash" then
			EconomyService.addCash(player, rewardEntry.amount)
		elseif rewardEntry.kind == "Resource" then
			ResourceService.addResource(player, rewardEntry.resourceId, rewardEntry.amount)
		elseif rewardEntry.kind == "Item" then
			InventoryService.addItem(player, rewardEntry.itemId, rewardEntry.amount)
		end
	end
end

local function buildClaimResult(player: Player, status: PlaytimeRewardsClaimStatus, category: RewardCategory?, claimedRewardIndex: number?, grantedRewards: { PlaytimeRewardEntry }?): PlaytimeRewardsClaimResult
	return {
		success = status == "Claimed",
		status = status,
		snapshot = buildRewardsSnapshot(player),
		category = category,
		claimedRewardIndex = claimedRewardIndex,
		grantedRewards = grantedRewards,
	}
end

local function claimPlaytimeReward(player: Player): PlaytimeRewardsClaimResult
	local progressData = sanitizePlaytimeData(PlayerDataService.getPlaytimeRewardsData(player))
	local currentPlaytimeSeconds = getCurrentPlaytimeSeconds(player, progressData)
	local claimableRewardIndex = getPlaytimeClaimableRewardIndex(progressData, currentPlaytimeSeconds)
	if claimableRewardIndex == nil then
		return buildClaimResult(player, "AlreadyClaimed", "Playtime", nil, nil)
	end

	local rewardDefinition = clonePlaytimeRewardDefinition(PlaytimeRewardsConfig.getRewardDefinition(claimableRewardIndex))
	local claimedRewardIndexes = cloneClaimedPlaytimeRewardIndexes(progressData.claimedRewardIndexes)
	claimedRewardIndexes[claimableRewardIndex] = true

	local updatedProgressData: PlayerPlaytimeRewardsData = {
		accumulatedPlaytimeSeconds = currentPlaytimeSeconds,
		claimedRewardIndexes = claimedRewardIndexes,
		totalClaims = progressData.totalClaims + 1,
	}

	sessionStartTimesByPlayer[player] = getCurrentUnixTime()
	PlayerDataService.setPlaytimeRewardsData(player, updatedProgressData)
	grantRewardEntries(player, rewardDefinition.rewards)
	pushSnapshot(player)

	return buildClaimResult(player, "Claimed", "Playtime", claimableRewardIndex, rewardDefinition.rewards)
end

local function claimDailyReward(player: Player): PlaytimeRewardsClaimResult
	local dailyData = sanitizeDailyData(PlayerDataService.getDailyRewardsData(player))
	local now = getCurrentUnixTime()
	local claimableRewardIndex = getDailyClaimableRewardIndex(dailyData, now)
	if claimableRewardIndex == nil then
		return buildClaimResult(player, "AlreadyClaimed", "Daily", nil, nil)
	end

	local rewardDefinition = cloneDailyRewardDefinition(DailyRewardsConfig.getRewardDefinition(claimableRewardIndex))
	local claimedRewardIndexes: { [number]: boolean } = if areAllDailyRewardsClaimed(dailyData) then {} else cloneClaimedDailyRewardIndexes(dailyData.claimedRewardIndexes)
	claimedRewardIndexes[claimableRewardIndex] = true

	local updatedDailyData: PlayerDailyRewardsData = {
		claimedRewardIndexes = claimedRewardIndexes,
		lastClaimUnixTime = now,
		nextRewardIndex = DailyRewardsConfig.getNextRewardIndex(claimableRewardIndex),
		totalClaims = dailyData.totalClaims + 1,
	}

	PlayerDataService.setDailyRewardsData(player, updatedDailyData)
	grantRewardEntries(player, rewardDefinition.rewards)
	pushSnapshot(player)

	return buildClaimResult(player, "Claimed", "Daily", claimableRewardIndex, rewardDefinition.rewards)
end

local function claimReward(player: Player, category: unknown): PlaytimeRewardsClaimResult
	if claimInProgressByPlayer[player] == true then
		return buildClaimResult(player, "AlreadyClaimed", nil, nil, nil)
	end

	claimInProgressByPlayer[player] = true

	local success, result = pcall(function(): PlaytimeRewardsClaimResult
		if category == "Daily" then
			return claimDailyReward(player)
		end

		return claimPlaytimeReward(player)
	end)

	claimInProgressByPlayer[player] = nil

	if not success then
		warn(string.format("[PlaytimeRewardsService] Failed to claim reward for %s: %s", player.Name, tostring(result)))
		return buildClaimResult(player, "AlreadyClaimed", nil, nil, nil)
	end

	return result :: PlaytimeRewardsClaimResult
end

local function saveCurrentPlaytime(player: Player)
	if sessionStartTimesByPlayer[player] == nil then
		return
	end

	persistCurrentPlaytime(player)
end

local PlaytimeRewardsService = {}

function PlaytimeRewardsService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local playtimeRewardsRemotes = Remotes.getPlaytimeRewardsRemotes()
	playtimeRewardsRemotes.getPlaytimeRewardsSnapshot.OnServerInvoke = function(player: Player): RewardsSnapshot
		return buildRewardsSnapshot(player)
	end

	playtimeRewardsRemotes.claimPlaytimeReward.OnServerInvoke = function(player: Player, category: unknown): PlaytimeRewardsClaimResult
		return claimReward(player, category)
	end

	PlayerDataService.observeBeforeSave(saveCurrentPlaytime)
	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(cleanupPlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		initializePlayer(player)
	end
end

return table.freeze(PlaytimeRewardsService)

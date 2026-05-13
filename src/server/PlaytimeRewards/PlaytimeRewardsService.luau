--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local playtimeRewardsFolder = sharedFolder:WaitForChild("PlaytimeRewards") :: Folder

local PlaytimeRewardsConfig = require(playtimeRewardsFolder:WaitForChild("PlaytimeRewardsConfig") :: ModuleScript)
local PlaytimeRewardsTypes = require(playtimeRewardsFolder:WaitForChild("PlaytimeRewardsTypes") :: ModuleScript)
local EconomyService = require(script.Parent.Parent.Economy.EconomyService)
local InventoryService = require(script.Parent.Parent.Inventory.InventoryService)
local Remotes = require(script.Parent.Parent.Networking.Remotes)
local ResourceService = require(script.Parent.Parent.Resources.ResourceService)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)

type PlaytimeRewardDefinition = PlaytimeRewardsTypes.PlaytimeRewardDefinition
type PlaytimeRewardSnapshot = PlaytimeRewardsTypes.PlaytimeRewardSnapshot
type PlaytimeRewardState = PlaytimeRewardsTypes.PlaytimeRewardState
type PlaytimeRewardEntry = PlaytimeRewardsTypes.PlaytimeRewardEntry
type PlaytimeRewardsClaimResult = PlaytimeRewardsTypes.PlaytimeRewardsClaimResult
type PlaytimeRewardsClaimStatus = PlaytimeRewardsTypes.PlaytimeRewardsClaimStatus
type PlaytimeRewardsSnapshot = PlaytimeRewardsTypes.PlaytimeRewardsSnapshot
type PlayerPlaytimeRewardsData = PlaytimeRewardsTypes.PlayerPlaytimeRewardsData

local hasStarted = false
local claimInProgressByPlayer: { [Player]: boolean } = {}
local sessionStartTimesByPlayer: { [Player]: number } = {}

local function getCurrentUnixTime(): number
	return Workspace:GetServerTimeNow()
end

local function cloneRewardEntry(rewardEntry: PlaytimeRewardEntry): PlaytimeRewardEntry
	if rewardEntry.kind == "Cash" then
		return {
			kind = "Cash",
			amount = rewardEntry.amount,
		}
	elseif rewardEntry.kind == "Resource" then
		return {
			kind = "Resource",
			resourceId = rewardEntry.resourceId,
			amount = rewardEntry.amount,
		}
	end

	return {
		kind = "Item",
		itemId = rewardEntry.itemId,
		amount = rewardEntry.amount,
	}
end

local function cloneRewardEntries(rewardEntries: { PlaytimeRewardEntry }): { PlaytimeRewardEntry }
	local clone: { PlaytimeRewardEntry } = table.create(#rewardEntries)
	for _, rewardEntry in ipairs(rewardEntries) do
		table.insert(clone, cloneRewardEntry(rewardEntry))
	end
	return clone
end

local function cloneRewardDefinition(definition: PlaytimeRewardDefinition): PlaytimeRewardDefinition
	return {
		rewardIndex = definition.rewardIndex,
		displayName = definition.displayName,
		requiredPlaytimeSeconds = definition.requiredPlaytimeSeconds,
		rewards = cloneRewardEntries(definition.rewards),
	}
end

local function getCycleLength(): number
	return PlaytimeRewardsConfig.getCycleLength()
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

local function sanitizeProgressData(progressData: PlayerPlaytimeRewardsData): PlayerPlaytimeRewardsData
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

local function cloneClaimedRewardIndexes(claimedRewardIndexes: { [number]: boolean }): { [number]: boolean }
	local clone: { [number]: boolean } = {}
	for rewardIndex, isClaimed in pairs(claimedRewardIndexes) do
		if isClaimed and PlaytimeRewardsConfig.isRewardIndexInRange(rewardIndex) then
			clone[rewardIndex] = true
		end
	end

	return clone
end

local function getCurrentPlaytimeSeconds(player: Player, progressData: PlayerPlaytimeRewardsData): number
	local sessionStartTime = sessionStartTimesByPlayer[player]
	if sessionStartTime == nil then
		return progressData.accumulatedPlaytimeSeconds
	end

	return progressData.accumulatedPlaytimeSeconds + math.max(0, getCurrentUnixTime() - sessionStartTime)
end

local function buildPersistedProgressData(player: Player, progressData: PlayerPlaytimeRewardsData): PlayerPlaytimeRewardsData
	return {
		accumulatedPlaytimeSeconds = getCurrentPlaytimeSeconds(player, progressData),
		claimedRewardIndexes = cloneClaimedRewardIndexes(progressData.claimedRewardIndexes),
		totalClaims = progressData.totalClaims,
	}
end

local function persistCurrentPlaytime(player: Player): PlayerPlaytimeRewardsData
	local progressData = sanitizeProgressData(PlayerDataService.getPlaytimeRewardsData(player))
	local updatedProgressData = buildPersistedProgressData(player, progressData)
	sessionStartTimesByPlayer[player] = getCurrentUnixTime()
	PlayerDataService.setPlaytimeRewardsData(player, updatedProgressData)
	return updatedProgressData
end

local function getClaimableRewardIndex(progressData: PlayerPlaytimeRewardsData, currentPlaytimeSeconds: number): number?
	for _, definition in ipairs(PlaytimeRewardsConfig.getRewardDefinitions()) do
		if progressData.claimedRewardIndexes[definition.rewardIndex] ~= true
			and currentPlaytimeSeconds >= definition.requiredPlaytimeSeconds
		then
			return definition.rewardIndex
		end
	end

	return nil
end

local function canClaim(progressData: PlayerPlaytimeRewardsData, currentPlaytimeSeconds: number): boolean
	return getClaimableRewardIndex(progressData, currentPlaytimeSeconds) ~= nil
end

local function getNextRewardSecondsRemaining(progressData: PlayerPlaytimeRewardsData, currentPlaytimeSeconds: number): number?
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

local function getRewardState(rewardIndex: number, requiredPlaytimeSeconds: number, progressData: PlayerPlaytimeRewardsData, currentPlaytimeSeconds: number): PlaytimeRewardState
	if progressData.claimedRewardIndexes[rewardIndex] == true then
		return "Claimed"
	end

	if currentPlaytimeSeconds >= requiredPlaytimeSeconds then
		return "Claimable"
	end

	return "Locked"
end

local function buildRewardSnapshots(progressData: PlayerPlaytimeRewardsData, currentPlaytimeSeconds: number): { PlaytimeRewardSnapshot }
	local rewardSnapshots: { PlaytimeRewardSnapshot } = {}

	for _, definition in ipairs(PlaytimeRewardsConfig.getRewardDefinitions()) do
		local secondsRemaining = math.max(0, math.ceil(definition.requiredPlaytimeSeconds - currentPlaytimeSeconds))
		table.insert(rewardSnapshots, {
			rewardIndex = definition.rewardIndex,
			displayName = definition.displayName,
			requiredPlaytimeSeconds = definition.requiredPlaytimeSeconds,
			rewards = cloneRewardEntries(definition.rewards),
			secondsRemaining = secondsRemaining,
			state = getRewardState(definition.rewardIndex, definition.requiredPlaytimeSeconds, progressData, currentPlaytimeSeconds),
		})
	end

	return rewardSnapshots
end

local function buildSnapshotFromProgress(player: Player, progressData: PlayerPlaytimeRewardsData): PlaytimeRewardsSnapshot
	local sanitizedProgressData = sanitizeProgressData(progressData)
	local currentPlaytimeSeconds = getCurrentPlaytimeSeconds(player, sanitizedProgressData)

	return {
		canClaim = canClaim(sanitizedProgressData, currentPlaytimeSeconds),
		claimableRewardIndex = getClaimableRewardIndex(sanitizedProgressData, currentPlaytimeSeconds),
		currentPlaytimeSeconds = currentPlaytimeSeconds,
		cycleLength = getCycleLength(),
		rewardSnapshots = buildRewardSnapshots(sanitizedProgressData, currentPlaytimeSeconds),
		nextRewardSecondsRemaining = getNextRewardSecondsRemaining(sanitizedProgressData, currentPlaytimeSeconds),
		snapshotServerTime = getCurrentUnixTime(),
		totalClaims = sanitizedProgressData.totalClaims,
	}
end

local function pushSnapshot(player: Player)
	local playtimeRewardsRemotes = Remotes.getPlaytimeRewardsRemotes()
	playtimeRewardsRemotes.playtimeRewardsUpdated:FireClient(player, buildSnapshotFromProgress(player, PlayerDataService.getPlaytimeRewardsData(player)))
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

local function buildClaimResult(player: Player, progressData: PlayerPlaytimeRewardsData, status: PlaytimeRewardsClaimStatus, claimedRewardIndex: number?): PlaytimeRewardsClaimResult
	local grantedRewards: { PlaytimeRewardEntry }? = nil
	if claimedRewardIndex ~= nil then
		grantedRewards = cloneRewardEntries(PlaytimeRewardsConfig.getRewardDefinition(claimedRewardIndex).rewards)
	end

	return {
		success = status == "Claimed",
		status = status,
		snapshot = buildSnapshotFromProgress(player, progressData),
		claimedRewardIndex = claimedRewardIndex,
		grantedRewards = grantedRewards,
	}
end

local function claimReward(player: Player): PlaytimeRewardsClaimResult
	if claimInProgressByPlayer[player] == true then
		return buildClaimResult(player, PlayerDataService.getPlaytimeRewardsData(player), "AlreadyClaimed", nil)
	end

	claimInProgressByPlayer[player] = true

	local success, result = pcall(function(): PlaytimeRewardsClaimResult
		local progressData = sanitizeProgressData(PlayerDataService.getPlaytimeRewardsData(player))
		local currentPlaytimeSeconds = getCurrentPlaytimeSeconds(player, progressData)
		local claimableRewardIndex = getClaimableRewardIndex(progressData, currentPlaytimeSeconds)

		if claimableRewardIndex == nil then
			return buildClaimResult(player, progressData, "AlreadyClaimed", nil)
		end

		local rewardDefinition = cloneRewardDefinition(PlaytimeRewardsConfig.getRewardDefinition(claimableRewardIndex))
		grantRewardEntries(player, rewardDefinition.rewards)

		local claimedRewardIndexes = cloneClaimedRewardIndexes(progressData.claimedRewardIndexes)
		claimedRewardIndexes[claimableRewardIndex] = true
		local updatedProgressData: PlayerPlaytimeRewardsData = {
			accumulatedPlaytimeSeconds = currentPlaytimeSeconds,
			claimedRewardIndexes = claimedRewardIndexes,
			totalClaims = progressData.totalClaims + 1,
		}

		sessionStartTimesByPlayer[player] = getCurrentUnixTime()
		PlayerDataService.setPlaytimeRewardsData(player, updatedProgressData)
		pushSnapshot(player)

		return buildClaimResult(player, updatedProgressData, "Claimed", claimableRewardIndex)
	end)

	claimInProgressByPlayer[player] = nil

	if not success then
		warn(string.format("[PlaytimeRewardsService] Failed to claim reward for %s: %s", player.Name, tostring(result)))
		return buildClaimResult(player, PlayerDataService.getPlaytimeRewardsData(player), "AlreadyClaimed", nil)
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
	playtimeRewardsRemotes.getPlaytimeRewardsSnapshot.OnServerInvoke = function(player: Player): PlaytimeRewardsSnapshot
		return buildSnapshotFromProgress(player, PlayerDataService.getPlaytimeRewardsData(player))
	end

	playtimeRewardsRemotes.claimPlaytimeReward.OnServerInvoke = function(player: Player): PlaytimeRewardsClaimResult
		return claimReward(player)
	end

	PlayerDataService.observeBeforeSave(saveCurrentPlaytime)
	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(cleanupPlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		initializePlayer(player)
	end
end

return table.freeze(PlaytimeRewardsService)

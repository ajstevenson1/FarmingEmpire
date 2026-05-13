--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local dailyRewardsFolder = sharedFolder:WaitForChild("DailyRewards") :: Folder

local DailyRewardsConfig = require(dailyRewardsFolder:WaitForChild("DailyRewardsConfig") :: ModuleScript)
local DailyRewardsTypes = require(dailyRewardsFolder:WaitForChild("DailyRewardsTypes") :: ModuleScript)
local EconomyService = require(script.Parent.Parent.Economy.EconomyService)
local InventoryService = require(script.Parent.Parent.Inventory.InventoryService)
local Remotes = require(script.Parent.Parent.Networking.Remotes)
local ResourceService = require(script.Parent.Parent.Resources.ResourceService)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)

type DailyRewardDefinition = DailyRewardsTypes.DailyRewardDefinition
type DailyRewardDaySnapshot = DailyRewardsTypes.DailyRewardDaySnapshot
type DailyRewardDayState = DailyRewardsTypes.DailyRewardDayState
type DailyRewardEntry = DailyRewardsTypes.DailyRewardEntry
type DailyRewardsClaimResult = DailyRewardsTypes.DailyRewardsClaimResult
type DailyRewardsClaimStatus = DailyRewardsTypes.DailyRewardsClaimStatus
type DailyRewardsSnapshot = DailyRewardsTypes.DailyRewardsSnapshot
type PlayerDailyRewardsData = DailyRewardsTypes.PlayerDailyRewardsData

local hasStarted = false
local claimInProgressByPlayer: { [Player]: boolean } = {}

local function getCurrentUnixTime(): number
	return Workspace:GetServerTimeNow()
end

local function cloneRewardEntry(rewardEntry: DailyRewardEntry): DailyRewardEntry
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

local function cloneRewardEntries(rewardEntries: { DailyRewardEntry }): { DailyRewardEntry }
	local clone: { DailyRewardEntry } = table.create(#rewardEntries)
	for _, rewardEntry in ipairs(rewardEntries) do
		table.insert(clone, cloneRewardEntry(rewardEntry))
	end
	return clone
end

local function cloneRewardDefinition(definition: DailyRewardDefinition): DailyRewardDefinition
	return {
		dayIndex = definition.dayIndex,
		displayName = definition.displayName,
		rewards = cloneRewardEntries(definition.rewards),
	}
end

local function getCycleLength(): number
	return DailyRewardsConfig.getCycleLength()
end

local function sanitizeProgressData(progressData: PlayerDailyRewardsData): PlayerDailyRewardsData
	return {
		lastClaimPeriodId = progressData.lastClaimPeriodId,
		nextDayIndex = DailyRewardsConfig.sanitizeDayIndex(progressData.nextDayIndex),
		totalClaims = math.max(0, math.floor(progressData.totalClaims)),
	}
end

local function getPreviousDayIndex(dayIndex: number): number
	local cycleLength = getCycleLength()
	if dayIndex <= 1 then
		return cycleLength
	end

	return dayIndex - 1
end

local function getCurrentPeriodId(): number
	return DailyRewardsConfig.getPeriodIdAtTime(getCurrentUnixTime())
end

local function getNextClaimTime(currentPeriodId: number): number
	return DailyRewardsConfig.getNextPeriodStartTime(currentPeriodId)
end

local function hasMissedReset(progressData: PlayerDailyRewardsData, currentPeriodId: number): boolean
	local lastClaimPeriodId = progressData.lastClaimPeriodId
	if lastClaimPeriodId == nil then
		return false
	end

	return currentPeriodId > lastClaimPeriodId + 1
end

local function canClaim(progressData: PlayerDailyRewardsData, currentPeriodId: number): boolean
	local lastClaimPeriodId = progressData.lastClaimPeriodId
	if lastClaimPeriodId == nil then
		return true
	end

	return currentPeriodId > lastClaimPeriodId
end

local function getClaimableDayIndex(progressData: PlayerDailyRewardsData, currentPeriodId: number): number?
	if not canClaim(progressData, currentPeriodId) then
		return nil
	end

	if hasMissedReset(progressData, currentPeriodId) then
		return 1
	end

	return DailyRewardsConfig.sanitizeDayIndex(progressData.nextDayIndex)
end

local function getClaimedTodayDayIndex(progressData: PlayerDailyRewardsData, currentPeriodId: number): number?
	local lastClaimPeriodId = progressData.lastClaimPeriodId
	if lastClaimPeriodId == nil or currentPeriodId ~= lastClaimPeriodId then
		return nil
	end

	return getPreviousDayIndex(DailyRewardsConfig.sanitizeDayIndex(progressData.nextDayIndex))
end

local function getSecondsUntilNextClaim(currentPeriodId: number): number
	return math.max(0, math.ceil(getNextClaimTime(currentPeriodId) - getCurrentUnixTime()))
end

local function getDayState(dayIndex: number, claimableDayIndex: number?, claimedTodayDayIndex: number?): DailyRewardDayState
	if claimedTodayDayIndex ~= nil then
		if dayIndex <= claimedTodayDayIndex then
			return "Claimed"
		end

		return "Locked"
	end

	if claimableDayIndex == nil then
		return "Locked"
	end

	if dayIndex < claimableDayIndex then
		return "Claimed"
	end

	if dayIndex == claimableDayIndex then
		return "Claimable"
	end

	return "Locked"
end

local function buildDaysSnapshot(progressData: PlayerDailyRewardsData, currentPeriodId: number): { DailyRewardDaySnapshot }
	local claimableDayIndex = getClaimableDayIndex(progressData, currentPeriodId)
	local claimedTodayDayIndex = getClaimedTodayDayIndex(progressData, currentPeriodId)
	local days: { DailyRewardDaySnapshot } = {}

	for _, definition in ipairs(DailyRewardsConfig.getRewardDefinitions()) do
		table.insert(days, {
			dayIndex = definition.dayIndex,
			displayName = definition.displayName,
			rewards = cloneRewardEntries(definition.rewards),
			state = getDayState(definition.dayIndex, claimableDayIndex, claimedTodayDayIndex),
		})
	end

	return days
end

local function buildSnapshotFromProgress(progressData: PlayerDailyRewardsData): DailyRewardsSnapshot
	local sanitizedProgressData = sanitizeProgressData(progressData)
	local currentPeriodId = getCurrentPeriodId()

	return {
		canClaim = canClaim(sanitizedProgressData, currentPeriodId),
		claimableDayIndex = getClaimableDayIndex(sanitizedProgressData, currentPeriodId),
		claimedTodayDayIndex = getClaimedTodayDayIndex(sanitizedProgressData, currentPeriodId),
		currentPeriodId = currentPeriodId,
		cycleLength = getCycleLength(),
		days = buildDaysSnapshot(sanitizedProgressData, currentPeriodId),
		lastClaimPeriodId = sanitizedProgressData.lastClaimPeriodId,
		nextClaimTime = getNextClaimTime(currentPeriodId),
		secondsUntilNextClaim = getSecondsUntilNextClaim(currentPeriodId),
		totalClaims = sanitizedProgressData.totalClaims,
	}
end

local function pushSnapshot(player: Player)
	local dailyRewardsRemotes = Remotes.getDailyRewardsRemotes()
	dailyRewardsRemotes.dailyRewardsUpdated:FireClient(player, buildSnapshotFromProgress(PlayerDataService.getDailyRewardsData(player)))
end

local function initializePlayer(player: Player)
	PlayerDataService.waitForData(player)
	pushSnapshot(player)
end

local function cleanupPlayer(player: Player)
	claimInProgressByPlayer[player] = nil
end

local function grantRewardEntries(player: Player, rewardEntries: { DailyRewardEntry })
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

local function buildClaimResult(progressData: PlayerDailyRewardsData, status: DailyRewardsClaimStatus, claimedDayIndex: number?): DailyRewardsClaimResult
	local grantedRewards: { DailyRewardEntry }? = nil
	if claimedDayIndex ~= nil then
		grantedRewards = cloneRewardEntries(DailyRewardsConfig.getRewardDefinition(claimedDayIndex).rewards)
	end

	return {
		success = status == "Claimed",
		status = status,
		snapshot = buildSnapshotFromProgress(progressData),
		claimedDayIndex = claimedDayIndex,
		grantedRewards = grantedRewards,
	}
end

local function claimReward(player: Player): DailyRewardsClaimResult
	if claimInProgressByPlayer[player] == true then
		return buildClaimResult(PlayerDataService.getDailyRewardsData(player), "AlreadyClaimed", nil)
	end

	claimInProgressByPlayer[player] = true

	local success, result = pcall(function(): DailyRewardsClaimResult
		local progressData = sanitizeProgressData(PlayerDataService.getDailyRewardsData(player))
		local currentPeriodId = getCurrentPeriodId()
		local claimableDayIndex = getClaimableDayIndex(progressData, currentPeriodId)

		if claimableDayIndex == nil then
			return buildClaimResult(progressData, "AlreadyClaimed", nil)
		end

		local rewardDefinition = cloneRewardDefinition(DailyRewardsConfig.getRewardDefinition(claimableDayIndex))
		grantRewardEntries(player, rewardDefinition.rewards)

		local updatedProgressData: PlayerDailyRewardsData = {
			lastClaimPeriodId = currentPeriodId,
			nextDayIndex = DailyRewardsConfig.getNextDayIndex(claimableDayIndex),
			totalClaims = progressData.totalClaims + 1,
		}

		PlayerDataService.setDailyRewardsData(player, updatedProgressData)
		pushSnapshot(player)

		return buildClaimResult(updatedProgressData, "Claimed", claimableDayIndex)
	end)

	claimInProgressByPlayer[player] = nil

	if not success then
		warn(string.format("[DailyRewardsService] Failed to claim reward for %s: %s", player.Name, tostring(result)))
		return buildClaimResult(PlayerDataService.getDailyRewardsData(player), "AlreadyClaimed", nil)
	end

	return result :: DailyRewardsClaimResult
end

local DailyRewardsService = {}

function DailyRewardsService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local dailyRewardsRemotes = Remotes.getDailyRewardsRemotes()
	dailyRewardsRemotes.getDailyRewardsSnapshot.OnServerInvoke = function(player: Player): DailyRewardsSnapshot
		return buildSnapshotFromProgress(PlayerDataService.getDailyRewardsData(player))
	end

	dailyRewardsRemotes.claimDailyReward.OnServerInvoke = function(player: Player): DailyRewardsClaimResult
		return claimReward(player)
	end

	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(cleanupPlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		initializePlayer(player)
	end
end

return table.freeze(DailyRewardsService)

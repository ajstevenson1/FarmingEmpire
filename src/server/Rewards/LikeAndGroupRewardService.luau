--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local notificationsFolder = sharedFolder:WaitForChild("Notifications") :: Folder
local promoRewardsFolder = sharedFolder:WaitForChild("PromoRewards") :: Folder

local NotificationConfig = require(notificationsFolder:WaitForChild("NotificationConfig") :: ModuleScript)
local NotificationTypes = require(notificationsFolder:WaitForChild("NotificationTypes") :: ModuleScript)
local LikeAndGroupRewardConfig = require(promoRewardsFolder:WaitForChild("LikeAndGroupRewardConfig") :: ModuleScript)
local InventoryService = require(script.Parent.Parent.Inventory.InventoryService)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)
local Remotes = require(script.Parent.Parent.Networking.Remotes)

type NotificationVariant = NotificationTypes.NotificationVariant
type PromoRewardEntry = LikeAndGroupRewardConfig.PromoRewardEntry

local LikeAndGroupRewardService = {}

local hasStarted = false
local didWarnMissingGroupId = false
local nextAllowedTouchAtByPlayer: { [Player]: number } = {}
local claimInProgressByPlayer: { [Player]: boolean } = {}

local function getCurrentTime(): number
	return Workspace:GetServerTimeNow()
end

local function findPlayerFromTouchedPart(touchedPart: BasePart): Player?
	local current: Instance? = touchedPart
	while current ~= nil and current ~= Workspace do
		if current:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(current)
			if player ~= nil then
				return player
			end
		end

		current = current.Parent
	end

	return nil
end

local function findTouchPart(): BasePart?
	local plate = Workspace:FindFirstChild(LikeAndGroupRewardConfig.plateName)
	if plate == nil then
		warn(string.format("[LikeAndGroupRewardService] Missing Workspace.%s.", LikeAndGroupRewardConfig.plateName))
		return nil
	end

	local touchPart = plate:FindFirstChild(LikeAndGroupRewardConfig.touchPartName, true)
	if touchPart == nil then
		warn(string.format(
			"[LikeAndGroupRewardService] Missing %s.%s.",
			plate:GetFullName(),
			LikeAndGroupRewardConfig.touchPartName
		))
		return nil
	end

	if not touchPart:IsA("BasePart") then
		warn(string.format("[LikeAndGroupRewardService] %s must be a BasePart.", touchPart:GetFullName()))
		return nil
	end

	return touchPart
end

local function canHandleTouch(player: Player, currentTime: number): boolean
	local nextAllowedTouchAt = nextAllowedTouchAtByPlayer[player] or 0
	if currentTime < nextAllowedTouchAt then
		return false
	end

	nextAllowedTouchAtByPlayer[player] = currentTime + LikeAndGroupRewardConfig.touchCooldownSeconds
	return true
end

local function sendNotification(player: Player, text: string, variant: NotificationVariant)
	Remotes.getNotificationRemotes().notificationReceived:FireClient(player, {
		id = HttpService:GenerateGUID(false),
		kind = "Toast",
		text = text,
		effect = "Instant",
		durationSeconds = NotificationConfig.toastDurationSeconds,
		variant = variant,
	})
end

local function getRewardGroupId(): number?
	if LikeAndGroupRewardConfig.groupId > 0 then
		return LikeAndGroupRewardConfig.groupId
	end

	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
		return game.CreatorId
	end

	if not didWarnMissingGroupId then
		didWarnMissingGroupId = true
		warn("[LikeAndGroupRewardService] LikeAndGroupRewardConfig.groupId must be set because this experience is not group-owned.")
	end

	return nil
end

local function isPlayerInGroup(player: Player, groupId: number): boolean
	local didCheckGroup, isInGroup = pcall(function(): boolean
		return player:IsInGroup(groupId)
	end)

	if not didCheckGroup then
		warn(string.format("[LikeAndGroupRewardService] Failed to check group membership for %s.", player.Name))
		return false
	end

	return isInGroup == true
end

local function grantRewards(player: Player, rewards: { PromoRewardEntry })
	for _, reward in ipairs(rewards) do
		InventoryService.addItem(player, reward.itemId, reward.quantity)
	end
end

local function handleClaimForPlayer(player: Player)
	if PlayerDataService.hasClaimedOneTimeReward(player, LikeAndGroupRewardConfig.rewardId) then
		sendNotification(player, LikeAndGroupRewardConfig.notifications.alreadyClaimed, "Info")
		return
	end

	local groupId = getRewardGroupId()
	if groupId == nil then
		sendNotification(player, LikeAndGroupRewardConfig.notifications.unavailable, "Error")
		return
	end

	if not isPlayerInGroup(player, groupId) then
		sendNotification(player, LikeAndGroupRewardConfig.notifications.notInGroup, "Error")
		return
	end

	if not PlayerDataService.markOneTimeRewardClaimed(player, LikeAndGroupRewardConfig.rewardId) then
		sendNotification(player, LikeAndGroupRewardConfig.notifications.alreadyClaimed, "Info")
		return
	end

	grantRewards(player, LikeAndGroupRewardConfig.rewards)
	sendNotification(player, LikeAndGroupRewardConfig.notifications.success, "Reward")
end

local function processTouchForPlayer(player: Player)
	if claimInProgressByPlayer[player] == true then
		return
	end

	if not canHandleTouch(player, getCurrentTime()) then
		return
	end

	claimInProgressByPlayer[player] = true
	local didHandle, result = pcall(function()
		handleClaimForPlayer(player)
	end)
	claimInProgressByPlayer[player] = nil

	if not didHandle then
		warn(string.format("[LikeAndGroupRewardService] Failed to process reward touch for %s: %s", player.Name, tostring(result)))
	end
end

function LikeAndGroupRewardService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local touchPart = findTouchPart()
	if touchPart == nil then
		return
	end

	touchPart.Touched:Connect(function(touchedPart: BasePart)
		local player = findPlayerFromTouchedPart(touchedPart)
		if player == nil then
			return
		end

		processTouchForPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		nextAllowedTouchAtByPlayer[player] = nil
		claimInProgressByPlayer[player] = nil
	end)
end

return table.freeze(LikeAndGroupRewardService)

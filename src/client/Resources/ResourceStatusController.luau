--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local economyFolder = sharedFolder:WaitForChild("Economy") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local EconomyTypes = require(economyFolder:WaitForChild("EconomyTypes") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)
local ResourceGainToastView = require(script.Parent.ResourceGainToastView)
local ResourceGainSoundPlayer = require(script.Parent.ResourceGainSoundPlayer)
local ResourceStatusView = require(script.Parent.ResourceStatusView)
local RewardClaimEffects = require(script.Parent.Parent.PlaytimeRewards.RewardClaimEffects)

type EconomySnapshot = EconomyTypes.EconomySnapshot
type ResourceSnapshot = ResourceTypes.ResourceSnapshot
type ResourceUpdateContext = ResourceTypes.ResourceUpdateContext
type ResourceGainSoundPlayerInstance = ResourceGainSoundPlayer.ResourceGainSoundPlayer
type ResourceGainToastViewInstance = ResourceGainToastView.ResourceGainToastView
type ResourceStatusViewInstance = ResourceStatusView.ResourceStatusView

local hasStarted = false
local latestEconomySnapshot: EconomySnapshot? = nil
local latestResourceSnapshot: ResourceSnapshot? = nil
local pendingAppleGain = 0
local pendingAppleFlushToken = 0

local APPLE_GAIN_FALLBACK_FLUSH_DELAY_SECONDS = 0.12
local OFFLINE_EARNINGS_CLAIM_REASON: ResourceTypes.ResourceUpdateReason = "OfflineEarningsClaim"

local function getRootGui(): ScreenGui
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before using ResourceStatusController")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild("GUI")
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")
	return rootGui
end

local function getResourceRemotes(): (RemoteEvent, RemoteFunction)
	local remotesFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local resourcesRemoteFolder = remotesFolder:WaitForChild(RemoteNames.resourcesFolderName) :: Folder
	local resourceUpdated = resourcesRemoteFolder:WaitForChild(RemoteNames.resourceUpdatedEventName) :: RemoteEvent
	local getResourceSnapshot = resourcesRemoteFolder:WaitForChild(RemoteNames.getResourceSnapshotFunctionName) :: RemoteFunction
	return resourceUpdated, getResourceSnapshot
end

local function getEconomyRemotes(): (RemoteEvent, RemoteFunction)
	local remotesFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local economyRemoteFolder = remotesFolder:WaitForChild(RemoteNames.economyFolderName) :: Folder
	local economyUpdated = economyRemoteFolder:WaitForChild(RemoteNames.economyUpdatedEventName) :: RemoteEvent
	local getEconomySnapshot = economyRemoteFolder:WaitForChild(RemoteNames.getEconomySnapshotFunctionName) :: RemoteFunction
	return economyUpdated, getEconomySnapshot
end

local function getHarvestConfirmedRemote(): RemoteEvent
	local remotesFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local harvestRemoteFolder = remotesFolder:WaitForChild(RemoteNames.harvestFolderName) :: Folder
	return harvestRemoteFolder:WaitForChild(RemoteNames.scytheHarvestConfirmedEventName) :: RemoteEvent
end

local function renderIfReady(view: ResourceStatusViewInstance)
	local resourceSnapshot = latestResourceSnapshot
	local economySnapshot = latestEconomySnapshot
	if resourceSnapshot == nil or economySnapshot == nil then
		return
	end

	local apples = resourceSnapshot.amountsByResourceId.Apple or 0
	local cider = resourceSnapshot.amountsByResourceId.Cider or 0
	view:render(apples, cider, economySnapshot.cash)
end

local function getResourceAmount(snapshot: ResourceSnapshot, resourceId: ResourceTypes.ResourceId): number
	return snapshot.amountsByResourceId[resourceId] or 0
end

local function flushPendingAppleGain(toastView: ResourceGainToastViewInstance)
	if pendingAppleGain <= 0 then
		return
	end

	toastView:showAppleGain(pendingAppleGain)
	pendingAppleGain = 0
	pendingAppleFlushToken += 1
end

local function schedulePendingAppleGainFlush(toastView: ResourceGainToastViewInstance)
	pendingAppleFlushToken += 1
	local token = pendingAppleFlushToken

	task.spawn(function()
		task.wait(APPLE_GAIN_FALLBACK_FLUSH_DELAY_SECONDS)
		if token ~= pendingAppleFlushToken then
			return
		end

		flushPendingAppleGain(toastView)
	end)
end

local function showResourceChangeToastsIfNeeded(
	toastView: ResourceGainToastViewInstance,
	soundPlayer: ResourceGainSoundPlayerInstance,
	previousSnapshot: ResourceSnapshot?,
	nextSnapshot: ResourceSnapshot,
	context: ResourceUpdateContext?
)
	if previousSnapshot == nil then
		return
	end

	local appleGain = getResourceAmount(nextSnapshot, "Apple") - getResourceAmount(previousSnapshot, "Apple")
	if appleGain > 0 then
		pendingAppleGain += appleGain
		schedulePendingAppleGainFlush(toastView)
	end

	local ciderGain = getResourceAmount(nextSnapshot, "Cider") - getResourceAmount(previousSnapshot, "Cider")
	if ciderGain > 0 then
		toastView:showCiderGain(ciderGain)
		if context ~= nil and context.reason == OFFLINE_EARNINGS_CLAIM_REASON then
			RewardClaimEffects.playCiderBottleClaim(getRootGui())
		else
			soundPlayer:playCiderCollected()
		end
	elseif ciderGain < 0 then
		toastView:showCiderUsed(math.abs(ciderGain))
	end
end

local function showCashChangeToastIfNeeded(
	toastView: ResourceGainToastViewInstance,
	soundPlayer: ResourceGainSoundPlayerInstance,
	previousSnapshot: EconomySnapshot?,
	nextSnapshot: EconomySnapshot
)
	if previousSnapshot == nil then
		return
	end

	local cashGain = nextSnapshot.cash - previousSnapshot.cash
	if cashGain > 0 then
		toastView:showCashGain(cashGain)
		soundPlayer:playCashEarned()
	elseif cashGain < 0 then
		toastView:showCashUsed(math.abs(cashGain))
	end
end

local ResourceStatusController = {}

function ResourceStatusController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local view = ResourceStatusView.new()
	local toastView = ResourceGainToastView.new()
	local soundPlayer = ResourceGainSoundPlayer.new()
	local resourceUpdated, getResourceSnapshot = getResourceRemotes()
	local economyUpdated, getEconomySnapshot = getEconomyRemotes()
	local harvestConfirmed = getHarvestConfirmedRemote()

	latestResourceSnapshot = getResourceSnapshot:InvokeServer() :: ResourceSnapshot
	latestEconomySnapshot = getEconomySnapshot:InvokeServer() :: EconomySnapshot
	renderIfReady(view)

	resourceUpdated.OnClientEvent:Connect(function(resourceSnapshot: ResourceSnapshot, context: ResourceUpdateContext?)
		showResourceChangeToastsIfNeeded(toastView, soundPlayer, latestResourceSnapshot, resourceSnapshot, context)
		latestResourceSnapshot = resourceSnapshot
		renderIfReady(view)
	end)

	economyUpdated.OnClientEvent:Connect(function(economySnapshot: EconomySnapshot)
		showCashChangeToastIfNeeded(toastView, soundPlayer, latestEconomySnapshot, economySnapshot)
		latestEconomySnapshot = economySnapshot
		renderIfReady(view)
	end)

	harvestConfirmed.OnClientEvent:Connect(function()
		flushPendingAppleGain(toastView)
	end)
end

return table.freeze(ResourceStatusController)

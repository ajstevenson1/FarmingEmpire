--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local dailyRewardsFolder = sharedFolder:WaitForChild("DailyRewards") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local DailyRewardsTypes = require(dailyRewardsFolder:WaitForChild("DailyRewardsTypes") :: ModuleScript)
local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local ResourceCatalog = require(resourcesFolder:WaitForChild("ResourceCatalog") :: ModuleScript)
local FrameManager = require(script.Parent.Parent.UI.FrameManager)

type DailyRewardDaySnapshot = DailyRewardsTypes.DailyRewardDaySnapshot
type DailyRewardEntry = DailyRewardsTypes.DailyRewardEntry
type DailyRewardsClaimResult = DailyRewardsTypes.DailyRewardsClaimResult
type DailyRewardsSnapshot = DailyRewardsTypes.DailyRewardsSnapshot
type GuiButtonLike = TextButton | ImageButton

local DAILY_REWARDS_FRAME_ID = "DailyRewards"
local MENU_FRAME_GROUP = "Menu"
local DEFAULT_PANEL_SIZE = UDim2.fromScale(0.52, 0.62)
local DEFAULT_PANEL_POSITION = UDim2.fromScale(0.5, 0.5)
local hasStarted = false
local latestSnapshot: DailyRewardsSnapshot? = nil
local latestStatusText: string? = nil
local isClaimPending = false
local didWarnMissingFrame = false
local registeredFrame: Frame? = nil

local function getRootGui(): ScreenGui
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before starting DailyRewardsController")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild("GUI")
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")
	return rootGui
end

local function findDescendant(parent: Instance, childName: string): Instance?
	return parent:FindFirstChild(childName, true)
end

local function getRequiredGuiButton(parent: Instance, childName: string): GuiButtonLike
	local child = parent:FindFirstChild(childName)
	assert(child ~= nil, string.format("%s must contain a child named %s", parent:GetFullName(), childName))
	assert(
		child:IsA("TextButton") or child:IsA("ImageButton"),
		string.format("%s.%s must be a TextButton or ImageButton", parent:GetFullName(), childName)
	)
	return child :: GuiButtonLike
end

local function getOpenButton(rootGui: ScreenGui): GuiButtonLike
	local hud = rootGui:WaitForChild("HUD")
	assert(hud:IsA("GuiObject"), "PlayerGui.GUI.HUD must be a GuiObject")
	local left = hud:WaitForChild("Left")
	assert(left:IsA("GuiObject"), "PlayerGui.GUI.HUD.Left must be a GuiObject")
	return getRequiredGuiButton(left, "DailyRewards")
end

local function getDailyRewardsFrame(rootGui: ScreenGui): Frame?
	local frames = rootGui:FindFirstChild("Frames")
	if frames == nil or not frames:IsA("Frame") then
		return nil
	end

	local dailyRewardsFrame = frames:FindFirstChild("DailyRewards")
	if dailyRewardsFrame == nil or not dailyRewardsFrame:IsA("Frame") then
		return nil
	end

	return dailyRewardsFrame
end

local function getClosedPanelPosition(panel: Frame): UDim2
	local panelHeight = math.max(panel.AbsoluteSize.Y, panel.Size.Y.Offset, 64)
	return UDim2.new(panel.Position.X.Scale, panel.Position.X.Offset, 1, panelHeight + 48)
end

local function prepareFrameDefaults(frame: Frame)
	if frame.Size == UDim2.fromOffset(100, 100) then
		frame.Size = DEFAULT_PANEL_SIZE
	end

	if frame.Position == UDim2.fromOffset(0, 0) then
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = DEFAULT_PANEL_POSITION
	end
end

local function getDailyRewardsRemotes(): (RemoteEvent, RemoteFunction, RemoteFunction)
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local rewardsFolder = rootFolder:WaitForChild(RemoteNames.dailyRewardsFolderName) :: Folder
	local dailyRewardsUpdated = rewardsFolder:WaitForChild(RemoteNames.dailyRewardsUpdatedEventName)
	local getDailyRewardsSnapshot = rewardsFolder:WaitForChild(RemoteNames.getDailyRewardsSnapshotFunctionName)
	local claimDailyReward = rewardsFolder:WaitForChild(RemoteNames.claimDailyRewardFunctionName)

	assert(dailyRewardsUpdated:IsA("RemoteEvent"), "DailyRewards.DailyRewardsUpdated must be a RemoteEvent")
	assert(getDailyRewardsSnapshot:IsA("RemoteFunction"), "DailyRewards.GetDailyRewardsSnapshot must be a RemoteFunction")
	assert(claimDailyReward:IsA("RemoteFunction"), "DailyRewards.ClaimDailyReward must be a RemoteFunction")

	return dailyRewardsUpdated :: RemoteEvent, getDailyRewardsSnapshot :: RemoteFunction, claimDailyReward :: RemoteFunction
end

local function findTextLabel(parent: Instance, childName: string): TextLabel?
	local label = findDescendant(parent, childName)
	if label == nil or not label:IsA("TextLabel") then
		return nil
	end

	return label
end

local function findGuiButton(parent: Instance, childName: string): GuiButtonLike?
	local button = findDescendant(parent, childName)
	if button == nil then
		return nil
	end

	if not (button:IsA("TextButton") or button:IsA("ImageButton")) then
		return nil
	end

	return button :: GuiButtonLike
end

local function findDayContainer(parent: Instance, dayIndex: number): GuiObject?
	local dayContainer = findDescendant(parent, string.format("Day%d", dayIndex))
	if dayContainer == nil or not dayContainer:IsA("GuiObject") then
		return nil
	end

	return dayContainer
end

local function formatRewardEntry(rewardEntry: DailyRewardEntry): string
	if rewardEntry.kind == "Cash" then
		return string.format("%d Cash", rewardEntry.amount)
	elseif rewardEntry.kind == "Resource" then
		local definition = ResourceCatalog.getResourceDefinition(rewardEntry.resourceId)
		return string.format("%d %s", rewardEntry.amount, definition.displayName)
	end

	local definition = ItemCatalog.getItemDefinition(rewardEntry.itemId)
	return string.format("%dx %s", rewardEntry.amount, definition.displayName)
end

local function formatRewardEntries(rewardEntries: { DailyRewardEntry }): string
	local parts: { string } = {}
	for _, rewardEntry in ipairs(rewardEntries) do
		table.insert(parts, formatRewardEntry(rewardEntry))
	end

	return table.concat(parts, ", ")
end

local function getDayStateText(daySnapshot: DailyRewardDaySnapshot): string
	if daySnapshot.state == "Claimed" then
		return "Claimed"
	elseif daySnapshot.state == "Claimable" then
		return "Ready"
	end

	return "Locked"
end

local function getCountdownText(snapshot: DailyRewardsSnapshot): string
	if snapshot.canClaim then
		return "Ready to claim"
	end

	local secondsRemaining = math.max(0, math.ceil(snapshot.nextClaimTime - Workspace:GetServerTimeNow()))
	local hours = math.floor(secondsRemaining / 3600)
	local minutes = math.floor((secondsRemaining % 3600) / 60)
	local seconds = secondsRemaining % 60
	return string.format("Next claim in %02d:%02d:%02d", hours, minutes, seconds)
end

local function getStatusText(snapshot: DailyRewardsSnapshot): string
	if latestStatusText ~= nil then
		return latestStatusText
	end

	if snapshot.canClaim and snapshot.claimableDayIndex ~= nil then
		return string.format("Day %d reward is ready.", snapshot.claimableDayIndex)
	end

	if snapshot.claimedTodayDayIndex ~= nil then
		return string.format("Day %d claimed. Come back tomorrow.", snapshot.claimedTodayDayIndex)
	end

	return "Daily rewards unavailable."
end

local function renderDay(dayContainer: GuiObject, daySnapshot: DailyRewardDaySnapshot)
	local titleLabel = findTextLabel(dayContainer, "TitleLabel")
	if titleLabel ~= nil then
		titleLabel.Text = daySnapshot.displayName
	end

	local rewardLabel = findTextLabel(dayContainer, "RewardLabel")
	if rewardLabel ~= nil then
		rewardLabel.Text = formatRewardEntries(daySnapshot.rewards)
	end

	local stateLabel = findTextLabel(dayContainer, "StateLabel")
	if stateLabel ~= nil then
		stateLabel.Text = getDayStateText(daySnapshot)
	end
end

local function renderFrame(frame: Frame)
	local snapshot = latestSnapshot
	if snapshot == nil then
		return
	end

	local statusLabel = findTextLabel(frame, "StatusLabel")
	if statusLabel ~= nil then
		statusLabel.Text = getStatusText(snapshot)
	end

	local nextClaimLabel = findTextLabel(frame, "NextClaimLabel")
	if nextClaimLabel ~= nil then
		nextClaimLabel.Text = getCountdownText(snapshot)
	end

	local claimButton = findGuiButton(frame, "ClaimButton")
	if claimButton ~= nil then
		claimButton.Active = not isClaimPending and snapshot.canClaim
		claimButton.AutoButtonColor = not isClaimPending and snapshot.canClaim
		if claimButton:IsA("TextButton") then
			if isClaimPending then
				claimButton.Text = "Claiming..."
			elseif snapshot.canClaim then
				claimButton.Text = "Claim"
			else
				claimButton.Text = "Claimed"
			end
		end
	end

	local rewardsList = findDescendant(frame, "RewardsList")
	if rewardsList ~= nil and rewardsList:IsA("GuiObject") then
		for _, daySnapshot in ipairs(snapshot.days) do
			local dayContainer = findDayContainer(rewardsList, daySnapshot.dayIndex)
			if dayContainer ~= nil then
				renderDay(dayContainer, daySnapshot)
			end
		end
	end
end

local function renderIfPossible(rootGui: ScreenGui)
	local frame = registeredFrame or getDailyRewardsFrame(rootGui)
	if frame == nil then
		return
	end

	renderFrame(frame)
end

local function refreshSnapshot(getDailyRewardsSnapshot: RemoteFunction)
	local success, result = pcall(function(): unknown
		return getDailyRewardsSnapshot:InvokeServer()
	end)

	if not success then
		warn(string.format("[DailyRewardsController] Failed to load daily rewards snapshot: %s", tostring(result)))
		return
	end

	latestSnapshot = result :: DailyRewardsSnapshot
	latestStatusText = nil
end

local function warnMissingFrame()
	if didWarnMissingFrame then
		return
	end

	didWarnMissingFrame = true
	warn("[DailyRewardsController] Create StarterGui.GUI.Frames.DailyRewards in Studio to enable the daily rewards menu.")
end

local function bindClaimButton(frame: Frame, claimDailyReward: RemoteFunction)
	local claimButton = findGuiButton(frame, "ClaimButton")
	if claimButton == nil then
		return
	end

	claimButton.Activated:Connect(function()
		local snapshot = latestSnapshot
		if snapshot == nil or not snapshot.canClaim or isClaimPending then
			return
		end

		isClaimPending = true
		latestStatusText = nil
		renderFrame(frame)

		local success, result = pcall(function(): unknown
			return claimDailyReward:InvokeServer()
		end)

		isClaimPending = false
		if not success then
			latestStatusText = "Claim failed."
			warn(string.format("[DailyRewardsController] Failed to claim daily reward: %s", tostring(result)))
			renderFrame(frame)
			return
		end

		local claimResult = result :: DailyRewardsClaimResult
		latestSnapshot = claimResult.snapshot
		if claimResult.status == "Claimed" and claimResult.claimedDayIndex ~= nil then
			latestStatusText = string.format("Claimed Day %d reward.", claimResult.claimedDayIndex)
		else
			latestStatusText = "Already claimed today."
		end
		renderFrame(frame)
	end)
end

local function ensureFrameRegistered(rootGui: ScreenGui, claimDailyReward: RemoteFunction): Frame?
	if registeredFrame ~= nil then
		return registeredFrame
	end

	local frame = getDailyRewardsFrame(rootGui)
	if frame == nil then
		warnMissingFrame()
		return nil
	end

	registeredFrame = frame
	prepareFrameDefaults(frame)
	FrameManager.registerFrame({
		id = DAILY_REWARDS_FRAME_ID,
		frame = frame,
		group = MENU_FRAME_GROUP,
		defaultOpen = frame.Visible,
		closedPosition = getClosedPanelPosition(frame),
	})

	bindClaimButton(frame, claimDailyReward)
	frame.Destroying:Connect(function()
		if registeredFrame == frame then
			registeredFrame = nil
		end
	end)
	renderFrame(frame)

	return frame
end

local DailyRewardsController = {}

function DailyRewardsController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local rootGui = getRootGui()
	local openButton = getOpenButton(rootGui)
	local dailyRewardsUpdated, getDailyRewardsSnapshot, claimDailyReward = getDailyRewardsRemotes()

	refreshSnapshot(getDailyRewardsSnapshot)
	ensureFrameRegistered(rootGui, claimDailyReward)
	renderIfPossible(rootGui)

	openButton.Activated:Connect(function()
		local frame = ensureFrameRegistered(rootGui, claimDailyReward)
		if frame == nil then
			return
		end

		refreshSnapshot(getDailyRewardsSnapshot)
		renderFrame(frame)
		FrameManager.toggle(DAILY_REWARDS_FRAME_ID)
	end)

	dailyRewardsUpdated.OnClientEvent:Connect(function(snapshot: DailyRewardsSnapshot)
		latestSnapshot = snapshot
		if not isClaimPending then
			latestStatusText = nil
		end
		renderIfPossible(rootGui)
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			local frame = registeredFrame
			if frame ~= nil and FrameManager.isOpen(DAILY_REWARDS_FRAME_ID) then
				renderFrame(frame)
			end
		end
	end)
end

return table.freeze(DailyRewardsController)

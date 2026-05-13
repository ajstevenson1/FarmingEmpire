--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local playtimeRewardsFolder = sharedFolder:WaitForChild("PlaytimeRewards") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local PlaytimeRewardsTypes = require(playtimeRewardsFolder:WaitForChild("PlaytimeRewardsTypes") :: ModuleScript)
local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local ResourceCatalog = require(resourcesFolder:WaitForChild("ResourceCatalog") :: ModuleScript)
local FrameManager = require(script.Parent.Parent.UI.FrameManager)
local PlaytimeRewardsView = require(script.Parent.PlaytimeRewardsView)

type PlaytimeRewardSnapshot = PlaytimeRewardsTypes.PlaytimeRewardSnapshot
type PlaytimeRewardState = PlaytimeRewardsTypes.PlaytimeRewardState
type PlaytimeRewardEntry = PlaytimeRewardsTypes.PlaytimeRewardEntry
type PlaytimeRewardsClaimResult = PlaytimeRewardsTypes.PlaytimeRewardsClaimResult
type PlaytimeRewardsSnapshot = PlaytimeRewardsTypes.PlaytimeRewardsSnapshot
type GuiButtonLike = TextButton | ImageButton

local PLAYTIME_REWARDS_FRAME_ID = "PlaytimeRewards"
local LEGACY_REWARDS_FRAME_ID = "DailyRewards"
local MENU_FRAME_GROUP = "Menu"
local DEFAULT_PANEL_SIZE = UDim2.fromScale(0.52, 0.62)
local DEFAULT_PANEL_POSITION = UDim2.fromScale(0.5, 0.5)
local hasStarted = false
local latestSnapshot: PlaytimeRewardsSnapshot? = nil
local latestStatusText: string? = nil
local isClaimPending = false
local didWarnMissingFrame = false
local registeredFrame: Frame? = nil

local function getRootGui(): ScreenGui
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before starting PlaytimeRewardsController")

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

	local playtimeRewardsButton = left:FindFirstChild(PLAYTIME_REWARDS_FRAME_ID)
	if playtimeRewardsButton ~= nil then
		assert(
			playtimeRewardsButton:IsA("TextButton") or playtimeRewardsButton:IsA("ImageButton"),
			string.format("%s.%s must be a TextButton or ImageButton", left:GetFullName(), PLAYTIME_REWARDS_FRAME_ID)
		)
		return playtimeRewardsButton :: GuiButtonLike
	end

	return getRequiredGuiButton(left, LEGACY_REWARDS_FRAME_ID)
end

local function getNotificationIndicator(rootGui: ScreenGui): GuiObject?
	local openButton = getOpenButton(rootGui)
	local design = openButton:FindFirstChild("Design")
	if design == nil or not design:IsA("GuiObject") then
		return nil
	end

	local notification = design:FindFirstChild("Notification")
	if notification == nil or not notification:IsA("GuiObject") then
		return nil
	end

	return notification
end

local function getPlaytimeRewardsFrame(rootGui: ScreenGui): Frame?
	local frames = rootGui:FindFirstChild("Frames")
	if frames == nil or not frames:IsA("Frame") then
		return nil
	end

	local playtimeRewardsFrame = frames:FindFirstChild(PLAYTIME_REWARDS_FRAME_ID)
	if playtimeRewardsFrame == nil then
		playtimeRewardsFrame = frames:FindFirstChild(LEGACY_REWARDS_FRAME_ID)
	end

	if playtimeRewardsFrame == nil or not playtimeRewardsFrame:IsA("Frame") then
		return nil
	end

	return playtimeRewardsFrame
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

local function getPlaytimeRewardsRemotes(): (RemoteEvent, RemoteFunction, RemoteFunction)
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local rewardsFolder = rootFolder:WaitForChild(RemoteNames.playtimeRewardsFolderName) :: Folder
	local playtimeRewardsUpdated = rewardsFolder:WaitForChild(RemoteNames.playtimeRewardsUpdatedEventName)
	local getPlaytimeRewardsSnapshot = rewardsFolder:WaitForChild(RemoteNames.getPlaytimeRewardsSnapshotFunctionName)
	local claimPlaytimeReward = rewardsFolder:WaitForChild(RemoteNames.claimPlaytimeRewardFunctionName)

	assert(playtimeRewardsUpdated:IsA("RemoteEvent"), "PlaytimeRewards.PlaytimeRewardsUpdated must be a RemoteEvent")
	assert(getPlaytimeRewardsSnapshot:IsA("RemoteFunction"), "PlaytimeRewards.GetPlaytimeRewardsSnapshot must be a RemoteFunction")
	assert(claimPlaytimeReward:IsA("RemoteFunction"), "PlaytimeRewards.ClaimPlaytimeReward must be a RemoteFunction")

	return playtimeRewardsUpdated :: RemoteEvent, getPlaytimeRewardsSnapshot :: RemoteFunction, claimPlaytimeReward :: RemoteFunction
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

local function findRewardContainer(parent: Instance, rewardIndex: number): GuiObject?
	local rewardContainer = findDescendant(parent, string.format("Reward%d", rewardIndex))
	if rewardContainer == nil or not rewardContainer:IsA("GuiObject") then
		return nil
	end

	return rewardContainer
end

local function formatRewardEntry(rewardEntry: PlaytimeRewardEntry): string
	if rewardEntry.kind == "Cash" then
		return string.format("%d Cash", rewardEntry.amount)
	elseif rewardEntry.kind == "Resource" then
		local definition = ResourceCatalog.getResourceDefinition(rewardEntry.resourceId)
		return string.format("%d %s", rewardEntry.amount, definition.displayName)
	end

	local definition = ItemCatalog.getItemDefinition(rewardEntry.itemId)
	return string.format("%dx %s", rewardEntry.amount, definition.displayName)
end

local function formatRewardEntries(rewardEntries: { PlaytimeRewardEntry }): string
	local parts: { string } = {}
	for _, rewardEntry in ipairs(rewardEntries) do
		table.insert(parts, formatRewardEntry(rewardEntry))
	end

	return table.concat(parts, ", ")
end

local function getRewardStateText(rewardState: PlaytimeRewardState): string
	if rewardState == "Claimed" then
		return "Claimed"
	elseif rewardState == "Claimable" then
		return "Unclaimed"
	end

	return "Not yet unlocked"
end

local function formatDuration(seconds: number): string
	local sanitizedSeconds = math.max(0, math.ceil(seconds))
	local hours = math.floor(sanitizedSeconds / 3600)
	local minutes = math.floor((sanitizedSeconds % 3600) / 60)
	local remainingSeconds = sanitizedSeconds % 60

	if hours > 0 then
		return string.format("%02d:%02d:%02d", hours, minutes, remainingSeconds)
	end

	return string.format("%02d:%02d", minutes, remainingSeconds)
end

local function getCurrentPlaytimeSeconds(snapshot: PlaytimeRewardsSnapshot): number
	return snapshot.currentPlaytimeSeconds + math.max(0, Workspace:GetServerTimeNow() - snapshot.snapshotServerTime)
end

local function getDynamicRewardState(rewardSnapshot: PlaytimeRewardSnapshot, snapshot: PlaytimeRewardsSnapshot): PlaytimeRewardState
	if rewardSnapshot.state == "Claimed" then
		return "Claimed"
	end

	if getCurrentPlaytimeSeconds(snapshot) >= rewardSnapshot.requiredPlaytimeSeconds then
		return "Claimable"
	end

	return "Locked"
end

local function getRewardSecondsRemaining(rewardSnapshot: PlaytimeRewardSnapshot, snapshot: PlaytimeRewardsSnapshot): number
	if getDynamicRewardState(rewardSnapshot, snapshot) ~= "Locked" then
		return 0
	end

	return math.max(0, math.ceil(rewardSnapshot.requiredPlaytimeSeconds - getCurrentPlaytimeSeconds(snapshot)))
end

local function getClaimableRewardIndex(snapshot: PlaytimeRewardsSnapshot): number?
	for _, rewardSnapshot in ipairs(snapshot.rewardSnapshots) do
		if getDynamicRewardState(rewardSnapshot, snapshot) == "Claimable" then
			return rewardSnapshot.rewardIndex
		end
	end

	return nil
end

local function canClaim(snapshot: PlaytimeRewardsSnapshot): boolean
	return getClaimableRewardIndex(snapshot) ~= nil
end

local function getNextRewardSecondsRemaining(snapshot: PlaytimeRewardsSnapshot): number?
	local lowestSecondsRemaining: number? = nil
	for _, rewardSnapshot in ipairs(snapshot.rewardSnapshots) do
		if getDynamicRewardState(rewardSnapshot, snapshot) == "Locked" then
			local secondsRemaining = getRewardSecondsRemaining(rewardSnapshot, snapshot)
			if lowestSecondsRemaining == nil or secondsRemaining < lowestSecondsRemaining then
				lowestSecondsRemaining = secondsRemaining
			end
		end
	end

	return lowestSecondsRemaining
end

local function getCountdownText(snapshot: PlaytimeRewardsSnapshot): string
	if canClaim(snapshot) then
		return "Reward ready"
	end

	local secondsRemaining = getNextRewardSecondsRemaining(snapshot)
	if secondsRemaining == nil then
		return "All rewards claimed"
	end

	return string.format("Next reward in %s", formatDuration(secondsRemaining))
end

local function getStatusText(snapshot: PlaytimeRewardsSnapshot): string
	if latestStatusText ~= nil then
		return latestStatusText
	end

	local claimableRewardIndex = getClaimableRewardIndex(snapshot)
	if claimableRewardIndex ~= nil then
		return string.format("Reward %d is ready.", claimableRewardIndex)
	end

	local secondsRemaining = getNextRewardSecondsRemaining(snapshot)
	if secondsRemaining ~= nil then
		return string.format("Play %s more for the next reward.", formatDuration(secondsRemaining))
	end

	return "All playtime rewards claimed."
end

local function getRowColors(rewardState: PlaytimeRewardState): (Color3, Color3, Color3)
	if rewardState == "Claimed" then
		return Color3.fromRGB(30, 92, 46), Color3.fromRGB(94, 232, 104), Color3.fromRGB(214, 255, 218)
	elseif rewardState == "Claimable" then
		return Color3.fromRGB(117, 91, 24), Color3.fromRGB(255, 220, 63), Color3.fromRGB(255, 246, 180)
	end

	return Color3.fromRGB(42, 45, 48), Color3.fromRGB(106, 112, 118), Color3.fromRGB(218, 222, 226)
end

local function renderReward(rewardContainer: GuiObject, rewardSnapshot: PlaytimeRewardSnapshot, snapshot: PlaytimeRewardsSnapshot)
	local dynamicRewardState = getDynamicRewardState(rewardSnapshot, snapshot)
	local backgroundColor, strokeColor, textColor = getRowColors(dynamicRewardState)

	rewardContainer.BackgroundColor3 = backgroundColor
	rewardContainer.BackgroundTransparency = 0

	local titleLabel = findTextLabel(rewardContainer, "TitleLabel")
	if titleLabel ~= nil then
		titleLabel.Text = rewardSnapshot.displayName
		titleLabel.TextColor3 = textColor
	end

	local rewardLabel = findTextLabel(rewardContainer, "RewardLabel")
	if rewardLabel ~= nil then
		rewardLabel.Text = formatRewardEntries(rewardSnapshot.rewards)
		rewardLabel.TextColor3 = textColor
	end

	local stateLabel = findTextLabel(rewardContainer, "StateLabel")
	if stateLabel ~= nil then
		if dynamicRewardState == "Locked" then
			stateLabel.Text = string.format("%s (%s)", getRewardStateText(dynamicRewardState), formatDuration(getRewardSecondsRemaining(rewardSnapshot, snapshot)))
		else
			stateLabel.Text = getRewardStateText(dynamicRewardState)
		end

		stateLabel.TextColor3 = textColor
	end

	local stroke = rewardContainer:FindFirstChildOfClass("UIStroke")
	if stroke ~= nil then
		stroke.Color = strokeColor
	end
end

local function renderNotificationIndicator(rootGui: ScreenGui)
	local notification = getNotificationIndicator(rootGui)
	if notification == nil then
		return
	end

	local snapshot = latestSnapshot
	notification.Visible = snapshot ~= nil and canClaim(snapshot) and not isClaimPending
end

local function renderFrame(frame: Frame)
	local snapshot = latestSnapshot
	if snapshot == nil then
		return
	end

	local contentRoot = PlaytimeRewardsView.ensure(frame)

	local statusLabel = findTextLabel(contentRoot, "StatusLabel")
	if statusLabel ~= nil then
		statusLabel.Text = getStatusText(snapshot)
	end

	local playtimeLabel = findTextLabel(contentRoot, "PlaytimeLabel")
	if playtimeLabel ~= nil then
		playtimeLabel.Text = string.format("Playtime: %s", formatDuration(getCurrentPlaytimeSeconds(snapshot)))
	end

	local nextClaimLabel = findTextLabel(contentRoot, "NextClaimLabel")
	if nextClaimLabel ~= nil then
		nextClaimLabel.Text = getCountdownText(snapshot)
	end

	local claimButton = findGuiButton(contentRoot, "ClaimButton")
	if claimButton ~= nil then
		local canClaimReward = canClaim(snapshot)
		claimButton.Active = not isClaimPending and canClaimReward
		claimButton.AutoButtonColor = not isClaimPending and canClaimReward
		if claimButton:IsA("TextButton") then
			if isClaimPending then
				claimButton.Text = "Claiming..."
			elseif canClaimReward then
				claimButton.Text = "Claim"
			else
				claimButton.Text = "Waiting"
			end
		end
	end

	local rewardsList = findDescendant(contentRoot, "RewardsList")
	if rewardsList ~= nil and rewardsList:IsA("GuiObject") then
		for _, rewardSnapshot in ipairs(snapshot.rewardSnapshots) do
			local rewardContainer = findRewardContainer(rewardsList, rewardSnapshot.rewardIndex)
			if rewardContainer ~= nil then
				renderReward(rewardContainer, rewardSnapshot, snapshot)
			end
		end
	end
end

local function renderIfPossible(rootGui: ScreenGui)
	local frame = registeredFrame or getPlaytimeRewardsFrame(rootGui)
	if frame == nil then
		return
	end

	renderFrame(frame)
end

local function refreshSnapshot(getPlaytimeRewardsSnapshot: RemoteFunction)
	local success, result = pcall(function(): unknown
		return getPlaytimeRewardsSnapshot:InvokeServer()
	end)

	if not success then
		warn(string.format("[PlaytimeRewardsController] Failed to load playtime rewards snapshot: %s", tostring(result)))
		return
	end

	latestSnapshot = result :: PlaytimeRewardsSnapshot
	latestStatusText = nil
end

local function warnMissingFrame()
	if didWarnMissingFrame then
		return
	end

	didWarnMissingFrame = true
	warn("[PlaytimeRewardsController] Create StarterGui.GUI.Frames.PlaytimeRewards in Studio to enable the playtime rewards menu.")
end

local function bindClaimButton(rootGui: ScreenGui, frame: Frame, claimPlaytimeReward: RemoteFunction)
	local contentRoot = PlaytimeRewardsView.ensure(frame)
	local claimButton = findGuiButton(contentRoot, "ClaimButton")
	if claimButton == nil then
		return
	end

	claimButton.Activated:Connect(function()
		local snapshot = latestSnapshot
		if snapshot == nil or not canClaim(snapshot) or isClaimPending then
			return
		end

		isClaimPending = true
		latestStatusText = nil
		renderNotificationIndicator(rootGui)
		renderFrame(frame)

		local success, result = pcall(function(): unknown
			return claimPlaytimeReward:InvokeServer()
		end)

		isClaimPending = false
		if not success then
			latestStatusText = "Claim failed."
			warn(string.format("[PlaytimeRewardsController] Failed to claim playtime reward: %s", tostring(result)))
			renderNotificationIndicator(rootGui)
			renderFrame(frame)
			return
		end

		local claimResult = result :: PlaytimeRewardsClaimResult
		latestSnapshot = claimResult.snapshot
		if claimResult.status == "Claimed" and claimResult.claimedRewardIndex ~= nil then
			latestStatusText = string.format("Claimed Reward %d.", claimResult.claimedRewardIndex)
		else
			latestStatusText = "No reward ready yet."
		end
		renderNotificationIndicator(rootGui)
		renderFrame(frame)
	end)
end

local function ensureFrameRegistered(rootGui: ScreenGui, claimPlaytimeReward: RemoteFunction): Frame?
	if registeredFrame ~= nil then
		return registeredFrame
	end

	local frame = getPlaytimeRewardsFrame(rootGui)
	if frame == nil then
		warnMissingFrame()
		return nil
	end

	registeredFrame = frame
	prepareFrameDefaults(frame)
	PlaytimeRewardsView.ensure(frame)
	FrameManager.registerFrame({
		id = PLAYTIME_REWARDS_FRAME_ID,
		frame = frame,
		group = MENU_FRAME_GROUP,
		defaultOpen = frame.Visible,
		closedPosition = getClosedPanelPosition(frame),
	})

	bindClaimButton(rootGui, frame, claimPlaytimeReward)
	frame.Destroying:Connect(function()
		if registeredFrame == frame then
			registeredFrame = nil
		end
	end)
	renderFrame(frame)

	return frame
end

local PlaytimeRewardsController = {}

function PlaytimeRewardsController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local rootGui = getRootGui()
	local openButton = getOpenButton(rootGui)
	local playtimeRewardsUpdated, getPlaytimeRewardsSnapshot, claimPlaytimeReward = getPlaytimeRewardsRemotes()

	renderNotificationIndicator(rootGui)
	refreshSnapshot(getPlaytimeRewardsSnapshot)
	renderNotificationIndicator(rootGui)
	ensureFrameRegistered(rootGui, claimPlaytimeReward)
	renderIfPossible(rootGui)

	openButton.Activated:Connect(function()
		local frame = ensureFrameRegistered(rootGui, claimPlaytimeReward)
		if frame == nil then
			return
		end

		refreshSnapshot(getPlaytimeRewardsSnapshot)
		renderNotificationIndicator(rootGui)
		renderFrame(frame)
		FrameManager.toggle(PLAYTIME_REWARDS_FRAME_ID)
	end)

	playtimeRewardsUpdated.OnClientEvent:Connect(function(snapshot: PlaytimeRewardsSnapshot)
		latestSnapshot = snapshot
		if not isClaimPending then
			latestStatusText = nil
		end
		renderNotificationIndicator(rootGui)
		renderIfPossible(rootGui)
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			renderNotificationIndicator(rootGui)

			local frame = registeredFrame
			if frame ~= nil and FrameManager.isOpen(PLAYTIME_REWARDS_FRAME_ID) then
				renderFrame(frame)
			end
		end
	end)
end

return table.freeze(PlaytimeRewardsController)

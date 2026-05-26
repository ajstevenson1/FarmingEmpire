--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local playtimeRewardsFolder = sharedFolder:WaitForChild("PlaytimeRewards") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local PlaytimeRewardsTypes = require(playtimeRewardsFolder:WaitForChild("PlaytimeRewardsTypes") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local ResourceCatalog = require(resourcesFolder:WaitForChild("ResourceCatalog") :: ModuleScript)
local FrameManager = require(script.Parent.Parent.UI.FrameManager)
local RewardClaimEffects = require(script.Parent.RewardClaimEffects)

type DailyRewardSnapshot = PlaytimeRewardsTypes.DailyRewardSnapshot
type DailyRewardsSnapshot = PlaytimeRewardsTypes.DailyRewardsSnapshot
type PlaytimeRewardEntry = PlaytimeRewardsTypes.PlaytimeRewardEntry
type PlaytimeRewardSnapshot = PlaytimeRewardsTypes.PlaytimeRewardSnapshot
type PlaytimeRewardState = PlaytimeRewardsTypes.PlaytimeRewardState
type PlaytimeRewardsClaimResult = PlaytimeRewardsTypes.PlaytimeRewardsClaimResult
type PlaytimeRewardsSnapshot = PlaytimeRewardsTypes.PlaytimeRewardsSnapshot
type RewardCategory = PlaytimeRewardsTypes.RewardCategory
type RewardsSnapshot = PlaytimeRewardsTypes.RewardsSnapshot
type GuiButtonLike = TextButton | ImageButton
type RewardSnapshot = PlaytimeRewardSnapshot | DailyRewardSnapshot

local REWARDS_FRAME_ID = "Rewards"
local LEGACY_PLAYTIME_FRAME_ID = "PlaytimeRewards"
local LEGACY_DAILY_FRAME_ID = "DailyRewards"
local MENU_FRAME_GROUP = "Menu"
local TEMPLATE_NAME = "PlaytimeRewardTemplate"
local DEFAULT_PANEL_SIZE = UDim2.fromScale(0.52, 0.62)
local DEFAULT_PANEL_POSITION = UDim2.fromScale(0.5, 0.5)
local TAB_TWEEN_INFO = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ACTIVE_TAB_SCALE = 1.2
local ACTIVE_STROKE_COLOR = Color3.fromRGB(255, 255, 255)
local CLAIMED_GRADIENT = ColorSequence.new(Color3.fromRGB(62, 238, 34), Color3.fromRGB(20, 185, 47))
local CLAIMED_STROKE_COLOR = Color3.fromRGB(9, 106, 34)
local CLAIMED_TEXT_STROKE_COLOR = Color3.fromRGB(5, 72, 24)
local LOCKED_GRADIENT = ColorSequence.new(Color3.fromRGB(255, 96, 96), Color3.fromRGB(210, 42, 58))
local LOCKED_STROKE_COLOR = Color3.fromRGB(150, 22, 38)
local LOCKED_TEXT_STROKE_COLOR = Color3.fromRGB(108, 14, 26)
local DESKTOP_GRID_CELL_SIZE = 180
local DESKTOP_GRID_PADDING = 30
local MOBILE_GRID_CELL_SIZE = 100
local MOBILE_GRID_PADDING = 15
local MOBILE_SCROLLER_WIDTH = 520
local CLAIM_HITBOX_NAME = "RewardClaimHitbox"

local hasStarted = false
local latestSnapshot: RewardsSnapshot? = nil
local activeCategory: RewardCategory = "Playtime"
local isClaimPending = false
local didWarnMissingFrame = false
local didWarnMissingScroller = false
local didWarnMissingTemplate = false
local registeredFrame: Frame? = nil
local tabBaseSizes: { [GuiObject]: UDim2 } = {}
local tabBaseStrokeColors: { [UIStroke]: Color3 } = {}
local renderFrame: ((Frame, ScreenGui, RemoteFunction, boolean) -> ())? = nil
local cachedRootGui: ScreenGui? = nil
local cachedGetRewardsSnapshot: RemoteFunction? = nil
local cachedClaimReward: RemoteFunction? = nil

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

local function findTextLabel(parent: Instance, childName: string): TextLabel?
	local label = findDescendant(parent, childName)
	if label == nil or not label:IsA("TextLabel") then
		return nil
	end

	return label
end

local function findGuiButton(parent: Instance, childName: string): GuiButtonLike?
	local button = findDescendant(parent, childName)
	if button == nil or not (button:IsA("TextButton") or button:IsA("ImageButton")) then
		return nil
	end

	return button :: GuiButtonLike
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

	local rewardsButton = left:FindFirstChild(REWARDS_FRAME_ID)
	if rewardsButton ~= nil and (rewardsButton:IsA("TextButton") or rewardsButton:IsA("ImageButton")) then
		return rewardsButton :: GuiButtonLike
	end

	local playtimeRewardsButton = left:FindFirstChild(LEGACY_PLAYTIME_FRAME_ID)
	if playtimeRewardsButton ~= nil and (playtimeRewardsButton:IsA("TextButton") or playtimeRewardsButton:IsA("ImageButton")) then
		return playtimeRewardsButton :: GuiButtonLike
	end

	return getRequiredGuiButton(left, LEGACY_DAILY_FRAME_ID)
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

local function getRewardsFrame(rootGui: ScreenGui): Frame?
	local frames = rootGui:FindFirstChild("Frames")
	if frames == nil then
		return nil
	end

	local rewardsFrame = frames:FindFirstChild(REWARDS_FRAME_ID)
		or frames:FindFirstChild(LEGACY_PLAYTIME_FRAME_ID)
		or frames:FindFirstChild(LEGACY_DAILY_FRAME_ID)
	if rewardsFrame == nil or not rewardsFrame:IsA("Frame") then
		return nil
	end

	return rewardsFrame
end

local function getOrCreateRewardsFrame(rootGui: ScreenGui): Frame?
	local frames = rootGui:FindFirstChild("Frames")
	if frames == nil then
		frames = Instance.new("Folder")
		frames.Name = "Frames"
		frames.Parent = rootGui
	end

	local existingFrame = getRewardsFrame(rootGui)
	if existingFrame ~= nil then
		return existingFrame
	end

	local frame = Instance.new("Frame")
	frame.Name = REWARDS_FRAME_ID
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = DEFAULT_PANEL_POSITION
	frame.Size = DEFAULT_PANEL_SIZE
	frame.Visible = false
	frame.Parent = frames
	return frame
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

local function getRewardsRemotes(): (RemoteEvent, RemoteFunction, RemoteFunction)
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local rewardsFolder = rootFolder:WaitForChild(RemoteNames.playtimeRewardsFolderName) :: Folder
	local rewardsUpdated = rewardsFolder:WaitForChild(RemoteNames.playtimeRewardsUpdatedEventName)
	local getRewardsSnapshot = rewardsFolder:WaitForChild(RemoteNames.getPlaytimeRewardsSnapshotFunctionName)
	local claimReward = rewardsFolder:WaitForChild(RemoteNames.claimPlaytimeRewardFunctionName)

	assert(rewardsUpdated:IsA("RemoteEvent"), "PlaytimeRewards.PlaytimeRewardsUpdated must be a RemoteEvent")
	assert(getRewardsSnapshot:IsA("RemoteFunction"), "PlaytimeRewards.GetPlaytimeRewardsSnapshot must be a RemoteFunction")
	assert(claimReward:IsA("RemoteFunction"), "PlaytimeRewards.ClaimPlaytimeReward must be a RemoteFunction")

	return rewardsUpdated :: RemoteEvent, getRewardsSnapshot :: RemoteFunction, claimReward :: RemoteFunction
end

local function scaleUDim2(size: UDim2, scale: number): UDim2
	return UDim2.new(size.X.Scale * scale, math.floor(size.X.Offset * scale), size.Y.Scale * scale, math.floor(size.Y.Offset * scale))
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

local function getRewardImageAssetId(rewardEntries: { PlaytimeRewardEntry }): string
	for _, rewardEntry in ipairs(rewardEntries) do
		local imageAssetId = rewardEntry.imageAssetId
		if imageAssetId ~= nil and imageAssetId ~= "" then
			return imageAssetId
		end
	end

	return ""
end

local function getCurrentPlaytimeSeconds(snapshot: PlaytimeRewardsSnapshot): number
	return snapshot.currentPlaytimeSeconds + math.max(0, Workspace:GetServerTimeNow() - snapshot.snapshotServerTime)
end

local function getPlaytimeRewardState(rewardSnapshot: PlaytimeRewardSnapshot, snapshot: PlaytimeRewardsSnapshot): PlaytimeRewardState
	if rewardSnapshot.state == "Claimed" then
		return "Claimed"
	end

	if getCurrentPlaytimeSeconds(snapshot) >= rewardSnapshot.requiredPlaytimeSeconds then
		return "Claimable"
	end

	return "Locked"
end

local function getDailyRewardState(rewardSnapshot: DailyRewardSnapshot, snapshot: DailyRewardsSnapshot): PlaytimeRewardState
	if rewardSnapshot.state == "Claimed" then
		return "Claimed"
	end

	local elapsedSeconds = math.max(0, Workspace:GetServerTimeNow() - snapshot.snapshotServerTime)
	if rewardSnapshot.rewardIndex == snapshot.claimableRewardIndex
		or (rewardSnapshot.state == "Locked" and rewardSnapshot.secondsRemaining > 0 and rewardSnapshot.secondsRemaining - elapsedSeconds <= 0)
	then
		return "Claimable"
	end

	return rewardSnapshot.state
end

local function getPlaytimeRewardSecondsRemaining(rewardSnapshot: PlaytimeRewardSnapshot, snapshot: PlaytimeRewardsSnapshot): number
	if getPlaytimeRewardState(rewardSnapshot, snapshot) ~= "Locked" then
		return 0
	end

	return math.max(0, math.ceil(rewardSnapshot.requiredPlaytimeSeconds - getCurrentPlaytimeSeconds(snapshot)))
end

local function getDailyRewardSecondsRemaining(rewardSnapshot: DailyRewardSnapshot, snapshot: DailyRewardsSnapshot): number
	if getDailyRewardState(rewardSnapshot, snapshot) ~= "Locked" then
		return 0
	end

	local elapsedSeconds = math.max(0, Workspace:GetServerTimeNow() - snapshot.snapshotServerTime)
	return math.max(0, math.ceil(rewardSnapshot.secondsRemaining - elapsedSeconds))
end

local function canClaimPlaytime(snapshot: PlaytimeRewardsSnapshot): boolean
	for _, rewardSnapshot in ipairs(snapshot.rewardSnapshots) do
		if getPlaytimeRewardState(rewardSnapshot, snapshot) == "Claimable" then
			return true
		end
	end

	return false
end

local function canClaimDaily(snapshot: DailyRewardsSnapshot): boolean
	if snapshot.canClaim then
		return true
	end

	local nextRewardSecondsRemaining = snapshot.nextRewardSecondsRemaining
	if nextRewardSecondsRemaining == nil then
		return false
	end

	local elapsedSeconds = math.max(0, Workspace:GetServerTimeNow() - snapshot.snapshotServerTime)
	return nextRewardSecondsRemaining - elapsedSeconds <= 0
end

local function canClaimAny(snapshot: RewardsSnapshot): boolean
	return canClaimPlaytime(snapshot.playtime) or canClaimDaily(snapshot.daily)
end

local function getPreferredOpenCategory(snapshot: RewardsSnapshot): RewardCategory
	return if canClaimDaily(snapshot.daily) then "Daily" else activeCategory
end

local function getCategorySnapshot(snapshot: RewardsSnapshot, category: RewardCategory): PlaytimeRewardsSnapshot | DailyRewardsSnapshot
	if category == "Daily" then
		return snapshot.daily
	end

	return snapshot.playtime
end

local function getRewardState(rewardSnapshot: RewardSnapshot, snapshot: PlaytimeRewardsSnapshot | DailyRewardsSnapshot, category: RewardCategory): PlaytimeRewardState
	if category == "Daily" then
		return getDailyRewardState(rewardSnapshot :: DailyRewardSnapshot, snapshot :: DailyRewardsSnapshot)
	end

	return getPlaytimeRewardState(rewardSnapshot :: PlaytimeRewardSnapshot, snapshot :: PlaytimeRewardsSnapshot)
end

local function getRewardSecondsRemaining(rewardSnapshot: RewardSnapshot, snapshot: PlaytimeRewardsSnapshot | DailyRewardsSnapshot, category: RewardCategory): number
	if category == "Daily" then
		return getDailyRewardSecondsRemaining(rewardSnapshot :: DailyRewardSnapshot, snapshot :: DailyRewardsSnapshot)
	end

	return getPlaytimeRewardSecondsRemaining(rewardSnapshot :: PlaytimeRewardSnapshot, snapshot :: PlaytimeRewardsSnapshot)
end

local function getRewardSnapshots(snapshot: PlaytimeRewardsSnapshot | DailyRewardsSnapshot, category: RewardCategory): { RewardSnapshot }
	local rewardSnapshots: { RewardSnapshot } = {}
	if category == "Daily" then
		for _, rewardSnapshot in ipairs((snapshot :: DailyRewardsSnapshot).rewardSnapshots) do
			table.insert(rewardSnapshots, rewardSnapshot)
		end
	else
		for _, rewardSnapshot in ipairs((snapshot :: PlaytimeRewardsSnapshot).rewardSnapshots) do
			table.insert(rewardSnapshots, rewardSnapshot)
		end
	end

	return rewardSnapshots
end

local function findRewardsDesign(frame: Frame): GuiObject
	local design = frame:FindFirstChild("Design")
	if design ~= nil and design:IsA("GuiObject") then
		return design
	end

	return frame
end

local function findTabs(frame: Frame): GuiObject?
	local design = findRewardsDesign(frame)
	local tabs = design:FindFirstChild("Tabs")
	if tabs ~= nil and tabs:IsA("GuiObject") then
		return tabs
	end

	return nil
end

local function findTabButton(frame: Frame, category: RewardCategory): GuiObject?
	local tabs = findTabs(frame)
	if tabs == nil then
		return nil
	end

	local tab = tabs:FindFirstChild(category)
	if tab ~= nil and tab:IsA("GuiObject") then
		return tab
	end

	return nil
end

local function findTabStroke(tab: GuiObject): UIStroke?
	local design = tab:FindFirstChild("Design")
	local strokeParent = if design ~= nil and design:IsA("GuiObject") then design else tab
	local stroke = strokeParent:FindFirstChild("Stroke")
	if stroke ~= nil and stroke:IsA("UIStroke") then
		return stroke
	end

	return strokeParent:FindFirstChildOfClass("UIStroke")
end

local function renderTabs(frame: Frame)
	for _, category in ipairs({ "Playtime" :: RewardCategory, "Daily" :: RewardCategory }) do
		local tab = findTabButton(frame, category)
		if tab ~= nil then
			if tabBaseSizes[tab] == nil then
				tabBaseSizes[tab] = tab.Size
			end

			local stroke = findTabStroke(tab)
			if stroke ~= nil then
				if tabBaseStrokeColors[stroke] == nil then
					tabBaseStrokeColors[stroke] = stroke.Color
				end

				stroke.Color = if category == activeCategory then ACTIVE_STROKE_COLOR else tabBaseStrokeColors[stroke]
			end

			local targetSize = if category == activeCategory then scaleUDim2(tabBaseSizes[tab], ACTIVE_TAB_SCALE) else tabBaseSizes[tab]
			TweenService:Create(tab, TAB_TWEEN_INFO, { Size = targetSize }):Play()
		end
	end
end

local function setClaimText(claim: GuiObject, text: string)
	if claim:IsA("TextButton") then
		claim.Text = ""
	end

	local design = claim:FindFirstChild("Design")
	local textRoot = if design ~= nil then design else claim
	local claimLabel = textRoot:FindFirstChild("Claim", true)
	if claimLabel ~= nil and claimLabel:IsA("TextLabel") then
		claimLabel.Text = text
		return
	end

	local textLabel = textRoot:FindFirstChild("TextLabel", true)
	if textLabel ~= nil and textLabel:IsA("TextLabel") then
		textLabel.Text = text
		return
	end

	local title = textRoot:FindFirstChild("Title", true)
	if title ~= nil and title:IsA("TextLabel") then
		title.Text = text
	end
end

local function applyClaimVariant(claim: GuiObject, rewardState: PlaytimeRewardState)
	local design = claim:FindFirstChild("Design")
	if design == nil or not design:IsA("GuiObject") then
		return
	end

	local gradient = design:FindFirstChild("Gradient")
	if gradient ~= nil and gradient:IsA("UIGradient") then
		if rewardState == "Claimed" then
			gradient.Color = CLAIMED_GRADIENT
		elseif rewardState == "Locked" then
			gradient.Color = LOCKED_GRADIENT
		end
	end

	local stroke = design:FindFirstChild("Stroke")
	if stroke ~= nil and stroke:IsA("UIStroke") then
		if rewardState == "Claimed" then
			stroke.Color = CLAIMED_STROKE_COLOR
		elseif rewardState == "Locked" then
			stroke.Color = LOCKED_STROKE_COLOR
		end
	end

	local claimLabel = design:FindFirstChild("Claim", true)
	if claimLabel ~= nil and claimLabel:IsA("TextLabel") then
		local textStroke = claimLabel:FindFirstChild("Stroke")
		if textStroke ~= nil and textStroke:IsA("UIStroke") then
			if rewardState == "Claimed" then
				textStroke.Color = CLAIMED_TEXT_STROKE_COLOR
			elseif rewardState == "Locked" then
				textStroke.Color = LOCKED_TEXT_STROKE_COLOR
			end
		end
	end
end

local function setClaimState(tile: GuiObject, rewardState: PlaytimeRewardState, isPending: boolean)
	local claim = findDescendant(tile, "Claim")
	if claim == nil or not claim:IsA("GuiObject") then
		return
	end

	if rewardState == "Claimed" then
		setClaimText(claim, "Claimed")
		applyClaimVariant(claim, "Claimed")
	elseif rewardState == "Claimable" then
		setClaimText(claim, if isPending then "Claiming..." else "Claim")
	else
		setClaimText(claim, "Locked")
		applyClaimVariant(claim, "Locked")
	end

	if claim:IsA("TextButton") or claim:IsA("ImageButton") then
		local button = claim :: GuiButtonLike
		button.Active = rewardState == "Claimable" and not isPending
		button.AutoButtonColor = rewardState == "Claimable" and not isPending
	end
end

local function getHighestGuiZIndex(root: Instance): number
	local highestZIndex = 1
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			highestZIndex = math.max(highestZIndex, descendant.ZIndex)
		end
	end

	return highestZIndex
end

local function getOrCreateClaimHitbox(tile: GuiObject): TextButton
	local existing = tile:FindFirstChild(CLAIM_HITBOX_NAME)
	if existing ~= nil then
		assert(existing:IsA("TextButton"), string.format("%s must be a TextButton", existing:GetFullName()))
		return existing
	end

	local hitbox = Instance.new("TextButton")
	hitbox.Name = CLAIM_HITBOX_NAME
	hitbox.Active = false
	hitbox.AutoButtonColor = false
	hitbox.BackgroundTransparency = 1
	hitbox.BorderSizePixel = 0
	hitbox.Size = UDim2.fromScale(1, 1)
	hitbox.Position = UDim2.fromScale(0, 0)
	hitbox.Text = ""
	hitbox.ZIndex = getHighestGuiZIndex(tile) + 1
	hitbox.Parent = tile
	return hitbox
end

local function renderRewardTile(tile: GuiObject, rewardSnapshot: RewardSnapshot, categorySnapshot: PlaytimeRewardsSnapshot | DailyRewardsSnapshot, category: RewardCategory, claimReward: RemoteFunction, rootGui: ScreenGui, frame: Frame)
	local rewardState = getRewardState(rewardSnapshot, categorySnapshot, category)
	local rewardText = formatRewardEntries(rewardSnapshot.rewards)

	tile.Name = string.format("%sReward%d", category, rewardSnapshot.rewardIndex)
	tile.Visible = true

	local rewardLabel = findTextLabel(tile, "Reward")
	if rewardLabel ~= nil then
		rewardLabel.Text = rewardText
	end

	local titleLabel = findTextLabel(tile, "Title")
	if titleLabel ~= nil then
		titleLabel.Text = rewardSnapshot.displayName
	end

	local timerLabel = findTextLabel(tile, "Timer")
	if timerLabel ~= nil then
		if category == "Daily" then
			timerLabel.Text = string.format("Day %d", rewardSnapshot.rewardIndex)
		elseif rewardState == "Claimed" then
			timerLabel.Text = "Claimed"
		elseif rewardState == "Claimable" then
			timerLabel.Text = "Unlocked"
		else
			local secondsRemaining = getRewardSecondsRemaining(rewardSnapshot, categorySnapshot, category)
			if secondsRemaining <= 0 then
				timerLabel.Text = "Locked"
			elseif category == "Playtime" then
				timerLabel.Text = formatDuration(secondsRemaining)
			end
		end
	end

	local icon = findDescendant(tile, "Icon")
	if icon ~= nil and icon:IsA("ImageLabel") then
		local imageAssetId = getRewardImageAssetId(rewardSnapshot.rewards)
		if imageAssetId ~= "" then
			icon.Image = imageAssetId
		end
	end

	setClaimState(tile, rewardState, isClaimPending)

	local function tryClaimReward()
		if rewardState ~= "Claimable" or isClaimPending then
			return
		end

		isClaimPending = true
		setClaimState(tile, rewardState, true)

		local success, result = pcall(function(): unknown
			return claimReward:InvokeServer(category)
		end)

		isClaimPending = false
		if not success then
			warn(string.format("[PlaytimeRewardsController] Failed to claim %s reward: %s", category, tostring(result)))
			setClaimState(tile, rewardState, false)
			return
		end

		local claimResult = result :: PlaytimeRewardsClaimResult
		latestSnapshot = claimResult.snapshot
		RewardClaimEffects.play(rootGui)
		renderTabs(frame)
		local notification = getNotificationIndicator(rootGui)
		if notification ~= nil and latestSnapshot ~= nil then
			notification.Visible = canClaimAny(latestSnapshot :: RewardsSnapshot) and not isClaimPending
		end
		local renderFrameCallback = renderFrame
		if renderFrameCallback ~= nil then
			renderFrameCallback(frame, rootGui, claimReward, false)
		end
	end

	local claim = findDescendant(tile, "Claim")
	if claim ~= nil and (claim:IsA("TextButton") or claim:IsA("ImageButton")) then
		local button = claim :: GuiButtonLike
		button.Activated:Connect(tryClaimReward)
	end

	local claimHitbox = getOrCreateClaimHitbox(tile)
	claimHitbox.Active = rewardState == "Claimable" and not isClaimPending
	claimHitbox.Visible = rewardState == "Claimable"
	claimHitbox.Activated:Connect(tryClaimReward)
end

local function warnMissingTemplate()
	if didWarnMissingTemplate then
		return
	end

	didWarnMissingTemplate = true
	warn(string.format("[PlaytimeRewardsController] Add a %s GuiObject under Rewards to render reward tiles.", TEMPLATE_NAME))
end

local function findRewardTemplate(frame: Frame): GuiObject?
	local templatesFolder = ReplicatedStorage:FindFirstChild("Templates")
	if templatesFolder ~= nil then
		local replicatedTemplate = templatesFolder:FindFirstChild(TEMPLATE_NAME)
		if replicatedTemplate ~= nil and replicatedTemplate:IsA("GuiObject") then
			return replicatedTemplate
		end

		local replicatedFallbackTemplate = templatesFolder:FindFirstChild("RewardTemplate")
		if replicatedFallbackTemplate ~= nil and replicatedFallbackTemplate:IsA("GuiObject") then
			return replicatedFallbackTemplate
		end
	end

	local template = findDescendant(frame, TEMPLATE_NAME)
	if template ~= nil and template:IsA("GuiObject") then
		return template
	end

	local fallbackTemplate = findDescendant(frame, "RewardTemplate")
	if fallbackTemplate ~= nil and fallbackTemplate:IsA("GuiObject") then
		return fallbackTemplate
	end

	return nil
end

local function findRewardsScroller(frame: Frame): ScrollingFrame?
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("ScrollingFrame") then
			return child
		end
	end

	return nil
end

local function warnMissingScroller()
	if didWarnMissingScroller then
		return
	end

	didWarnMissingScroller = true
	warn("[PlaytimeRewardsController] Add a ScrollingFrame directly under Rewards to render reward tiles.")
end

local function clearRewardTiles(scroller: ScrollingFrame)
	for _, child in ipairs(scroller:GetChildren()) do
		if child:IsA("GuiObject") and child:GetAttribute("GeneratedRewardTile") == true then
			child:Destroy()
		end
	end
end

local function updateRewardGridLayout(scroller: ScrollingFrame, rootGui: ScreenGui)
	local layout = scroller:FindFirstChildOfClass("UIGridLayout")
	if layout == nil then
		return
	end

	local scrollerWidth = scroller.AbsoluteSize.X
	local isMobile = scrollerWidth > 0 and scrollerWidth <= MOBILE_SCROLLER_WIDTH
	local cellSize = if isMobile then MOBILE_GRID_CELL_SIZE else DESKTOP_GRID_CELL_SIZE
	local padding = if isMobile then MOBILE_GRID_PADDING else DESKTOP_GRID_PADDING

	layout.CellSize = UDim2.fromOffset(cellSize, cellSize)
	layout.CellPadding = UDim2.fromOffset(padding, padding)
end

local function bindResponsiveGridLayout(frame: Frame, rootGui: ScreenGui)
	rootGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local scroller = findRewardsScroller(frame)
		if scroller ~= nil then
			updateRewardGridLayout(scroller, rootGui)
		end
	end)
end

local function renderRewardGrid(frame: Frame, rootGui: ScreenGui, claimReward: RemoteFunction, _animate: boolean)
	local snapshot = latestSnapshot
	if snapshot == nil then
		return
	end

	local scroller = findRewardsScroller(frame)
	if scroller == nil then
		warnMissingScroller()
		return
	end

	local template = findRewardTemplate(frame)
	if template == nil then
		warnMissingTemplate()
		return
	end

	updateRewardGridLayout(scroller, rootGui)
	clearRewardTiles(scroller)

	local categorySnapshot = getCategorySnapshot(snapshot, activeCategory)
	for _, rewardSnapshot in ipairs(getRewardSnapshots(categorySnapshot, activeCategory)) do
		local tile = template:Clone()
		tile:SetAttribute("GeneratedRewardTile", true)
		tile.LayoutOrder = rewardSnapshot.rewardIndex
		tile.Parent = scroller
		renderRewardTile(tile, rewardSnapshot, categorySnapshot, activeCategory, claimReward, rootGui, frame)
	end
end

local function renderNotificationIndicator(rootGui: ScreenGui)
	local notification = getNotificationIndicator(rootGui)
	if notification == nil then
		return
	end

	local snapshot = latestSnapshot
	notification.Visible = snapshot ~= nil and canClaimAny(snapshot) and not isClaimPending
end

renderFrame = function(frame: Frame, rootGui: ScreenGui, claimReward: RemoteFunction, animateGrid: boolean)
	renderTabs(frame)
	renderRewardGrid(frame, rootGui, claimReward, animateGrid)
end

local function refreshSnapshot(getRewardsSnapshot: RemoteFunction)
	local success, result = pcall(function(): unknown
		return getRewardsSnapshot:InvokeServer()
	end)

	if not success then
		warn(string.format("[PlaytimeRewardsController] Failed to load rewards snapshot: %s", tostring(result)))
		return
	end

	latestSnapshot = result :: RewardsSnapshot
end

local function warnMissingFrame()
	if didWarnMissingFrame then
		return
	end

	didWarnMissingFrame = true
	warn("[PlaytimeRewardsController] Create StarterGui.GUI.Frames.Rewards in Studio to enable the rewards menu.")
end

local function bindTabs(frame: Frame, rootGui: ScreenGui, claimReward: RemoteFunction)
	for _, category in ipairs({ "Playtime" :: RewardCategory, "Daily" :: RewardCategory }) do
		local tab = findTabButton(frame, category)
		if tab ~= nil and (tab:IsA("TextButton") or tab:IsA("ImageButton")) then
			local button = tab :: GuiButtonLike
			button.Activated:Connect(function()
				if activeCategory == category then
					return
				end

				activeCategory = category
				local renderFrameCallback = renderFrame
				if renderFrameCallback ~= nil then
					renderFrameCallback(frame, rootGui, claimReward, true)
				end
			end)
		end
	end
end

local function ensureFrameRegistered(rootGui: ScreenGui, claimReward: RemoteFunction): Frame?
	if registeredFrame ~= nil then
		return registeredFrame
	end

	local frame = getOrCreateRewardsFrame(rootGui)
	if frame == nil then
		warnMissingFrame()
		return nil
	end

	registeredFrame = frame
	prepareFrameDefaults(frame)
	FrameManager.registerFrame({
		id = REWARDS_FRAME_ID,
		frame = frame,
		group = MENU_FRAME_GROUP,
		defaultOpen = frame.Visible,
		closedPosition = getClosedPanelPosition(frame),
	})

	bindTabs(frame, rootGui, claimReward)
	bindResponsiveGridLayout(frame, rootGui)
	frame.Destroying:Connect(function()
		if registeredFrame == frame then
			registeredFrame = nil
		end
	end)
	local renderFrameCallback = renderFrame
	if renderFrameCallback ~= nil then
		renderFrameCallback(frame, rootGui, claimReward, false)
	end

	return frame
end

local PlaytimeRewardsController = {}

function PlaytimeRewardsController.open(category: RewardCategory?)
	local rootGui = cachedRootGui
	local getRewardsSnapshot = cachedGetRewardsSnapshot
	local claimReward = cachedClaimReward
	if rootGui == nil or getRewardsSnapshot == nil or claimReward == nil then
		return
	end

	refreshSnapshot(getRewardsSnapshot)
	local snapshot = latestSnapshot
	if category ~= nil then
		activeCategory = category
	elseif snapshot ~= nil then
		activeCategory = getPreferredOpenCategory(snapshot)
	end

	renderNotificationIndicator(rootGui)
	local frame = ensureFrameRegistered(rootGui, claimReward)
	if frame == nil then
		return
	end

	local renderFrameCallback = renderFrame
	if renderFrameCallback ~= nil then
		renderFrameCallback(frame, rootGui, claimReward, false)
	end

	FrameManager.open(REWARDS_FRAME_ID)
end

function PlaytimeRewardsController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local rootGui = getRootGui()
	local openButton = getOpenButton(rootGui)
	local rewardsUpdated, getRewardsSnapshot, claimReward = getRewardsRemotes()
	cachedRootGui = rootGui
	cachedGetRewardsSnapshot = getRewardsSnapshot
	cachedClaimReward = claimReward

	renderNotificationIndicator(rootGui)
	refreshSnapshot(getRewardsSnapshot)
	renderNotificationIndicator(rootGui)
	ensureFrameRegistered(rootGui, claimReward)

	openButton.Activated:Connect(function()
		refreshSnapshot(getRewardsSnapshot)
		local snapshot = latestSnapshot
		if snapshot ~= nil then
			activeCategory = getPreferredOpenCategory(snapshot)
		end

		renderNotificationIndicator(rootGui)
		local frame = ensureFrameRegistered(rootGui, claimReward)
		if frame == nil then
			return
		end

		local renderFrameCallback = renderFrame
		if renderFrameCallback ~= nil then
			renderFrameCallback(frame, rootGui, claimReward, false)
		end
		FrameManager.toggle(REWARDS_FRAME_ID)
	end)

	rewardsUpdated.OnClientEvent:Connect(function(snapshot: RewardsSnapshot)
		latestSnapshot = snapshot
		renderNotificationIndicator(rootGui)
		local frame = registeredFrame
		if frame ~= nil then
			local renderFrameCallback = renderFrame
			if renderFrameCallback ~= nil then
				renderFrameCallback(frame, rootGui, claimReward, false)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			renderNotificationIndicator(rootGui)

			local frame = registeredFrame
			if frame ~= nil and FrameManager.isOpen(REWARDS_FRAME_ID) then
				local renderFrameCallback = renderFrame
				if renderFrameCallback ~= nil then
					renderFrameCallback(frame, rootGui, claimReward, false)
				end
			end
		end
	end)
end

return table.freeze(PlaytimeRewardsController)

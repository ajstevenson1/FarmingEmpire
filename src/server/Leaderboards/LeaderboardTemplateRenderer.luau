--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

export type TemplateLeaderboardEntry = {
	userId: number,
	playerName: string,
	scoreText: string,
}

export type TemplateLeaderboardRenderConfig = {
	workspaceModelName: string,
	displayBoardName: string,
	scrollingFrameName: string,
	entriesToDisplay: number,
	refreshIntervalSeconds: number,
	emptyText: string,
}

local TEMPLATES_FOLDER_NAME = "Templates"
local ENTRY_TEMPLATE_NAME = "LeaderboardEntry"
local LEGACY_GENERATED_ROOT_NAME = "CashLeaderboardRoot"
local GENERATED_ATTRIBUTE_NAME = "IsGeneratedLeaderboardElement"

local RANK_LABEL_NAME = "RankLabel"
local NAME_LABEL_NAME = "NameLabel"
local SCORE_LABEL_NAME = "ScoreLabel"
local PLAYER_IMAGE_NAME = "PlayerImage"

local GOLD_COLOR = Color3.fromRGB(245, 196, 77)
local SILVER_COLOR = Color3.fromRGB(204, 213, 222)
local BRONZE_COLOR = Color3.fromRGB(209, 139, 83)
local DEFAULT_RANK_COLOR = Color3.fromRGB(91, 184, 111)

local templatesFolder = ReplicatedStorage:WaitForChild(TEMPLATES_FOLDER_NAME) :: Folder
local thumbnailImagesByUserId: { [number]: string } = {}

local function getRankColor(rank: number): Color3
	if rank == 1 then
		return GOLD_COLOR
	elseif rank == 2 then
		return SILVER_COLOR
	elseif rank == 3 then
		return BRONZE_COLOR
	end

	return DEFAULT_RANK_COLOR
end

local function getThumbnailImage(userId: number): string
	local cachedImage = thumbnailImagesByUserId[userId]
	if cachedImage ~= nil then
		return cachedImage
	end

	local success, imageOrError = pcall(function(): string
		local content, _isReady = Players:GetUserThumbnailAsync(
			userId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size100x100
		)

		return content
	end)

	if success then
		local image = imageOrError :: string
		thumbnailImagesByUserId[userId] = image
		return image
	end

	warn(string.format("Failed to load leaderboard thumbnail for userId %d: %s", userId, tostring(imageOrError)))
	return ""
end

local function getEntryTemplate(): Frame
	local template = templatesFolder:WaitForChild(ENTRY_TEMPLATE_NAME)
	assert(template:IsA("Frame"), string.format("ReplicatedStorage.Templates.%s must be a Frame", ENTRY_TEMPLATE_NAME))
	return template
end

local function findRequiredTextLabel(parent: Instance, childName: string): TextLabel
	local child = parent:FindFirstChild(childName)
	assert(child ~= nil and child:IsA("TextLabel"), string.format("%s.%s must be a TextLabel", parent:GetFullName(), childName))
	return child :: TextLabel
end

local function findRequiredImageLabel(parent: Instance, childName: string): ImageLabel
	local child = parent:FindFirstChild(childName)
	assert(child ~= nil and child:IsA("ImageLabel"), string.format("%s.%s must be an ImageLabel", parent:GetFullName(), childName))
	return child :: ImageLabel
end

local function findDisplayBoard(config: TemplateLeaderboardRenderConfig): Instance?
	local leaderboardModel = Workspace:FindFirstChild(config.workspaceModelName)
	if leaderboardModel == nil then
		warn(string.format("Workspace.%s is required for this leaderboard.", config.workspaceModelName))
		return nil
	end

	local displayBoard = leaderboardModel:FindFirstChild(config.displayBoardName, true)
	if displayBoard == nil then
		warn(string.format("Workspace.%s needs a %s descendant.", config.workspaceModelName, config.displayBoardName))
	end

	return displayBoard
end

local function getScrollingFrame(config: TemplateLeaderboardRenderConfig): ScrollingFrame?
	local displayBoard = findDisplayBoard(config)
	if displayBoard == nil then
		return nil
	end

	local surfaceGui = displayBoard:FindFirstChildWhichIsA("SurfaceGui")
	if surfaceGui == nil then
		warn(string.format("%s needs a SurfaceGui child.", displayBoard:GetFullName()))
		return nil
	end

	local legacyGeneratedRoot = surfaceGui:FindFirstChild(LEGACY_GENERATED_ROOT_NAME)
	if legacyGeneratedRoot ~= nil then
		legacyGeneratedRoot:Destroy()
	end

	local scrollingFrame = surfaceGui:FindFirstChild(config.scrollingFrameName)
	if scrollingFrame == nil or not scrollingFrame:IsA("ScrollingFrame") then
		warn(string.format("%s needs a ScrollingFrame named %s.", surfaceGui:GetFullName(), config.scrollingFrameName))
		return nil
	end

	return scrollingFrame
end

local function clearGeneratedElements(scrollingFrame: ScrollingFrame)
	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:GetAttribute(GENERATED_ATTRIBUTE_NAME) == true
			or string.match(child.Name, "^Entry_%d%d$")
		then
			child:Destroy()
		end
	end
end

local function styleTemplateRow(row: Frame, rank: number)
	row.LayoutOrder = rank
	row:SetAttribute(GENERATED_ATTRIBUTE_NAME, true)
end

local function createRow(scrollingFrame: ScrollingFrame, entry: TemplateLeaderboardEntry, rank: number)
	local row = getEntryTemplate():Clone()
	row.Name = string.format("Entry_%02d", rank)
	styleTemplateRow(row, rank)
	row.Parent = scrollingFrame

	local rankLabel = findRequiredTextLabel(row, RANK_LABEL_NAME)
	local nameLabel = findRequiredTextLabel(row, NAME_LABEL_NAME)
	local scoreLabel = findRequiredTextLabel(row, SCORE_LABEL_NAME)
	local playerImage = findRequiredImageLabel(row, PLAYER_IMAGE_NAME)

	rankLabel.Text = string.format("#%d", rank)
	rankLabel.TextColor3 = getRankColor(rank)
	nameLabel.Text = entry.playerName
	scoreLabel.Text = entry.scoreText
	scoreLabel.TextColor3 = getRankColor(rank)
	playerImage.Image = getThumbnailImage(entry.userId)
end

local LeaderboardTemplateRenderer = {}

function LeaderboardTemplateRenderer.render(config: TemplateLeaderboardRenderConfig, entries: { TemplateLeaderboardEntry }, updatedAtUnix: number)
	local scrollingFrame = getScrollingFrame(config)
	if scrollingFrame == nil then
		return
	end

	clearGeneratedElements(scrollingFrame)

	for rank, entry in ipairs(entries) do
		createRow(scrollingFrame, entry, rank)
	end
end

return table.freeze(LeaderboardTemplateRenderer)

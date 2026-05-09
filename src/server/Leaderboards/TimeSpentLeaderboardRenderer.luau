--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local leaderboardsFolder = sharedFolder:WaitForChild("Leaderboards") :: Folder

local LeaderboardTypes = require(leaderboardsFolder:WaitForChild("LeaderboardTypes") :: ModuleScript)
local TimeSpentLeaderboardConfig = require(leaderboardsFolder:WaitForChild("TimeSpentLeaderboardConfig") :: ModuleScript)
local LeaderboardTemplateRenderer = require(script.Parent.LeaderboardTemplateRenderer)

type TimeSpentLeaderboardEntry = LeaderboardTypes.TimeSpentLeaderboardEntry
type TemplateLeaderboardEntry = LeaderboardTemplateRenderer.TemplateLeaderboardEntry
type TemplateLeaderboardRenderConfig = LeaderboardTemplateRenderer.TemplateLeaderboardRenderConfig

local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 60 * SECONDS_PER_MINUTE
local SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR

local function formatTime(totalSeconds: number): string
	local seconds = math.max(0, math.floor(totalSeconds))
	local days = math.floor(seconds / SECONDS_PER_DAY)
	local hours = math.floor((seconds % SECONDS_PER_DAY) / SECONDS_PER_HOUR)
	local minutes = math.floor((seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE)

	if days > 0 then
		return string.format("%dd %dh", days, hours)
	elseif hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	end

	return string.format("%dm", minutes)
end

local function buildRenderConfig(): TemplateLeaderboardRenderConfig
	return {
		workspaceModelName = TimeSpentLeaderboardConfig.workspaceModelName,
		displayBoardName = TimeSpentLeaderboardConfig.displayBoardName,
		scrollingFrameName = TimeSpentLeaderboardConfig.scrollingFrameName,
		entriesToDisplay = TimeSpentLeaderboardConfig.entriesToDisplay,
		refreshIntervalSeconds = TimeSpentLeaderboardConfig.refreshIntervalSeconds,
		emptyText = "No time records yet",
	}
end

local function buildTemplateEntries(entries: { TimeSpentLeaderboardEntry }): { TemplateLeaderboardEntry }
	local templateEntries: { TemplateLeaderboardEntry } = table.create(#entries)
	for _, entry in ipairs(entries) do
		table.insert(templateEntries, {
			userId = entry.userId,
			playerName = entry.playerName,
			scoreText = formatTime(entry.totalSeconds),
		})
	end

	return templateEntries
end

local TimeSpentLeaderboardRenderer = {}

function TimeSpentLeaderboardRenderer.render(entries: { TimeSpentLeaderboardEntry }, updatedAtUnix: number)
	LeaderboardTemplateRenderer.render(buildRenderConfig(), buildTemplateEntries(entries), updatedAtUnix)
end

return table.freeze(TimeSpentLeaderboardRenderer)

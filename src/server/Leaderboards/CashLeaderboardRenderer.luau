--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local formattingFolder = sharedFolder:WaitForChild("Formatting") :: Folder
local leaderboardsFolder = sharedFolder:WaitForChild("Leaderboards") :: Folder

local CashLeaderboardConfig = require(leaderboardsFolder:WaitForChild("CashLeaderboardConfig") :: ModuleScript)
local LeaderboardTypes = require(leaderboardsFolder:WaitForChild("LeaderboardTypes") :: ModuleScript)
local NumberFormatter = require(formattingFolder:WaitForChild("NumberFormatter") :: ModuleScript)
local LeaderboardTemplateRenderer = require(script.Parent.LeaderboardTemplateRenderer)

type CashLeaderboardEntry = LeaderboardTypes.CashLeaderboardEntry
type TemplateLeaderboardEntry = LeaderboardTemplateRenderer.TemplateLeaderboardEntry
type TemplateLeaderboardRenderConfig = LeaderboardTemplateRenderer.TemplateLeaderboardRenderConfig

local function buildRenderConfig(): TemplateLeaderboardRenderConfig
	return {
		workspaceModelName = CashLeaderboardConfig.workspaceModelName,
		displayBoardName = CashLeaderboardConfig.displayBoardName,
		scrollingFrameName = CashLeaderboardConfig.scrollingFrameName,
		entriesToDisplay = CashLeaderboardConfig.entriesToDisplay,
		refreshIntervalSeconds = CashLeaderboardConfig.refreshIntervalSeconds,
		emptyText = "No cash records yet",
	}
end

local function buildTemplateEntries(entries: { CashLeaderboardEntry }): { TemplateLeaderboardEntry }
	local templateEntries: { TemplateLeaderboardEntry } = table.create(#entries)
	for _, entry in ipairs(entries) do
		table.insert(templateEntries, {
			userId = entry.userId,
			playerName = entry.playerName,
			scoreText = "$" .. NumberFormatter.formatAbbreviated(entry.cash, {
				decimalPlaces = 1,
				trimTrailingZeros = true,
			}),
		})
	end

	return templateEntries
end

local CashLeaderboardRenderer = {}

function CashLeaderboardRenderer.render(entries: { CashLeaderboardEntry }, updatedAtUnix: number)
	LeaderboardTemplateRenderer.render(buildRenderConfig(), buildTemplateEntries(entries), updatedAtUnix)
end

return table.freeze(CashLeaderboardRenderer)

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local leaderboardsFolder = sharedFolder:WaitForChild("Leaderboards") :: Folder

local CashLeaderboardConfig = require(leaderboardsFolder:WaitForChild("CashLeaderboardConfig") :: ModuleScript)
local LeaderboardTypes = require(leaderboardsFolder:WaitForChild("LeaderboardTypes") :: ModuleScript)
local LeaderboardTemplateRenderer = require(script.Parent.LeaderboardTemplateRenderer)

type CashLeaderboardEntry = LeaderboardTypes.CashLeaderboardEntry
type TemplateLeaderboardEntry = LeaderboardTemplateRenderer.TemplateLeaderboardEntry
type TemplateLeaderboardRenderConfig = LeaderboardTemplateRenderer.TemplateLeaderboardRenderConfig

local function formatCash(cash: number): string
	local sanitizedCash = math.max(0, math.floor(cash))
	local suffixes = {
		{ value = 1000000000, suffix = "B" },
		{ value = 1000000, suffix = "M" },
		{ value = 1000, suffix = "K" },
	}

	for _, suffixInfo in ipairs(suffixes) do
		if sanitizedCash >= suffixInfo.value then
			local compactValue = sanitizedCash / suffixInfo.value
			if compactValue >= 100 then
				return string.format("$%d%s", math.floor(compactValue), suffixInfo.suffix)
			end

			return string.format("$%.1f%s", compactValue, suffixInfo.suffix)
		end
	end

	return string.format("$%d", sanitizedCash)
end

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
			scoreText = formatCash(entry.cash),
		})
	end

	return templateEntries
end

local CashLeaderboardRenderer = {}

function CashLeaderboardRenderer.render(entries: { CashLeaderboardEntry }, updatedAtUnix: number)
	LeaderboardTemplateRenderer.render(buildRenderConfig(), buildTemplateEntries(entries), updatedAtUnix)
end

return table.freeze(CashLeaderboardRenderer)

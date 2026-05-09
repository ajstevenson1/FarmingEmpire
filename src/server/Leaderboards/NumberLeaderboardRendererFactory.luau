--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local leaderboardsFolder = sharedFolder:WaitForChild("Leaderboards") :: Folder

local LeaderboardTypes = require(leaderboardsFolder:WaitForChild("LeaderboardTypes") :: ModuleScript)
local LeaderboardTemplateRenderer = require(script.Parent.LeaderboardTemplateRenderer)

type NumberLeaderboardEntry = LeaderboardTypes.NumberLeaderboardEntry
type TemplateLeaderboardEntry = LeaderboardTemplateRenderer.TemplateLeaderboardEntry
type TemplateLeaderboardRenderConfig = LeaderboardTemplateRenderer.TemplateLeaderboardRenderConfig

export type NumberLeaderboardConfig = {
	workspaceModelName: string,
	displayBoardName: string,
	scrollingFrameName: string,
	entriesToDisplay: number,
	refreshIntervalSeconds: number,
}

export type NumberLeaderboardRenderer = {
	render: (self: NumberLeaderboardRenderer, entries: { NumberLeaderboardEntry }, updatedAtUnix: number) -> (),
}

local function formatCompactNumber(value: number): string
	local sanitizedValue = math.max(0, math.floor(value))
	local suffixes = {
		{ value = 1000000000, suffix = "B" },
		{ value = 1000000, suffix = "M" },
		{ value = 1000, suffix = "K" },
	}

	for _, suffixInfo in ipairs(suffixes) do
		if sanitizedValue >= suffixInfo.value then
			local compactValue = sanitizedValue / suffixInfo.value
			if compactValue >= 100 then
				return string.format("%d%s", math.floor(compactValue), suffixInfo.suffix)
			end

			return string.format("%.1f%s", compactValue, suffixInfo.suffix)
		end
	end

	return tostring(sanitizedValue)
end

local Renderer = {}
Renderer.__index = Renderer

local function buildRenderConfig(config: NumberLeaderboardConfig, emptyText: string): TemplateLeaderboardRenderConfig
	return {
		workspaceModelName = config.workspaceModelName,
		displayBoardName = config.displayBoardName,
		scrollingFrameName = config.scrollingFrameName,
		entriesToDisplay = config.entriesToDisplay,
		refreshIntervalSeconds = config.refreshIntervalSeconds,
		emptyText = emptyText,
	}
end

local function buildTemplateEntries(entries: { NumberLeaderboardEntry }, scorePrefix: string): { TemplateLeaderboardEntry }
	local templateEntries: { TemplateLeaderboardEntry } = table.create(#entries)
	for _, entry in ipairs(entries) do
		table.insert(templateEntries, {
			userId = entry.userId,
			playerName = entry.playerName,
			scoreText = scorePrefix .. formatCompactNumber(entry.value),
		})
	end

	return templateEntries
end

function Renderer:render(entries: { NumberLeaderboardEntry }, updatedAtUnix: number)
	LeaderboardTemplateRenderer.render(
		buildRenderConfig(self._config, self._emptyText),
		buildTemplateEntries(entries, self._scorePrefix),
		updatedAtUnix
	)
end

local NumberLeaderboardRendererFactory = {}

function NumberLeaderboardRendererFactory.create(
	config: NumberLeaderboardConfig,
	scorePrefix: string,
	emptyText: string
): NumberLeaderboardRenderer
	return setmetatable({
		_config = config,
		_scorePrefix = scorePrefix,
		_emptyText = emptyText,
	}, Renderer) :: NumberLeaderboardRenderer
end

return table.freeze(NumberLeaderboardRendererFactory)

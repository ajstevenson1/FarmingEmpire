--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local formattingFolder = sharedFolder:WaitForChild("Formatting") :: Folder
local leaderboardsFolder = sharedFolder:WaitForChild("Leaderboards") :: Folder

local LeaderboardTypes = require(leaderboardsFolder:WaitForChild("LeaderboardTypes") :: ModuleScript)
local NumberFormatter = require(formattingFolder:WaitForChild("NumberFormatter") :: ModuleScript)
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
			scoreText = scorePrefix .. NumberFormatter.formatAbbreviated(entry.value, {
				decimalPlaces = 1,
				trimTrailingZeros = true,
			}),
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

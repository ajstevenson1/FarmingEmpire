--!strict

export type GamePassDefinition = {
	id: string,
	displayName: string,
	gamePassId: number,
	cashMultiplier: number?,
}

local AUTO_CIDER_GAME_PASS_KEY = "AutoCiderPass"

local GAME_PASS_DEFINITIONS: { [string]: GamePassDefinition } = {
	AutoCiderPass = {
		id = "AutoCiderPass",
		displayName = "Auto Cider",
		gamePassId = 1861793571,
		cashMultiplier = nil,
	},
	Cash2x = {
		id = "Cash2x",
		displayName = "2x Cash",
		gamePassId = 1862816353,
		cashMultiplier = 2,
	},
	Cash3x = {
		id = "Cash3x",
		displayName = "3x Cash",
		gamePassId = 1862017586,
		cashMultiplier = 3,
	},
	Cash4x = {
		id = "Cash4x",
		displayName = "4x Cash",
		gamePassId = 1860682896,
		cashMultiplier = 4,
	},
	Cash6x = {
		id = "Cash6x",
		displayName = "6x Cash",
		gamePassId = 1863146224,
		cashMultiplier = 6,
	},
}

local CASH_MULTIPLIER_GAME_PASS_KEYS: { string } = {
	"Cash2x",
	"Cash3x",
	"Cash4x",
	"Cash6x",
}

local GamePassConfig = {}

function GamePassConfig.getDefinition(gamePassKey: string): GamePassDefinition?
	return GAME_PASS_DEFINITIONS[gamePassKey]
end

function GamePassConfig.getCashMultiplierDefinitions(): { GamePassDefinition }
	local definitions: { GamePassDefinition } = {}
	for _, gamePassKey in ipairs(CASH_MULTIPLIER_GAME_PASS_KEYS) do
		local definition = GAME_PASS_DEFINITIONS[gamePassKey]
		assert(definition ~= nil, string.format("%s game pass definition is required", gamePassKey))
		table.insert(definitions, definition)
	end

	return definitions
end

function GamePassConfig.getAutoCiderDefinition(): GamePassDefinition
	local definition = GAME_PASS_DEFINITIONS[AUTO_CIDER_GAME_PASS_KEY]
	assert(definition ~= nil, string.format("%s game pass definition is required", AUTO_CIDER_GAME_PASS_KEY))
	return definition
end

function GamePassConfig.getAllDefinitions(): { [string]: GamePassDefinition }
	return GAME_PASS_DEFINITIONS
end

return table.freeze(GamePassConfig)

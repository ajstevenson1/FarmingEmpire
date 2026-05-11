--!strict

export type SettingId = "Music" | "SFX"

export type SettingDefinition = {
	id: SettingId,
	defaultValue: number,
	step: number,
	soundGroupName: string?,
}

export type SettingsValues = {
	[SettingId]: number,
}

local settingDefinitions: { SettingDefinition } = table.freeze({
	table.freeze({
		id = "Music",
		defaultValue = 0.5,
		step = 0.05,
		soundGroupName = "Music",
	}),
	table.freeze({
		id = "SFX",
		defaultValue = 0.5,
		step = 0.05,
		soundGroupName = "SFX",
	}),
})

local settingDefinitionsById: { [SettingId]: SettingDefinition } = table.freeze({
	Music = settingDefinitions[1],
	SFX = settingDefinitions[2],
})

local SettingsConfig = {}

function SettingsConfig.getSettingDefinition(settingId: SettingId): SettingDefinition
	return settingDefinitionsById[settingId]
end

function SettingsConfig.getAllSettingDefinitions(): { SettingDefinition }
	return settingDefinitions
end

function SettingsConfig.getDefaultValues(): SettingsValues
	return {
		Music = settingDefinitionsById.Music.defaultValue,
		SFX = settingDefinitionsById.SFX.defaultValue,
	}
end

return table.freeze(SettingsConfig)

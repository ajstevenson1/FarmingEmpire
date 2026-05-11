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

function SettingsConfig.isSettingId(value: unknown): boolean
	return type(value) == "string" and settingDefinitionsById[value :: SettingId] ~= nil
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

function SettingsConfig.sanitizeSettingValue(settingId: SettingId, value: unknown): number
	local definition = settingDefinitionsById[settingId]
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return definition.defaultValue
	end

	local clampedValue = math.clamp(value, 0, 1)
	if definition.step <= 0 then
		return clampedValue
	end

	local steppedValue = math.round(clampedValue / definition.step) * definition.step
	return math.clamp(steppedValue, 0, 1)
end

function SettingsConfig.sanitizeValues(values: unknown): SettingsValues
	local rawValues: { [string]: unknown } = {}
	if type(values) == "table" then
		rawValues = values :: { [string]: unknown }
	end

	return {
		Music = SettingsConfig.sanitizeSettingValue("Music", rawValues.Music),
		SFX = SettingsConfig.sanitizeSettingValue("SFX", rawValues.SFX),
	}
end

return table.freeze(SettingsConfig)

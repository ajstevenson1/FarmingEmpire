--!strict

export type FormatMode = "Full" | "Abbreviated"

export type FormatOptions = {
	decimalPlaces: number?,
	trimTrailingZeros: boolean?,
}

type SuffixDefinition = {
	exponent: number,
	suffix: string,
}

local DEFAULT_DECIMAL_PLACES = 2
local MIN_DECIMAL_PLACES = 0
local MAX_DECIMAL_PLACES = 6

local ABBREVIATED_SUFFIXES: { SuffixDefinition } = table.freeze({
	{ exponent = 3, suffix = "K" },
	{ exponent = 6, suffix = "M" },
	{ exponent = 9, suffix = "B" },
	{ exponent = 12, suffix = "T" },
	{ exponent = 15, suffix = "Qa" },
	{ exponent = 18, suffix = "Qi" },
	{ exponent = 21, suffix = "Sx" },
	{ exponent = 24, suffix = "Sp" },
	{ exponent = 27, suffix = "Oc" },
	{ exponent = 30, suffix = "No" },
	{ exponent = 33, suffix = "Dc" },
	{ exponent = 36, suffix = "Ud" },
	{ exponent = 39, suffix = "Dd" },
	{ exponent = 42, suffix = "Td" },
	{ exponent = 45, suffix = "Qad" },
	{ exponent = 48, suffix = "Qid" },
	{ exponent = 51, suffix = "Sxd" },
	{ exponent = 54, suffix = "Spd" },
	{ exponent = 57, suffix = "Ocd" },
	{ exponent = 60, suffix = "Nod" },
	{ exponent = 63, suffix = "Vg" },
})

local NumberFormatter = {}

local function sanitizeFiniteNumber(value: number): number
	if value ~= value then
		return 0
	end

	if value == math.huge then
		return math.huge
	end

	if value == -math.huge then
		return -math.huge
	end

	return value
end

local function getAbsoluteIntegerText(value: number): string
	local sanitizedValue = sanitizeFiniteNumber(value)
	if sanitizedValue == math.huge then
		return "inf"
	end

	if sanitizedValue == -math.huge then
		return "-inf"
	end

	return string.format("%.0f", math.floor(math.abs(sanitizedValue)))
end

local function addCommas(integerText: string): string
	local reversedText = string.reverse(integerText)
	local chunks: { string } = {}

	for startIndex = 1, #reversedText, 3 do
		table.insert(chunks, string.sub(reversedText, startIndex, startIndex + 2))
	end

	return string.reverse(table.concat(chunks, ","))
end

local function getDecimalPlaces(options: FormatOptions?): number
	if options == nil or options.decimalPlaces == nil then
		return DEFAULT_DECIMAL_PLACES
	end

	return math.clamp(math.floor(options.decimalPlaces), MIN_DECIMAL_PLACES, MAX_DECIMAL_PLACES)
end

local function shouldTrimTrailingZeros(options: FormatOptions?): boolean
	if options == nil or options.trimTrailingZeros == nil then
		return true
	end

	return options.trimTrailingZeros
end

local function trimTrailingZeros(text: string): string
	local trimmedText = string.gsub(text, "0+$", "")
	trimmedText = string.gsub(trimmedText, "%.$", "")
	return trimmedText
end

local function getSignPrefix(value: number, displayedMagnitude: number): string
	return if value < 0 and displayedMagnitude > 0 then "-" else ""
end

function NumberFormatter.formatFull(value: number): string
	local sanitizedValue = sanitizeFiniteNumber(value)
	local absoluteValue = math.floor(math.abs(sanitizedValue))
	local integerText = getAbsoluteIntegerText(sanitizedValue)
	if integerText == "inf" or integerText == "-inf" then
		return integerText
	end

	return getSignPrefix(sanitizedValue, absoluteValue) .. addCommas(integerText)
end

function NumberFormatter.formatAbbreviated(value: number, options: FormatOptions?): string
	local sanitizedValue = sanitizeFiniteNumber(value)
	if sanitizedValue == math.huge then
		return "inf"
	end

	if sanitizedValue == -math.huge then
		return "-inf"
	end

	local absoluteValue = math.floor(math.abs(sanitizedValue))
	if absoluteValue < 1000 then
		return getSignPrefix(sanitizedValue, absoluteValue) .. tostring(absoluteValue)
	end

	local suffixDefinition = ABBREVIATED_SUFFIXES[#ABBREVIATED_SUFFIXES]
	for index = #ABBREVIATED_SUFFIXES, 1, -1 do
		local candidate = ABBREVIATED_SUFFIXES[index]
		if absoluteValue >= 10 ^ candidate.exponent then
			suffixDefinition = candidate
			break
		end
	end

	if absoluteValue >= 10 ^ (suffixDefinition.exponent + 3) then
		return string.format("%s%.2e", getSignPrefix(sanitizedValue, absoluteValue), absoluteValue)
	end

	local decimalPlaces = getDecimalPlaces(options)
	local formatString = "%." .. tostring(decimalPlaces) .. "f"
	local abbreviatedText = string.format(formatString, absoluteValue / (10 ^ suffixDefinition.exponent))

	if shouldTrimTrailingZeros(options) then
		abbreviatedText = trimTrailingZeros(abbreviatedText)
	end

	return getSignPrefix(sanitizedValue, absoluteValue) .. abbreviatedText .. suffixDefinition.suffix
end

function NumberFormatter.format(value: number, mode: FormatMode, options: FormatOptions?): string
	if mode == "Full" then
		return NumberFormatter.formatFull(value)
	end

	return NumberFormatter.formatAbbreviated(value, options)
end

return table.freeze(NumberFormatter)

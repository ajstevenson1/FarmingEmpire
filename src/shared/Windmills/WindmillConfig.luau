--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)

type BuildingId = BuildingTypes.BuildingId

export type WindmillCategory = "Cash" | "Offline"

export type WindmillBoostConfig = {
	offlineEarningsMultiplierBonus: number,
	ciderSellCashMultiplierBonus: number,
}

export type WindmillDefinition = {
	id: BuildingId,
	category: WindmillCategory,
	displayName: string,
	description: string,
	price: number,
	sellPrice: number,
	stockPerRestock: number,
	placementSize: Vector3,
	boosts: WindmillBoostConfig,
}

local WINDMILL_PLACEMENT_SIZE = Vector3.new(6, 8, 6)

local function createWindmillDefinition(
	id: BuildingId,
	category: WindmillCategory,
	displayName: string,
	description: string,
	price: number,
	offlineEarningsMultiplierBonus: number,
	ciderSellCashMultiplierBonus: number
): WindmillDefinition
	return table.freeze({
		id = id,
		category = category,
		displayName = displayName,
		description = description,
		price = price,
		sellPrice = math.floor(price * 0.5),
		stockPerRestock = 3,
		placementSize = WINDMILL_PLACEMENT_SIZE,
		boosts = table.freeze({
			offlineEarningsMultiplierBonus = offlineEarningsMultiplierBonus,
			ciderSellCashMultiplierBonus = ciderSellCashMultiplierBonus,
		}),
	})
end

local windmillDefinitions: { WindmillDefinition } = table.freeze({
	createWindmillDefinition(
		"OfflineEarningsWindmill",
		"Offline",
		"Basic AFK Windmill",
		"Boosts offline cider earnings by 25%.",
		1000,
		0.25,
		0
	),
	createWindmillDefinition(
		"CiderCashWindmill",
		"Cash",
		"Cash Windmill",
		"Boosts cash earned from selling cider by 25%.",
		500,
		0,
		0.25
	),
})

local windmillDefinitionsById: { [BuildingId]: WindmillDefinition } = {}
local windmillBuildingIds: { [string]: boolean } = {}

for _, windmillDefinition in ipairs(windmillDefinitions) do
	windmillDefinitionsById[windmillDefinition.id] = windmillDefinition
	windmillBuildingIds[windmillDefinition.id] = true
end

local function getSafeBonus(bonus: number): number
	if bonus ~= bonus or bonus == math.huge or bonus == -math.huge or bonus < 0 then
		return 0
	end

	return bonus
end

local WindmillConfig = {}

function WindmillConfig.getDefinitions(): { WindmillDefinition }
	return windmillDefinitions
end

function WindmillConfig.getDefinition(windmillId: BuildingId): WindmillDefinition?
	return windmillDefinitionsById[windmillId]
end

function WindmillConfig.isWindmillBuildingId(buildingId: string): boolean
	return windmillBuildingIds[buildingId] == true
end

function WindmillConfig.getOfflineEarningsMultiplierBonus(buildingId: BuildingId): number
	local definition = windmillDefinitionsById[buildingId]
	return if definition == nil then 0 else getSafeBonus(definition.boosts.offlineEarningsMultiplierBonus)
end

function WindmillConfig.getCiderSellCashMultiplierBonus(buildingId: BuildingId): number
	local definition = windmillDefinitionsById[buildingId]
	return if definition == nil then 0 else getSafeBonus(definition.boosts.ciderSellCashMultiplierBonus)
end

return table.freeze(WindmillConfig)

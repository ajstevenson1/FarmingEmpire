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
	visualAssetName: string,
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
	visualAssetName: string,
	price: number,
	offlineEarningsMultiplierBonus: number,
	ciderSellCashMultiplierBonus: number
): WindmillDefinition
	return table.freeze({
		id = id,
		category = category,
		displayName = displayName,
		description = description,
		visualAssetName = visualAssetName,
		price = price,
		sellPrice = 0,
		stockPerRestock = 1,
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
		"Old AFK Windmill",
		"Boosts offline juice earnings by 10%.",
		"OldWindmill",
		1000,
		0.1,
		0
	),
	createWindmillDefinition(
		"ModernAFKWindmill",
		"Offline",
		"Modern AFK Windmill",
		"Boosts offline juice earnings by 30%.",
		"ModernWindmill",
		15000,
		0.3,
		0
	),
	createWindmillDefinition(
		"GoldAFKWindmill",
		"Offline",
		"Gold AFK Windmill",
		"Boosts offline juice earnings by 70%.",
		"GoldWindmill",
		225000,
		0.7,
		0
	),
	createWindmillDefinition(
		"DiamondAFKWindmill",
		"Offline",
		"Diamond AFK Windmill",
		"Boosts offline juice earnings by 120%.",
		"DiamondWindmill",
		1500000,
		1.2,
		0
	),
	createWindmillDefinition(
		"CiderCashWindmill",
		"Cash",
		"Old Cash Windmill",
		"Boosts cash earned from selling juice by 10%.",
		"OldWindmill",
		2500,
		0,
		0.1
	),
	createWindmillDefinition(
		"ModernCashWindmill",
		"Cash",
		"Modern Cash Windmill",
		"Boosts cash earned from selling juice by 30%.",
		"ModernWindmill",
		45000,
		0,
		0.3
	),
	createWindmillDefinition(
		"GoldCashWindmill",
		"Cash",
		"Gold Cash Windmill",
		"Boosts cash earned from selling juice by 70%.",
		"GoldWindmill",
		570000,
		0,
		0.7
	),
	createWindmillDefinition(
		"DiamondCashWindmill",
		"Cash",
		"Diamond Cash Windmill",
		"Boosts cash earned from selling juice by 120%.",
		"DiamondWindmill",
		2800000,
		0,
		1.2
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

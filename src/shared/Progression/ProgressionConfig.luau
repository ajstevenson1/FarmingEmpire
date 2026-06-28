--!strict

local buildingsFolder = script.Parent.Parent:WaitForChild("Buildings") :: Folder
local shopsFolder = script.Parent.Parent:WaitForChild("Shops") :: Folder

local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local ShopTypes = require(shopsFolder:WaitForChild("ShopTypes") :: ModuleScript)

type BuildingId = BuildingTypes.BuildingId
type ShopStockRollConfig = ShopTypes.ShopStockRollConfig

local TREE_PRODUCE_INTERVAL_SECONDS = 1

export type TreeTierDefinition = {
	id: BuildingId,
	displayName: string,
	description: string,
	price: number,
	sellPrice: number,
	appleModelName: string,
	fruitPerInterval: number,
	storageCap: number,
	offlineCiderPerSecond: number,
	stock: ShopStockRollConfig,
}

export type MillTierDefinition = {
	id: BuildingId,
	displayName: string,
	description: string,
	price: number,
	sellPrice: number,
	inputAmount: number,
	outputAmount: number,
	offlineCiderPerSecond: number,
	stock: ShopStockRollConfig,
}

local function stock(appearanceChance: number, minQuantity: number, maxQuantity: number): ShopStockRollConfig
	return table.freeze({
		appearanceChance = appearanceChance,
		minQuantity = minQuantity,
		maxQuantity = maxQuantity,
	})
end

local function createTreeTier(
	id: BuildingId,
	displayName: string,
	appleModelName: string,
	price: number,
	fruitPerInterval: number,
	storageCap: number,
	offlineCiderPerSecond: number,
	stockConfig: ShopStockRollConfig
): TreeTierDefinition
	return table.freeze({
		id = id,
		displayName = displayName,
		description = string.format("Produces %d apples every %d second.", fruitPerInterval, TREE_PRODUCE_INTERVAL_SECONDS),
		price = price,
		sellPrice = math.floor(price * 0.5),
		appleModelName = appleModelName,
		fruitPerInterval = fruitPerInterval,
		storageCap = storageCap,
		offlineCiderPerSecond = offlineCiderPerSecond,
		stock = stockConfig,
	})
end

local function createMillTier(
	id: BuildingId,
	displayName: string,
	price: number,
	inputAmount: number,
	outputAmount: number,
	offlineCiderPerSecond: number,
	stockConfig: ShopStockRollConfig
): MillTierDefinition
	return table.freeze({
		id = id,
		displayName = displayName,
		description = string.format("Processes %d apples into %d cider each second.", inputAmount, outputAmount),
		price = price,
		sellPrice = math.floor(price * 0.5),
		inputAmount = inputAmount,
		outputAmount = outputAmount,
		offlineCiderPerSecond = offlineCiderPerSecond,
		stock = stockConfig,
	})
end

local treeDefinitions: { TreeTierDefinition } = table.freeze({
	createTreeTier("OakTree", "Oak Apple Tree", "Apple", 100, 2, 10, 0.05, stock(1, 8, 12)),
	createTreeTier("BirchTree", "Birch Apple Tree", "BirchApple", 500, 5, 25, 0.1, stock(0.95, 7, 10)),
	createTreeTier("CherryTree", "Cherry Apple Tree", "CherryApple", 1800, 12, 84, 0.2, stock(0.85, 5, 8)),
	createTreeTier("GoldenTree", "Golden Apple Tree", "GoldenApple", 6000, 18, 144, 0.35, stock(0.75, 4, 7)),
	createTreeTier("EmeraldTree", "Emerald Apple Tree", "EmeraldApple", 20000, 25, 250, 0.55, stock(0.65, 3, 5)),
	createTreeTier("SapphireTree", "Sapphire Apple Tree", "SapphireApple", 100000, 45, 540, 0.85, stock(0.55, 2, 4)),
	createTreeTier("DiamondTree", "Diamond Apple Tree", "DiamondApple", 280000, 65, 780, 1.25, stock(0.45, 2, 4)),
	createTreeTier("InfernoTree", "Inferno Apple Tree", "InfernoApple", 820000, 85, 1020, 1.8, stock(0.35, 1, 3)),
	createTreeTier("FrostbiteTree", "Frostbite Apple Tree", "FrostbiteApple", 2000000, 115, 1610, 2.5, stock(0.3, 1, 3)),
	createTreeTier("VoidfruitTree", "Voidfruit Apple Tree", "VoidApple", 12000000, 140, 1960, 3.4, stock(0.25, 1, 2)),
	createTreeTier("FalloutTree", "Fallout Apple Tree", "FalloutApple", 40000000, 180, 2700, 4.5, stock(0.2, 1, 2)),
	createTreeTier("RainbowPrismTree", "Rainbow Prism Apple Tree", "RainbowPrismApple", 230000000, 230, 3450, 5.9, stock(0.16, 1, 1)),
	createTreeTier("GhostwoodTree", "Ghostwood Apple Tree", "GhostwoodApple", 870000000, 290, 4350, 7.65, stock(0.12, 1, 1)),
	createTreeTier("CandyTree", "Candy Apple Tree", "CandyApple", 2300000000, 350, 5250, 9.85, stock(0.09, 1, 1)),
	createTreeTier("CyberTree", "Cyber Apple Tree", "CyberApple", 10000000000, 500, 7500, 12.6, stock(0.06, 1, 1)),
	createTreeTier("PatriotTree", "Patriot Tree", "PatriotApple", 0, 125, 1750, 0, stock(0, 0, 0)),
})

local millDefinitions: { MillTierDefinition } = table.freeze({
	createMillTier("CiderMill", "Cider Mill", 100, 1, 1, 0.1, stock(1, 4, 6)),
	createMillTier("CopperCiderMill", "Copper Cider Mill", 500, 2, 2, 0.2, stock(0.9, 3, 5)),
	createMillTier("SteelCiderMill", "Steel Cider Mill", 2500, 4, 4, 0.4, stock(0.8, 2, 4)),
	createMillTier("PlatinumCiderMill", "Platinum Cider Mill", 8500, 8, 8, 0.8, stock(0.7, 2, 4)),
	createMillTier("DiamondCiderMill", "Diamond Cider Mill", 21000, 16, 16, 1.3, stock(0.6, 1, 3)),
	createMillTier("RoyalCiderMill", "Royal Cider Mill", 80000, 35, 35, 2.1, stock(0.5, 1, 3)),
	createMillTier("IndustrialCiderMill", "Industrial Cider Mill", 225000, 75, 75, 3.2, stock(0.4, 1, 2)),
	createMillTier("AdvancedCiderMill", "Advanced Cider Mill", 570000, 100, 100, 4.7, stock(0.35, 1, 1)),
	createMillTier("MagmaCiderMill", "Magma Cider Mill", 1800000, 130, 130, 6.7, stock(0.3, 1, 1)),
	createMillTier("WastelandCiderMill", "Wasteland Cider Mill", 6500000, 170, 170, 9.2, stock(0.25, 1, 1)),
	createMillTier("AncientCiderMill", "Ancient Cider Mill", 28000000, 220, 220, 12.3, stock(0.2, 1, 1)),
	createMillTier("TitanCiderMill", "Titan Cider Mill", 110000000, 260, 260, 16.4, stock(0.16, 1, 1)),
	createMillTier("QuantumReactorMill", "Quantum Reactor Mill", 340000000, 320, 320, 21.4, stock(0.12, 1, 1)),
	createMillTier("DyingForgeMill", "Dying Forge Mill", 1050000000, 400, 400, 28.1, stock(0.09, 1, 1)),
	createMillTier("DeepSpaceMill", "Deep Space Mill", 7200000000, 500, 500, 36.3, stock(0.06, 1, 1)),
})

local treeBuildingIds: { [string]: boolean } = {}
for _, treeDefinition in ipairs(treeDefinitions) do
	treeBuildingIds[treeDefinition.id] = true
end

local millBuildingIds: { [string]: boolean } = {}
for _, millDefinition in ipairs(millDefinitions) do
	millBuildingIds[millDefinition.id] = true
end

local ProgressionConfig = {}

function ProgressionConfig.getTreeDefinitions(): { TreeTierDefinition }
	return treeDefinitions
end

function ProgressionConfig.getMillDefinitions(): { MillTierDefinition }
	return millDefinitions
end

function ProgressionConfig.getTreeProduceIntervalSeconds(): number
	return TREE_PRODUCE_INTERVAL_SECONDS
end

function ProgressionConfig.isTreeBuildingId(buildingId: string): boolean
	return treeBuildingIds[buildingId] == true
end

function ProgressionConfig.isMillBuildingId(buildingId: string): boolean
	return millBuildingIds[buildingId] == true
end

return table.freeze(ProgressionConfig)

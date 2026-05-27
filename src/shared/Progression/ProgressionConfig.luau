--!strict

local buildingsFolder = script.Parent.Parent:WaitForChild("Buildings") :: Folder

local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)

type BuildingId = BuildingTypes.BuildingId

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
	stockPerRestock: number,
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
	stockPerRestock: number,
}

local function createTreeTier(
	id: BuildingId,
	displayName: string,
	appleModelName: string,
	price: number,
	fruitPerInterval: number,
	storageCap: number,
	offlineCiderPerSecond: number,
	stockPerRestock: number
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
		stockPerRestock = stockPerRestock,
	})
end

local function createMillTier(
	id: BuildingId,
	displayName: string,
	price: number,
	inputAmount: number,
	outputAmount: number,
	offlineCiderPerSecond: number,
	stockPerRestock: number
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
		stockPerRestock = stockPerRestock,
	})
end

local treeDefinitions: { TreeTierDefinition } = table.freeze({
	createTreeTier("OakTree", "Oak Apple Tree", "Apple", 100, 2, 10, 0.05, 10),
	createTreeTier("BirchTree", "Birch Apple Tree", "BirchApple", 500, 5, 25, 0.1, 8),
	createTreeTier("CherryTree", "Cherry Apple Tree", "CherryApple", 1800, 12, 84, 0.2, 6),
	createTreeTier("GoldenTree", "Golden Apple Tree", "GoldenApple", 6000, 18, 144, 0.35, 5),
	createTreeTier("EmeraldTree", "Emerald Apple Tree", "EmeraldApple", 20000, 25, 250, 0.55, 4),
	createTreeTier("SapphireTree", "Sapphire Apple Tree", "SapphireApple", 100000, 33, 363, 0.85, 3),
	createTreeTier("DiamondTree", "Diamond Apple Tree", "DiamondApple", 280000, 42, 504, 1.25, 3),
	createTreeTier("InfernoTree", "Inferno Apple Tree", "InfernoApple", 820000, 55, 715, 1.8, 2),
	createTreeTier("FrostbiteTree", "Frostbite Apple Tree", "FrostbiteApple", 2000000, 65, 975, 2.5, 2),
	createTreeTier("VoidfruitTree", "Voidfruit Apple Tree", "VoidApple", 12000000, 75, 1250, 3.4, 2),
	createTreeTier("FalloutTree", "Fallout Apple Tree", "FalloutApple", 40000000, 90, 1800, 4.5, 1),
	createTreeTier("RainbowPrismTree", "Rainbow Prism Apple Tree", "RainbowPrismApple", 230000000, 110, 2750, 5.9, 1),
	createTreeTier("GhostwoodTree", "Ghostwood Apple Tree", "GhostwoodApple", 870000000, 125, 3750, 7.65, 1),
	createTreeTier("CandyTree", "Candy Apple Tree", "CandyApple", 2300000000, 150, 4500, 9.85, 1),
	createTreeTier("CyberTree", "Cyber Apple Tree", "CyberApple", 10000000000, 200, 6000, 12.6, 1),
})

local millDefinitions: { MillTierDefinition } = table.freeze({
	createMillTier("CiderMill", "Cider Mill", 100, 1, 1, 0.1, 5),
	createMillTier("CopperCiderMill", "Copper Cider Mill", 500, 2, 2, 0.2, 4),
	createMillTier("SteelCiderMill", "Steel Cider Mill", 2500, 4, 4, 0.4, 3),
	createMillTier("PlatinumCiderMill", "Platinum Cider Mill", 8500, 8, 8, 0.8, 3),
	createMillTier("DiamondCiderMill", "Diamond Cider Mill", 21000, 12, 12, 1.3, 2),
	createMillTier("RoyalCiderMill", "Royal Cider Mill", 80000, 20, 20, 2.1, 2),
	createMillTier("IndustrialCiderMill", "Industrial Cider Mill", 225000, 28, 28, 3.2, 2),
	createMillTier("AdvancedCiderMill", "Advanced Cider Mill", 570000, 35, 35, 4.7, 1),
	createMillTier("MagmaCiderMill", "Magma Cider Mill", 1800000, 45, 45, 6.7, 1),
	createMillTier("WastelandCiderMill", "Wasteland Cider Mill", 6500000, 58, 58, 9.2, 1),
	createMillTier("AncientCiderMill", "Ancient Cider Mill", 28000000, 70, 70, 12.3, 1),
	createMillTier("TitanCiderMill", "Titan Cider Mill", 110000000, 92, 92, 16.4, 1),
	createMillTier("QuantumReactorMill", "Quantum Reactor Mill", 340000000, 115, 115, 21.4, 1),
	createMillTier("DyingForgeMill", "Dying Forge Mill", 1050000000, 140, 140, 28.1, 1),
	createMillTier("DeepSpaceMill", "Deep Space Mill", 7200000000, 200, 200, 36.3, 1),
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

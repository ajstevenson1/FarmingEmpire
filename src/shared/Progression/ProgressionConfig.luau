--!strict

local buildingsFolder = script.Parent.Parent:WaitForChild("Buildings") :: Folder

local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)

type BuildingId = BuildingTypes.BuildingId

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
	unlockLifetimeCash: number,
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
	unlockLifetimeCash: number,
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
	unlockLifetimeCash: number,
	stockPerRestock: number
): TreeTierDefinition
	return table.freeze({
		id = id,
		displayName = displayName,
		description = string.format("Produces %d apples every 5 seconds.", fruitPerInterval),
		price = price,
		sellPrice = math.floor(price * 0.5),
		appleModelName = appleModelName,
		fruitPerInterval = fruitPerInterval,
		storageCap = storageCap,
		offlineCiderPerSecond = offlineCiderPerSecond,
		unlockLifetimeCash = unlockLifetimeCash,
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
	unlockLifetimeCash: number,
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
		unlockLifetimeCash = unlockLifetimeCash,
		stockPerRestock = stockPerRestock,
	})
end

local treeDefinitions: { TreeTierDefinition } = table.freeze({
	createTreeTier("OakTree", "Oak Apple Tree", "Apple", 500, 1, 12, 0.05, 0, 10),
	createTreeTier("BirchTree", "Birch Apple Tree", "BirchApple", 1250, 2, 20, 0.1, 1500, 8),
	createTreeTier("CherryTree", "Cherry Apple Tree", "CherryApple", 3200, 4, 30, 0.2, 6000, 6),
	createTreeTier("GoldenTree", "Golden Apple Tree", "GoldenApple", 8000, 7, 45, 0.35, 20000, 5),
	createTreeTier("EmeraldTree", "Emerald Apple Tree", "EmeraldApple", 20000, 11, 65, 0.55, 60000, 4),
	createTreeTier("SapphireTree", "Sapphire Apple Tree", "SapphireApple", 48000, 17, 90, 0.85, 180000, 3),
	createTreeTier("DiamondTree", "Diamond Apple Tree", "DiamondApple", 115000, 25, 125, 1.25, 500000, 3),
	createTreeTier("InfernoTree", "Inferno Apple Tree", "InfernoApple", 275000, 36, 170, 1.8, 1500000, 2),
	createTreeTier("FrostbiteTree", "Frostbite Apple Tree", "FrostbiteApple", 650000, 50, 230, 2.5, 4500000, 2),
	createTreeTier("VoidfruitTree", "Voidfruit Apple Tree", "VoidApple", 1500000, 68, 310, 3.4, 12000000, 2),
	createTreeTier("FalloutTree", "Fallout Apple Tree", "FalloutApple", 3500000, 90, 420, 4.5, 35000000, 1),
	createTreeTier("RainbowPrismTree", "Rainbow Prism Apple Tree", "RainbowPrismApple", 8000000, 118, 560, 5.9, 100000000, 1),
	createTreeTier("GhostwoodTree", "Ghostwood Apple Tree", "GhostwoodApple", 18000000, 153, 740, 7.65, 280000000, 1),
	createTreeTier("CandyTree", "Candy Apple Tree", "CandyApple", 40000000, 197, 970, 9.85, 800000000, 1),
	createTreeTier("CyberTree", "Cyber Apple Tree", "CyberApple", 90000000, 252, 1260, 12.6, 2200000000, 1),
})

local millDefinitions: { MillTierDefinition } = table.freeze({
	createMillTier("CiderMill", "Cider Mill", 500, 1, 1, 0.1, 0, 5),
	createMillTier("CopperCiderMill", "Copper Cider Mill", 1250, 2, 2, 0.2, 1500, 4),
	createMillTier("SteelCiderMill", "Steel Cider Mill", 3200, 4, 4, 0.4, 6000, 3),
	createMillTier("PlatinumCiderMill", "Platinum Cider Mill", 8500, 7, 8, 0.8, 20000, 3),
	createMillTier("DiamondCiderMill", "Diamond Cider Mill", 21000, 11, 13, 1.3, 60000, 2),
	createMillTier("RoyalCiderMill", "Royal Cider Mill", 52000, 17, 21, 2.1, 180000, 2),
	createMillTier("IndustrialCiderMill", "Industrial Cider Mill", 125000, 25, 32, 3.2, 500000, 2),
	createMillTier("AdvancedCiderMill", "Advanced Cider Mill", 300000, 36, 47, 4.7, 1500000, 1),
	createMillTier("MagmaCiderMill", "Magma Cider Mill", 700000, 50, 67, 6.7, 4500000, 1),
	createMillTier("WastelandCiderMill", "Wasteland Cider Mill", 1600000, 68, 92, 9.2, 12000000, 1),
	createMillTier("AncientCiderMill", "Ancient Cider Mill", 3700000, 90, 123, 12.3, 35000000, 1),
	createMillTier("TitanCiderMill", "Titan Cider Mill", 8500000, 118, 164, 16.4, 100000000, 1),
	createMillTier("QuantumReactorMill", "Quantum Reactor Mill", 19000000, 153, 214, 21.4, 280000000, 1),
	createMillTier("DyingForgeMill", "Dying Forge Mill", 43000000, 197, 281, 28.1, 800000000, 1),
	createMillTier("DeepSpaceMill", "Deep Space Mill", 95000000, 252, 363, 36.3, 2200000000, 1),
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

function ProgressionConfig.isTreeBuildingId(buildingId: string): boolean
	return treeBuildingIds[buildingId] == true
end

function ProgressionConfig.isMillBuildingId(buildingId: string): boolean
	return millBuildingIds[buildingId] == true
end

return table.freeze(ProgressionConfig)

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
	fruitPerInterval: number,
	storageCap: number,
	offlineCiderPerSecond: number,
	unlockLifetimeCash: number,
	stockPerRestock: number,
	leafColor: Color3,
	fruitColor: Color3,
	fallbackColor: Color3,
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
	accentColor: Color3,
	fallbackColor: Color3,
}

local function createTreeTier(
	id: BuildingId,
	displayName: string,
	price: number,
	fruitPerInterval: number,
	storageCap: number,
	offlineCiderPerSecond: number,
	unlockLifetimeCash: number,
	stockPerRestock: number,
	leafColor: Color3,
	fruitColor: Color3,
	fallbackColor: Color3
): TreeTierDefinition
	return table.freeze({
		id = id,
		displayName = displayName,
		description = string.format("Produces %d %s apples every 5 seconds.", fruitPerInterval, displayName),
		price = price,
		sellPrice = math.floor(price * 0.5),
		fruitPerInterval = fruitPerInterval,
		storageCap = storageCap,
		offlineCiderPerSecond = offlineCiderPerSecond,
		unlockLifetimeCash = unlockLifetimeCash,
		stockPerRestock = stockPerRestock,
		leafColor = leafColor,
		fruitColor = fruitColor,
		fallbackColor = fallbackColor,
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
	stockPerRestock: number,
	accentColor: Color3,
	fallbackColor: Color3
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
		accentColor = accentColor,
		fallbackColor = fallbackColor,
	})
end

local treeDefinitions: { TreeTierDefinition } = table.freeze({
	createTreeTier("OakTree", "Oak", 500, 1, 12, 0.05, 0, 10, Color3.fromRGB(88, 145, 71), Color3.fromRGB(201, 74, 58), Color3.fromRGB(109, 85, 59)),
	createTreeTier("BirchTree", "Birch", 1250, 2, 20, 0.1, 1500, 8, Color3.fromRGB(165, 190, 120), Color3.fromRGB(234, 220, 120), Color3.fromRGB(190, 193, 163)),
	createTreeTier("CherryTree", "Cherry", 3200, 4, 30, 0.2, 6000, 6, Color3.fromRGB(181, 92, 130), Color3.fromRGB(231, 63, 88), Color3.fromRGB(125, 78, 98)),
	createTreeTier("GoldenTree", "Golden", 8000, 7, 45, 0.35, 20000, 5, Color3.fromRGB(224, 183, 63), Color3.fromRGB(255, 223, 104), Color3.fromRGB(190, 152, 50)),
	createTreeTier("EmeraldTree", "Emerald", 20000, 11, 65, 0.55, 60000, 4, Color3.fromRGB(66, 173, 112), Color3.fromRGB(113, 230, 159), Color3.fromRGB(48, 122, 81)),
	createTreeTier("SapphireTree", "Sapphire", 48000, 17, 90, 0.85, 180000, 3, Color3.fromRGB(58, 112, 201), Color3.fromRGB(116, 176, 255), Color3.fromRGB(52, 79, 138)),
	createTreeTier("DiamondTree", "Diamond", 115000, 25, 125, 1.25, 500000, 3, Color3.fromRGB(179, 233, 241), Color3.fromRGB(239, 252, 255), Color3.fromRGB(123, 176, 184)),
	createTreeTier("InfernoTree", "Inferno", 275000, 36, 170, 1.8, 1500000, 2, Color3.fromRGB(164, 68, 34), Color3.fromRGB(250, 125, 54), Color3.fromRGB(111, 47, 28)),
	createTreeTier("FrostbiteTree", "Frostbite", 650000, 50, 230, 2.5, 4500000, 2, Color3.fromRGB(164, 221, 250), Color3.fromRGB(221, 244, 255), Color3.fromRGB(118, 168, 191)),
	createTreeTier("VoidfruitTree", "Voidfruit", 1500000, 68, 310, 3.4, 12000000, 2, Color3.fromRGB(84, 64, 129), Color3.fromRGB(162, 111, 255), Color3.fromRGB(52, 42, 82)),
	createTreeTier("FalloutTree", "Fallout", 3500000, 90, 420, 4.5, 35000000, 1, Color3.fromRGB(125, 165, 55), Color3.fromRGB(195, 233, 74), Color3.fromRGB(81, 106, 41)),
	createTreeTier("RainbowPrismTree", "Rainbow Prism", 8000000, 118, 560, 5.9, 100000000, 1, Color3.fromRGB(132, 115, 220), Color3.fromRGB(255, 120, 185), Color3.fromRGB(203, 169, 89)),
	createTreeTier("GhostwoodTree", "Ghostwood", 18000000, 153, 740, 7.65, 280000000, 1, Color3.fromRGB(188, 210, 213), Color3.fromRGB(230, 244, 246), Color3.fromRGB(144, 161, 166)),
	createTreeTier("CandyTree", "Candy", 40000000, 197, 970, 9.85, 800000000, 1, Color3.fromRGB(252, 154, 191), Color3.fromRGB(255, 209, 101), Color3.fromRGB(197, 117, 149)),
	createTreeTier("CyberTree", "Cyber", 90000000, 252, 1260, 12.6, 2200000000, 1, Color3.fromRGB(41, 201, 173), Color3.fromRGB(100, 255, 221), Color3.fromRGB(35, 111, 103)),
})

local millDefinitions: { MillTierDefinition } = table.freeze({
	createMillTier("CiderMill", "Cider Mill", 500, 1, 1, 0.1, 0, 5, Color3.fromRGB(150, 88, 44), Color3.fromRGB(117, 72, 43)),
	createMillTier("CopperCiderMill", "Copper Cider Mill", 1250, 2, 2, 0.2, 1500, 4, Color3.fromRGB(196, 108, 50), Color3.fromRGB(171, 95, 51)),
	createMillTier("SteelCiderMill", "Steel Cider Mill", 3200, 4, 4, 0.4, 6000, 3, Color3.fromRGB(142, 151, 158), Color3.fromRGB(116, 128, 135)),
	createMillTier("PlatinumCiderMill", "Platinum Cider Mill", 8500, 7, 8, 0.8, 20000, 3, Color3.fromRGB(180, 190, 207), Color3.fromRGB(131, 139, 157)),
	createMillTier("DiamondCiderMill", "Diamond Cider Mill", 21000, 11, 13, 1.3, 60000, 2, Color3.fromRGB(131, 225, 255), Color3.fromRGB(84, 157, 193)),
	createMillTier("RoyalCiderMill", "Royal Cider Mill", 52000, 17, 21, 2.1, 180000, 2, Color3.fromRGB(135, 77, 183), Color3.fromRGB(196, 159, 62)),
	createMillTier("IndustrialCiderMill", "Industrial Cider Mill", 125000, 25, 32, 3.2, 500000, 2, Color3.fromRGB(191, 134, 56), Color3.fromRGB(104, 98, 90)),
	createMillTier("AdvancedCiderMill", "Advanced Cider Mill", 300000, 36, 47, 4.7, 1500000, 1, Color3.fromRGB(87, 173, 224), Color3.fromRGB(64, 99, 127)),
	createMillTier("MagmaCiderMill", "Magma Cider Mill", 700000, 50, 67, 6.7, 4500000, 1, Color3.fromRGB(227, 98, 53), Color3.fromRGB(117, 54, 35)),
	createMillTier("WastelandCiderMill", "Wasteland Cider Mill", 1600000, 68, 92, 9.2, 12000000, 1, Color3.fromRGB(147, 160, 71), Color3.fromRGB(95, 90, 62)),
	createMillTier("AncientCiderMill", "Ancient Cider Mill", 3700000, 90, 123, 12.3, 35000000, 1, Color3.fromRGB(182, 162, 101), Color3.fromRGB(120, 97, 57)),
	createMillTier("TitanCiderMill", "Titan Cider Mill", 8500000, 118, 164, 16.4, 100000000, 1, Color3.fromRGB(130, 149, 171), Color3.fromRGB(80, 90, 107)),
	createMillTier("QuantumReactorMill", "Quantum Reactor Mill", 19000000, 153, 214, 21.4, 280000000, 1, Color3.fromRGB(80, 236, 255), Color3.fromRGB(54, 84, 124)),
	createMillTier("DyingForgeMill", "Dying Forge Mill", 43000000, 197, 281, 28.1, 800000000, 1, Color3.fromRGB(255, 152, 71), Color3.fromRGB(120, 62, 41)),
	createMillTier("DeepSpaceMill", "Deep Space Mill", 95000000, 252, 363, 36.3, 2200000000, 1, Color3.fromRGB(121, 117, 240), Color3.fromRGB(56, 57, 116)),
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

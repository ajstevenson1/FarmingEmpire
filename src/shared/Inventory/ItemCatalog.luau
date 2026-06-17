--!strict

local InventoryTypes = require(script.Parent.InventoryTypes)
local progressionFolder = script.Parent.Parent:WaitForChild("Progression") :: Folder
local windmillsFolder = script.Parent.Parent:WaitForChild("Windmills") :: Folder
local ProgressionConfig = require(progressionFolder:WaitForChild("ProgressionConfig") :: ModuleScript)
local WindmillConfig = require(windmillsFolder:WaitForChild("WindmillConfig") :: ModuleScript)

type ItemDefinition = InventoryTypes.ItemDefinition
type ItemId = InventoryTypes.ItemId
type MillTierDefinition = ProgressionConfig.MillTierDefinition
type TreeTierDefinition = ProgressionConfig.TreeTierDefinition
type WindmillDefinition = WindmillConfig.WindmillDefinition

local SCYTHE_IMAGE_ASSET_ID = "rbxassetid://86007084151897"
local TREE_IMAGE_ASSET_ID = "rbxassetid://80078631350858"
local MILL_IMAGE_ASSET_ID = "rbxassetid://110522443839275"
local WINDMILL_IMAGE_ASSET_ID = "rbxassetid://120573464445068"

local itemImageAssetIdsById: { [ItemId]: string } = table.freeze({
	Scythe = SCYTHE_IMAGE_ASSET_ID,

	OakTree = "rbxassetid://100736351086243",
	BirchTree = "rbxassetid://98598565581161",
	CherryTree = "rbxassetid://106367240675182",
	GoldenTree = "rbxassetid://126731029644470",
	EmeraldTree = "rbxassetid://108265574984029",
	SapphireTree = "rbxassetid://135876124547625",
	DiamondTree = "rbxassetid://88480342912822",
	InfernoTree = "rbxassetid://119430470644235",
	FrostbiteTree = "rbxassetid://94568696899208",
	VoidfruitTree = "rbxassetid://130844815001202",
	FalloutTree = "rbxassetid://136381373989446",
	RainbowPrismTree = "rbxassetid://101813367203312",
	GhostwoodTree = "rbxassetid://76743627812405",
	CandyTree = "rbxassetid://73127433981881",
	CyberTree = "rbxassetid://127029151232213",

	CiderMill = MILL_IMAGE_ASSET_ID,
	CopperCiderMill = MILL_IMAGE_ASSET_ID,
	SteelCiderMill = MILL_IMAGE_ASSET_ID,
	PlatinumCiderMill = MILL_IMAGE_ASSET_ID,
	DiamondCiderMill = MILL_IMAGE_ASSET_ID,
	RoyalCiderMill = MILL_IMAGE_ASSET_ID,
	IndustrialCiderMill = MILL_IMAGE_ASSET_ID,
	AdvancedCiderMill = MILL_IMAGE_ASSET_ID,
	MagmaCiderMill = MILL_IMAGE_ASSET_ID,
	WastelandCiderMill = MILL_IMAGE_ASSET_ID,
	AncientCiderMill = MILL_IMAGE_ASSET_ID,
	TitanCiderMill = MILL_IMAGE_ASSET_ID,
	QuantumReactorMill = MILL_IMAGE_ASSET_ID,
	DyingForgeMill = MILL_IMAGE_ASSET_ID,
	DeepSpaceMill = MILL_IMAGE_ASSET_ID,

	OfflineEarningsWindmill = "rbxassetid://75744019440681",
	ModernAFKWindmill = "rbxassetid://97254974522636",
	GoldAFKWindmill = "rbxassetid://126676149091790",
	DiamondAFKWindmill = "rbxassetid://74704325017182",
	CiderCashWindmill = "rbxassetid://75744019440681",
	ModernCashWindmill = "rbxassetid://97254974522636",
	GoldCashWindmill = "rbxassetid://126676149091790",
	DiamondCashWindmill = "rbxassetid://74704325017182",
})

local function getImageAssetId(itemId: ItemId): string
	local imageAssetId = itemImageAssetIdsById[itemId]
	assert(imageAssetId ~= nil, string.format("Missing imageAssetId for item %s", itemId))
	return imageAssetId
end

local itemsById: { [ItemId]: ItemDefinition } = {
	Scythe = table.freeze({
		id = "Scythe",
		displayName = "Scythe",
		kind = "Tool",
		maxStack = 1,
		inventoryOrder = 0,
		toolAssetName = "Scythe",
		imageAssetId = getImageAssetId("Scythe"),
	}),
}

local function createPlaceableItemDefinition(id: ItemId, displayName: string, inventoryOrder: number): ItemDefinition
	return table.freeze({
		id = id,
		displayName = displayName,
		kind = "Placeable",
		maxStack = 99,
		inventoryOrder = inventoryOrder,
		toolAssetName = nil,
		imageAssetId = getImageAssetId(id),
	})
end

for index, treeDefinition: TreeTierDefinition in ipairs(ProgressionConfig.getTreeDefinitions()) do
	itemsById[treeDefinition.id :: ItemId] = createPlaceableItemDefinition(treeDefinition.id :: ItemId, treeDefinition.displayName, 10 + index - 1)
end

for index, millDefinition: MillTierDefinition in ipairs(ProgressionConfig.getMillDefinitions()) do
	itemsById[millDefinition.id :: ItemId] = createPlaceableItemDefinition(millDefinition.id :: ItemId, millDefinition.displayName, 30 + index - 1)
end

for index, windmillDefinition: WindmillDefinition in ipairs(WindmillConfig.getDefinitions()) do
	itemsById[windmillDefinition.id :: ItemId] =
		createPlaceableItemDefinition(windmillDefinition.id :: ItemId, windmillDefinition.displayName, 50 + index - 1)
end

local ItemCatalog = {}

function ItemCatalog.getItemDefinition(itemId: ItemId): ItemDefinition
	return itemsById[itemId]
end

function ItemCatalog.hasItemDefinition(itemId: string): boolean
	return itemsById[itemId :: ItemId] ~= nil
end

function ItemCatalog.getAllItemDefinitions(): { [ItemId]: ItemDefinition }
	return itemsById
end

return table.freeze(ItemCatalog)

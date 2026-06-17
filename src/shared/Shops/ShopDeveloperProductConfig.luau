--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder

local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)

type ItemId = InventoryTypes.ItemId

export type DeveloperProductIdByItemId = { [ItemId]: number }

local UNCONFIGURED_DEVELOPER_PRODUCT_ID = 0

local developerProductIdByItemId: DeveloperProductIdByItemId = table.freeze({
	OakTree = 3605067479,
	BirchTree = 3605067872,
	CherryTree = 3605067901,
	GoldenTree = 3605068031,
	EmeraldTree = 3605068087,
	SapphireTree = 3605068139,
	DiamondTree = 3605068179,
	InfernoTree = 3605068360,
	FrostbiteTree = 3605068412,
	VoidfruitTree = 3605068451,
	FalloutTree = 3605068498,
	RainbowPrismTree = 3605068536,
	GhostwoodTree = 3605068577,
	CandyTree = 3605068623,
	CyberTree = 3605068644,

	CiderMill = 3605067549,
	CopperCiderMill = UNCONFIGURED_DEVELOPER_PRODUCT_ID,
	SteelCiderMill = UNCONFIGURED_DEVELOPER_PRODUCT_ID,
	PlatinumCiderMill = UNCONFIGURED_DEVELOPER_PRODUCT_ID,
	DiamondCiderMill = UNCONFIGURED_DEVELOPER_PRODUCT_ID,
	RoyalCiderMill = UNCONFIGURED_DEVELOPER_PRODUCT_ID,
	IndustrialCiderMill = UNCONFIGURED_DEVELOPER_PRODUCT_ID,
	AdvancedCiderMill = UNCONFIGURED_DEVELOPER_PRODUCT_ID,
	MagmaCiderMill = UNCONFIGURED_DEVELOPER_PRODUCT_ID,
	WastelandCiderMill = UNCONFIGURED_DEVELOPER_PRODUCT_ID,
	AncientCiderMill = UNCONFIGURED_DEVELOPER_PRODUCT_ID,
	TitanCiderMill = UNCONFIGURED_DEVELOPER_PRODUCT_ID,
	QuantumReactorMill = UNCONFIGURED_DEVELOPER_PRODUCT_ID,
	DyingForgeMill = UNCONFIGURED_DEVELOPER_PRODUCT_ID,
	DeepSpaceMill = UNCONFIGURED_DEVELOPER_PRODUCT_ID,
})

local ShopDeveloperProductConfig = {}

function ShopDeveloperProductConfig.getDeveloperProductId(itemId: ItemId): number?
	local developerProductId = developerProductIdByItemId[itemId]
	if developerProductId == nil or developerProductId <= 0 then
		return nil
	end

	return developerProductId
end

function ShopDeveloperProductConfig.getAllDeveloperProductIds(): DeveloperProductIdByItemId
	return developerProductIdByItemId
end

return table.freeze(ShopDeveloperProductConfig)

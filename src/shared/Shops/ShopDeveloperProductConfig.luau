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
	CopperCiderMill = 3605080348,
	SteelCiderMill = 3605080385,
	PlatinumCiderMill = 3605080444,
	DiamondCiderMill = 3605080512,
	RoyalCiderMill = 3605080556,
	IndustrialCiderMill = 3605080607,
	AdvancedCiderMill = 3605080637,
	MagmaCiderMill = 3605080673,
	WastelandCiderMill = 3605080707,
	AncientCiderMill = 3605080789,
	TitanCiderMill = 3605080835,
	QuantumReactorMill = 3605080873,
	DyingForgeMill = 3605080910,
	DeepSpaceMill = 3605080933,
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

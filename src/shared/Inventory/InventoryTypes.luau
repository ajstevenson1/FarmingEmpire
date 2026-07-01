--!strict

export type ItemId =
	"Scythe"
	| "OakTree"
	| "BirchTree"
	| "CherryTree"
	| "GoldenTree"
	| "EmeraldTree"
	| "SapphireTree"
	| "DiamondTree"
	| "InfernoTree"
	| "FrostbiteTree"
	| "VoidfruitTree"
	| "FalloutTree"
	| "RainbowPrismTree"
	| "GhostwoodTree"
	| "CandyTree"
	| "CyberTree"
	| "GlassTree"
	| "CiderMill"
	| "CopperCiderMill"
	| "SteelCiderMill"
	| "PlatinumCiderMill"
	| "DiamondCiderMill"
	| "RoyalCiderMill"
	| "IndustrialCiderMill"
	| "AdvancedCiderMill"
	| "MagmaCiderMill"
	| "WastelandCiderMill"
	| "AncientCiderMill"
	| "TitanCiderMill"
	| "QuantumReactorMill"
	| "DyingForgeMill"
	| "DeepSpaceMill"
	| "TempestMill"
	| "OfflineEarningsWindmill"
	| "ModernAFKWindmill"
	| "GoldAFKWindmill"
	| "DiamondAFKWindmill"
	| "CiderCashWindmill"
	| "ModernCashWindmill"
	| "GoldCashWindmill"
	| "DiamondCashWindmill"
	| "PatriotTree"
export type ItemKind = "Tool" | "Placeable"

export type ItemDefinition = {
	id: ItemId,
	displayName: string,
	kind: ItemKind,
	maxStack: number,
	inventoryOrder: number,
	toolAssetName: string?,
	imageAssetId: string,
}

export type InventoryEntry = {
	itemId: ItemId,
	quantity: number,
}

export type HotbarSlots = {
	[number]: ItemId?,
}

export type InventorySnapshot = {
	entries: { InventoryEntry },
	hotbarSlots: HotbarSlots,
	selectedSlotIndex: number?,
}

return {}

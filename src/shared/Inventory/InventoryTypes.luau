--!strict

export type ItemId =
	"Scythe"
	| "BasicTree"
	| "RubyAppleTree"
	| "GoldenAppleTree"
	| "CrystalAppleTree"
	| "CiderMill"
	| "CopperCiderMill"
	| "SteelCiderMill"
	| "RoyalCiderMill"
export type ItemKind = "Tool" | "Placeable"

export type ItemDefinition = {
	id: ItemId,
	displayName: string,
	kind: ItemKind,
	maxStack: number,
	inventoryOrder: number,
	toolAssetName: string?,
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

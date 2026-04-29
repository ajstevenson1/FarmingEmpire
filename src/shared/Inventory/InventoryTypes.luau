--!strict

export type ItemId = "WheatField"

export type ItemDefinition = {
	id: ItemId,
	displayName: string,
	kind: "Placeable",
	maxStack: number,
	hotbarOrder: number,
	placementFootprint: Vector3,
	placementPreviewColor: Color3,
	placedPartColor: Color3,
}

export type InventoryEntry = {
	itemId: ItemId,
	quantity: number,
}

export type InventorySnapshot = {
	entries: { InventoryEntry },
	equippedItemId: ItemId?,
}

return {}

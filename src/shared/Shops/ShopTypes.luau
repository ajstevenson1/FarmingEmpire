--!strict

export type ShopId = "TreesShop" | "MillsShop"

export type ShopDefinition = {
	id: ShopId,
	displayName: string,
	worldModelName: string,
	touchPartName: string,
	restockGuiName: string,
	nameLabelName: string,
	timerLabelName: string,
	restockIntervalSeconds: number,
}

export type ShopRestockState = {
	nextRestockAt: number,
}

export type ShopSnapshot = {
	shopsById: { [ShopId]: ShopRestockState },
}

export type ShopOpenedPayload = {
	shopId: ShopId,
	snapshot: ShopSnapshot,
}

return {}

--!strict

export type ResourceId = "Apple" | "Cider"

export type ResourceDefinition = {
	id: ResourceId,
	displayName: string,
	displayOrder: number,
}

export type ResourceSnapshot = {
	amountsByResourceId: { [ResourceId]: number },
}

export type ResourceUpdateReason = "OfflineEarningsClaim" | "AutoCiderCollection"

export type ResourceUpdateContext = {
	reason: ResourceUpdateReason,
}

return {}

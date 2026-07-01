--!strict

local inventoryFolder = script.Parent.Parent:WaitForChild("Inventory") :: Folder

local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)

type ItemId = InventoryTypes.ItemId

export type SpecialOfferRewardItem = {
	itemId: ItemId,
	quantity: number,
}

export type SpecialOfferDefinition = {
	buttonName: string,
	costLabelName: string,
	oneTimeRewardId: string,
	rewardItems: { SpecialOfferRewardItem },
}

local SPECIAL_OFFER_DEFINITION: SpecialOfferDefinition = table.freeze({
	buttonName = "SpecialOffer",
	costLabelName = "Cost",
	oneTimeRewardId = "SpecialOfferBundleV1",
	rewardItems = table.freeze({
		table.freeze({
			itemId = "GlassTree" :: ItemId,
			quantity = 1,
		}),
		table.freeze({
			itemId = "TempestMill" :: ItemId,
			quantity = 1,
		}),
	}),
})

local SpecialOfferConfig = {}

function SpecialOfferConfig.getDefinition(): SpecialOfferDefinition
	return SPECIAL_OFFER_DEFINITION
end

return table.freeze(SpecialOfferConfig)

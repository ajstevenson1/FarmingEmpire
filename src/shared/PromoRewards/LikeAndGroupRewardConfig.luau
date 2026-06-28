--!strict

local inventoryFolder = script.Parent.Parent:WaitForChild("Inventory") :: Folder
local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)

type ItemId = InventoryTypes.ItemId

export type PromoRewardEntry = {
	itemId: ItemId,
	quantity: number,
}

export type LikeAndGroupRewardNotifications = {
	success: string,
	notInGroup: string,
	alreadyClaimed: string,
	unavailable: string,
}

export type LikeAndGroupRewardConfig = {
	rewardId: string,
	groupId: number,
	plateName: string,
	touchPartName: string,
	touchCooldownSeconds: number,
	rewards: { PromoRewardEntry },
	notifications: LikeAndGroupRewardNotifications,
}

local LikeAndGroupRewardConfig: LikeAndGroupRewardConfig = {
	rewardId = "LikeAndGroupPlate",
	groupId = 0, -- Uses the experience owner group when possible. Set this if the target group is different.
	plateName = "LikeAndGroupPlate",
	touchPartName = "Touch",
	touchCooldownSeconds = 2,
	rewards = {
		{
			itemId = "CherryTree",
			quantity = 1,
		},
		{
			itemId = "CopperCiderMill",
			quantity = 1,
		},
	},
	notifications = {
		success = "Thanks for joining! Cherry Apple Tree and Copper Cider Mill added to your inventory!",
		notInGroup = "Join the group and like the game to claim these rewards!",
		alreadyClaimed = "You have already claimed this group reward.",
		unavailable = "Group reward is not set up yet.",
	},
}

return table.freeze(LikeAndGroupRewardConfig) :: LikeAndGroupRewardConfig

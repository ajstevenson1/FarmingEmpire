--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local shopsFolder = sharedFolder:WaitForChild("Shops") :: Folder

local ShopTypes = require(shopsFolder:WaitForChild("ShopTypes") :: ModuleScript)

type ShopStockRollConfig = ShopTypes.ShopStockRollConfig

local ShopStockRoller = {}

function ShopStockRoller.rollQuantity(stockConfig: ShopStockRollConfig, random: Random): number
	local appearanceChance = math.clamp(stockConfig.appearanceChance, 0, 1)
	if appearanceChance <= 0 or random:NextNumber() > appearanceChance then
		return 0
	end

	local minQuantity = math.max(0, math.floor(stockConfig.minQuantity))
	local maxQuantity = math.max(minQuantity, math.floor(stockConfig.maxQuantity))
	if maxQuantity <= 0 then
		return 0
	end

	return random:NextInteger(minQuantity, maxQuantity)
end

return table.freeze(ShopStockRoller)

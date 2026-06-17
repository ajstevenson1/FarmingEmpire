--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local monetizationFolder = sharedFolder:WaitForChild("Monetization") :: Folder

local RobuxStoreCatalog = require(monetizationFolder:WaitForChild("RobuxStoreCatalog") :: ModuleScript)
local RobuxStoreTypes = require(monetizationFolder:WaitForChild("RobuxStoreTypes") :: ModuleScript)
local EconomyService = require(script.Parent.Parent.Economy.EconomyService)

type RobuxStoreProductDefinition = RobuxStoreTypes.RobuxStoreProductDefinition

local RobuxStoreService = {}

local function grantCashPack(player: Player, productDefinition: RobuxStoreProductDefinition): boolean
	if productDefinition.rewardAmount <= 0 then
		warn(string.format("[RobuxStoreService] Product %s has invalid reward amount.", productDefinition.id))
		return false
	end

	EconomyService.addCash(player, productDefinition.rewardAmount)
	return true
end

function RobuxStoreService.grantDeveloperProductPurchase(player: Player, developerProductId: number): boolean
	local productDefinition = RobuxStoreCatalog.getProductDefinitionByDeveloperProductId(developerProductId)
	if productDefinition == nil then
		return false
	end

	if productDefinition.rewardType == "Cash" then
		return grantCashPack(player, productDefinition)
	end

	warn(string.format("[RobuxStoreService] Product %s has unsupported reward type.", productDefinition.id))
	return false
end

return table.freeze(RobuxStoreService)

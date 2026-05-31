--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local monetizationFolder = sharedFolder:WaitForChild("Monetization") :: Folder

local GamePassConfig = require(monetizationFolder:WaitForChild("GamePassConfig") :: ModuleScript)
local GamePassOwnershipService = require(script.Parent.GamePassOwnershipService)

local CashBoostService = {}

function CashBoostService.getCashMultiplier(player: Player): number
	local highestMultiplier = 1
	for _, definition in ipairs(GamePassConfig.getCashMultiplierDefinitions()) do
		local cashMultiplier = definition.cashMultiplier
		if cashMultiplier ~= nil
			and cashMultiplier > highestMultiplier
			and GamePassOwnershipService.playerOwnsGamePass(player, definition.gamePassId)
		then
			highestMultiplier = cashMultiplier
		end
	end

	return highestMultiplier
end

return table.freeze(CashBoostService)

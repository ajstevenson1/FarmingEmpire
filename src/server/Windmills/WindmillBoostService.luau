--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local windmillsFolder = sharedFolder:WaitForChild("Windmills") :: Folder

local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local WindmillConfig = require(windmillsFolder:WaitForChild("WindmillConfig") :: ModuleScript)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)

type BuildingId = BuildingTypes.BuildingId

local function getSafeMultiplierBonus(bonus: number): number
	if bonus ~= bonus or bonus == math.huge or bonus == -math.huge or bonus < 0 then
		return 0
	end

	return bonus
end

local function calculateMultiplier(player: Player, getBonus: (BuildingId) -> number): number
	local bonusTotal = 0
	for _, placedBuilding in ipairs(PlayerDataService.getPlacedBuildings(player)) do
		bonusTotal += getSafeMultiplierBonus(getBonus(placedBuilding.buildingId))
	end

	return 1 + bonusTotal
end

local WindmillBoostService = {}

function WindmillBoostService.getOfflineEarningsMultiplier(player: Player): number
	return calculateMultiplier(player, WindmillConfig.getOfflineEarningsMultiplierBonus)
end

function WindmillBoostService.getCiderSellCashMultiplier(player: Player): number
	return calculateMultiplier(player, WindmillConfig.getCiderSellCashMultiplierBonus)
end

return table.freeze(WindmillBoostService)

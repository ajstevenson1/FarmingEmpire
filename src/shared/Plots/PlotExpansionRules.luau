--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local PlotExpansionTypes = require(script.Parent.PlotExpansionTypes)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)

type BuildingId = BuildingTypes.BuildingId
type PlotModifierId = PlotExpansionTypes.PlotModifierId
type ResourceId = ResourceTypes.ResourceId

local PlotExpansionRules = {}

function PlotExpansionRules.getProductionMultiplier(modifierId: PlotModifierId?): number
	if modifierId == "DoubleProduction" then
		return 2
	end

	if modifierId == "TripleProduction" then
		return 3
	end

	return 1
end

function PlotExpansionRules.getResourceOutputMultiplier(modifierId: PlotModifierId?, resourceId: ResourceId): number
	return PlotExpansionRules.getProductionMultiplier(modifierId)
end

function PlotExpansionRules.getStorageCapMultiplier(modifierId: PlotModifierId?, resourceId: ResourceId): number
	if resourceId == "Apple" then
		return PlotExpansionRules.getProductionMultiplier(modifierId)
	end

	return 1
end

function PlotExpansionRules.getBuildingProductionMultiplier(modifierId: PlotModifierId?, buildingId: BuildingId): number
	return PlotExpansionRules.getProductionMultiplier(modifierId)
end

function PlotExpansionRules.getOfflineCiderRateMultiplier(modifierId: PlotModifierId?, buildingId: BuildingId): number
	return PlotExpansionRules.getProductionMultiplier(modifierId)
end

return table.freeze(PlotExpansionRules)

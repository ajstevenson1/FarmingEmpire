--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local progressionFolder = sharedFolder:WaitForChild("Progression") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local PlotExpansionTypes = require(script.Parent.PlotExpansionTypes)
local ProgressionConfig = require(progressionFolder:WaitForChild("ProgressionConfig") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)

type BuildingId = BuildingTypes.BuildingId
type PlotModifierId = PlotExpansionTypes.PlotModifierId
type ResourceId = ResourceTypes.ResourceId

local PlotExpansionRules = {}

function PlotExpansionRules.getResourceOutputMultiplier(modifierId: PlotModifierId?, resourceId: ResourceId): number
	if modifierId == "DoubleApple" and resourceId == "Apple" then
		return 2
	end

	if modifierId == "DoubleCider" and resourceId == "Cider" then
		return 2
	end

	return 1
end

function PlotExpansionRules.getOfflineCiderRateMultiplier(modifierId: PlotModifierId?, buildingId: BuildingId): number
	if modifierId == "DoubleApple" and ProgressionConfig.isTreeBuildingId(buildingId) then
		return 2
	end

	if modifierId == "DoubleCider" and ProgressionConfig.isMillBuildingId(buildingId) then
		return 2
	end

	return 1
end

return table.freeze(PlotExpansionRules)

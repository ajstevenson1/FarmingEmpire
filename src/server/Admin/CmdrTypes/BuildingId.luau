--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)

type BuildingId = BuildingTypes.BuildingId

local function getSortedBuildingIds(): { string }
	local buildingIds: { string } = {}
	for buildingId in pairs(BuildingCatalog.getAllBuildingDefinitions()) do
		table.insert(buildingIds, buildingId)
	end

	table.sort(buildingIds)
	return buildingIds
end

return function(registry)
	local findBuildingId = registry.Cmdr.Util.MakeFuzzyFinder(getSortedBuildingIds())

	registry:RegisterType("buildingId", {
		Validate = function(text: string): (boolean, string?)
			return findBuildingId(text, true) ~= nil, string.format("%q is not a valid building id.", text)
		end,

		Autocomplete = function(text: string): { string }
			return findBuildingId(text)
		end,

		Parse = function(text: string): BuildingId
			return findBuildingId(text, true) :: BuildingId
		end,
	})
end

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local ResourceCatalog = require(resourcesFolder:WaitForChild("ResourceCatalog") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)

type ResourceId = ResourceTypes.ResourceId

local function getSortedResourceIds(): { string }
	local resourceIds: { string } = {}
	for resourceId in pairs(ResourceCatalog.getAllResourceDefinitions()) do
		table.insert(resourceIds, resourceId)
	end

	table.sort(resourceIds)
	return resourceIds
end

return function(registry)
	local findResourceId = registry.Cmdr.Util.MakeFuzzyFinder(getSortedResourceIds())

	registry:RegisterType("resourceId", {
		Validate = function(text: string): (boolean, string?)
			return findResourceId(text, true) ~= nil, string.format("%q is not a valid resource id.", text)
		end,

		Autocomplete = function(text: string): { string }
			return findResourceId(text)
		end,

		Parse = function(text: string): ResourceId
			return findResourceId(text, true) :: ResourceId
		end,
	})
end

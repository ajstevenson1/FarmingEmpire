--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local ResourceCatalog = require(resourcesFolder:WaitForChild("ResourceCatalog") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)
local ResourceService = require(script.Parent.Parent.Parent.Resources.ResourceService)

type ResourceId = ResourceTypes.ResourceId

return function(_context, players: { Player }, resourceId: ResourceId, amount: number): string
	for _, player in ipairs(players) do
		ResourceService.addResource(player, resourceId, amount)
	end

	local resourceDefinition = ResourceCatalog.getResourceDefinition(resourceId)
	return string.format("Gave %d %s to %d player(s).", amount, resourceDefinition.displayName, #players)
end

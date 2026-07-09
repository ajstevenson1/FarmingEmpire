--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)
local AdminGlobalGiveService = require(script.Parent.Parent.AdminGlobalGiveService)

type ResourceId = ResourceTypes.ResourceId

return function(_context, resourceId: ResourceId, amount: number): string
	return AdminGlobalGiveService.publishGrant({
		kind = "Resource",
		resourceId = resourceId,
		amount = amount,
	})
end

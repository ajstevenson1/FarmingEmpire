--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local AdminGlobalGiveService = require(script.Parent.Parent.AdminGlobalGiveService)

type BuildingId = BuildingTypes.BuildingId

return function(_context, buildingId: BuildingId, quantity: number): string
	return AdminGlobalGiveService.publishGrant({
		kind = "Building",
		buildingId = buildingId,
		quantity = quantity,
	})
end

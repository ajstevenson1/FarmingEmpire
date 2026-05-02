--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local GrowAndHarvestBehavior = require(script.Parent.Behaviors.GrowAndHarvestBehavior)
local InputProcessorBehavior = require(script.Parent.Behaviors.InputProcessorBehavior)

type ProductionBehavior = BuildingTypes.ProductionBehavior
type ProductionBehaviorId = BuildingTypes.ProductionBehaviorId

local behaviorById: { [ProductionBehaviorId]: ProductionBehavior } = {
	GrowAndHarvest = GrowAndHarvestBehavior,
	InputProcessor = InputProcessorBehavior,
}

local ProductionBehaviorRegistry = {}

function ProductionBehaviorRegistry.getBehavior(behaviorId: ProductionBehaviorId): ProductionBehavior?
	return behaviorById[behaviorId]
end

return table.freeze(ProductionBehaviorRegistry)

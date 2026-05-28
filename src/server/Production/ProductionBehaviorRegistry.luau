--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local GrowAndHarvestBehavior = require(script.Parent.Behaviors.GrowAndHarvestBehavior)
local InputProcessorBehavior = require(script.Parent.Behaviors.InputProcessorBehavior)
local PassiveBehavior = require(script.Parent.Behaviors.PassiveBehavior)
local TimedStorageProducerBehavior = require(script.Parent.Behaviors.TimedStorageProducerBehavior)

type ProductionBehavior = BuildingTypes.ProductionBehavior
type ProductionBehaviorId = BuildingTypes.ProductionBehaviorId

local behaviorById: { [ProductionBehaviorId]: ProductionBehavior } = {
	GrowAndHarvest = GrowAndHarvestBehavior,
	TimedStorageProducer = TimedStorageProducerBehavior,
	InputProcessor = InputProcessorBehavior,
	Passive = PassiveBehavior,
}

local ProductionBehaviorRegistry = {}

function ProductionBehaviorRegistry.getBehavior(behaviorId: ProductionBehaviorId): ProductionBehavior?
	return behaviorById[behaviorId]
end

return table.freeze(ProductionBehaviorRegistry)

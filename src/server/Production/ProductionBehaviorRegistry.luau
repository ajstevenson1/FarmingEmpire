--!strict

local GrowAndHarvestBehavior = require(script.Parent.Behaviors.GrowAndHarvestBehavior)

local behaviorById = {
	GrowAndHarvest = GrowAndHarvestBehavior,
}

local ProductionBehaviorRegistry = {}

function ProductionBehaviorRegistry.getBehavior(behaviorId: string)
	return behaviorById[behaviorId]
end

return table.freeze(ProductionBehaviorRegistry)

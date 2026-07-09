--!strict

local ResourceTypes = require(script.Parent.ResourceTypes)

type ResourceDefinition = ResourceTypes.ResourceDefinition
type ResourceId = ResourceTypes.ResourceId

local resourcesById: { [ResourceId]: ResourceDefinition } = {
	Apple = table.freeze({
		id = "Apple",
		displayName = "Apples",
		displayOrder = 10,
	}),
	Cider = table.freeze({
		id = "Cider",
		displayName = "Apple Juice",
		displayOrder = 20,
	}),
}

local ResourceCatalog = {}

function ResourceCatalog.getResourceDefinition(resourceId: ResourceId): ResourceDefinition
	return resourcesById[resourceId]
end

function ResourceCatalog.getAllResourceDefinitions(): { [ResourceId]: ResourceDefinition }
	return resourcesById
end

return table.freeze(ResourceCatalog)

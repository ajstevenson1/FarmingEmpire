--!strict

return {
	Name = "globalgiveresource",
	Aliases = { "ggresource", "globalresource" },
	Description = "Gives a resource to every online player across all live servers.",
	Group = "Admin",
	Args = {
		{
			Type = "resourceId",
			Name = "resource",
			Description = "The resource id to give globally.",
		},
		{
			Type = "positiveInteger",
			Name = "amount",
			Description = "The resource amount to give globally.",
		},
	},
}

--!strict

return {
	Name = "giveresource",
	Aliases = { "resource", "giveresources" },
	Description = "Gives resources to one or more players.",
	Group = "Admin",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players to receive the resource.",
		},
		{
			Type = "resourceId",
			Name = "resource",
			Description = "The resource id to give.",
		},
		{
			Type = "positiveInteger",
			Name = "amount",
			Description = "The resource amount to give.",
		},
	},
}

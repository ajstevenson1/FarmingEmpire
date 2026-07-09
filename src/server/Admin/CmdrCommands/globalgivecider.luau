--!strict

return {
	Name = "globalgivecider",
	Aliases = { "ggcider", "globalcider" },
	Description = "Gives apple juice to every online player across all live servers.",
	Group = "Admin",
	Args = {
		{
			Type = "positiveInteger",
			Name = "amount",
			Description = "The apple juice amount to give globally.",
		},
	},
}

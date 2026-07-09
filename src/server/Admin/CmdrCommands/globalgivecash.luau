--!strict

return {
	Name = "globalgivecash",
	Aliases = { "ggcash", "globalcash" },
	Description = "Gives cash to every online player across all live servers.",
	Group = "Admin",
	Args = {
		{
			Type = "positiveInteger",
			Name = "amount",
			Description = "The cash amount to give globally.",
		},
	},
}

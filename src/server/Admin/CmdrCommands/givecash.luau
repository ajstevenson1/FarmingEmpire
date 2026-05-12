--!strict

return {
	Name = "givecash",
	Aliases = { "cash" },
	Description = "Gives cash to one or more players.",
	Group = "Admin",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players to receive cash.",
		},
		{
			Type = "positiveInteger",
			Name = "amount",
			Description = "The cash amount to give.",
		},
	},
}

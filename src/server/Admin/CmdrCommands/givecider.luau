--!strict

return {
	Name = "givecider",
	Aliases = { "cider" },
	Description = "Gives cider to one or more players.",
	Group = "Admin",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players to receive cider.",
		},
		{
			Type = "positiveInteger",
			Name = "amount",
			Description = "The cider amount to give.",
		},
	},
}

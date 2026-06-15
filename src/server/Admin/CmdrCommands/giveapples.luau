--!strict

return {
	Name = "giveapples",
	Aliases = { "apples" },
	Description = "Gives apples to one or more players.",
	Group = "Admin",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players to receive apples.",
		},
		{
			Type = "positiveInteger",
			Name = "amount",
			Description = "The apple amount to give.",
		},
	},
}

--!strict

return {
	Name = "givecider",
	Aliases = { "cider" },
	Description = "Gives apple juice to one or more players.",
	Group = "Admin",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players to receive apple juice.",
		},
		{
			Type = "positiveInteger",
			Name = "amount",
			Description = "The apple juice amount to give.",
		},
	},
}

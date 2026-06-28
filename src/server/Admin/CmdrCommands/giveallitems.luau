--!strict

return {
	Name = "giveallitems",
	Aliases = { "grantallitems", "giveeveryitem", "allitems" },
	Description = "Gives one of every inventory item to one or more players.",
	Group = "Admin",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players to receive every item.",
		},
	},
}

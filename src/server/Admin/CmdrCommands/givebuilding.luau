--!strict

return {
	Name = "givebuilding",
	Aliases = { "giveitem", "givetree", "givemill" },
	Description = "Gives placeable buildings to one or more players.",
	Group = "Admin",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players to receive the building.",
		},
		{
			Type = "buildingId",
			Name = "building",
			Description = "The building id to give.",
		},
		{
			Type = "positiveInteger",
			Name = "quantity",
			Description = "The quantity to give.",
			Optional = true,
			Default = 1,
		},
	},
}

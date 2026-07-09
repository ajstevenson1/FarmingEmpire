--!strict

return {
	Name = "globalgivebuilding",
	Aliases = { "ggbuilding", "ggitem", "ggtree", "ggmill", "globalgiveitem", "globalgivetree", "globalgivemill" },
	Description = "Gives a placeable building to every online player across all live servers.",
	Group = "Admin",
	Args = {
		{
			Type = "buildingId",
			Name = "building",
			Description = "The building id to give globally.",
		},
		{
			Type = "positiveInteger",
			Name = "quantity",
			Description = "The quantity to give globally.",
			Optional = true,
			Default = 1,
		},
	},
}

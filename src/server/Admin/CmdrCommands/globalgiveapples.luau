--!strict

return {
	Name = "globalgiveapples",
	Aliases = { "ggapples", "globalapples" },
	Description = "Gives apples to every online player across all live servers.",
	Group = "Admin",
	Args = {
		{
			Type = "positiveInteger",
			Name = "amount",
			Description = "The apple amount to give globally.",
		},
	},
}

--!strict

return {
	Name = "globalannounce",
	Aliases = { "ga", "gannounce" },
	Description = "Makes a global HUD announcement across all servers.",
	Group = "Admin",
	Args = {
		{
			Type = "string",
			Name = "text",
			Description = "The announcement text.",
		},
	},
}

--!strict

return {
	Name = "globalweather",
	Aliases = { "gw" },
	Description = "Starts or stops weather across all servers.",
	Group = "Admin",
	Args = {
		{
			Type = "string",
			Name = "action",
			Description = "Use start or stop.",
		},
		{
			Type = "string",
			Name = "event",
			Description = "Weather event name, such as Rain.",
			Optional = true,
		},
	},
}

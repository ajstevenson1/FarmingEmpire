--!strict

return {
	Name = "weather",
	Aliases = {},
	Description = "Starts or stops a weather event.",
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

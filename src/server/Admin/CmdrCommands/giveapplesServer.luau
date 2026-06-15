--!strict

local ResourceService = require(script.Parent.Parent.Parent.Resources.ResourceService)

return function(_context, players: { Player }, amount: number): string
	for _, player in ipairs(players) do
		ResourceService.addResource(player, "Apple", amount)
	end

	return string.format("Gave %d Apples to %d player(s).", amount, #players)
end

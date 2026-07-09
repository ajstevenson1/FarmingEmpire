--!strict

local AdminGrantService = require(script.Parent.Parent.AdminGrantService)

return function(_context, players: { Player }, amount: number): string
	return AdminGrantService.grantResource(players, "Apple", amount)
end

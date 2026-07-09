--!strict

local AdminGrantService = require(script.Parent.Parent.AdminGrantService)

return function(_context, players: { Player }): string
	return AdminGrantService.grantAllItems(players)
end

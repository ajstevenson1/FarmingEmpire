--!strict

local AdminGlobalGiveService = require(script.Parent.Parent.AdminGlobalGiveService)

return function(_context, amount: number): string
	return AdminGlobalGiveService.publishGrant({
		kind = "Cash",
		amount = amount,
	})
end

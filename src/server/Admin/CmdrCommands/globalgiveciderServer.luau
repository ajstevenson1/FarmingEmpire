--!strict

local AdminGlobalGiveService = require(script.Parent.Parent.AdminGlobalGiveService)

return function(_context, amount: number): string
	return AdminGlobalGiveService.publishGrant({
		kind = "Resource",
		resourceId = "Cider",
		amount = amount,
	})
end

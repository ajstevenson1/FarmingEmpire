--!strict

local AdminGlobalGiveService = require(script.Parent.Parent.AdminGlobalGiveService)

return function(_context): string
	return AdminGlobalGiveService.publishGrant({
		kind = "AllItems",
	})
end

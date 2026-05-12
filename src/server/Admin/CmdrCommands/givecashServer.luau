--!strict

local EconomyService = require(script.Parent.Parent.Parent.Economy.EconomyService)

return function(_context, players: { Player }, amount: number): string
	for _, player in ipairs(players) do
		EconomyService.addCash(player, amount)
	end

	return string.format("Gave $%d to %d player(s).", amount, #players)
end

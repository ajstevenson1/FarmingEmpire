--!strict

local startingHotbarSlots: { [number]: string } = {
	[2] = "BasicTree",
	[3] = "CiderMill",
}

return table.freeze(startingHotbarSlots)

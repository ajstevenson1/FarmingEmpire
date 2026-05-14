--!strict

local startingHotbarSlots: { [number]: string } = {
	[2] = "OakTree",
	[3] = "CiderMill",
}

return table.freeze(startingHotbarSlots)

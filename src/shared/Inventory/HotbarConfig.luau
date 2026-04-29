--!strict

local HotbarConfig = {
	lockedSlotIndex = 0,
	firstAssignableSlotIndex = 1,
	lastSlotIndex = 9,
	defaultSelectedSlotIndex = nil :: number?,
}

function HotbarConfig.isSlotIndexInRange(slotIndex: number): boolean
	return slotIndex >= HotbarConfig.lockedSlotIndex and slotIndex <= HotbarConfig.lastSlotIndex
end

function HotbarConfig.isAssignableSlotIndex(slotIndex: number): boolean
	return slotIndex >= HotbarConfig.firstAssignableSlotIndex and slotIndex <= HotbarConfig.lastSlotIndex
end

function HotbarConfig.getAllSlotIndices(): { number }
	local slotIndices = table.create(HotbarConfig.lastSlotIndex - HotbarConfig.lockedSlotIndex + 1)
	for slotIndex = HotbarConfig.lockedSlotIndex, HotbarConfig.lastSlotIndex do
		table.insert(slotIndices, slotIndex)
	end

	return slotIndices
end

return table.freeze(HotbarConfig)

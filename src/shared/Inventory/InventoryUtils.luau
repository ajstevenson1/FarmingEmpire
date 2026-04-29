--!strict

local InventoryTypes = require(script.Parent.InventoryTypes)

type HotbarSlots = InventoryTypes.HotbarSlots
type InventoryEntry = InventoryTypes.InventoryEntry
type InventorySnapshot = InventoryTypes.InventorySnapshot
type ItemId = InventoryTypes.ItemId

local InventoryUtils = {}

function InventoryUtils.cloneHotbarSlots(hotbarSlots: HotbarSlots): HotbarSlots
	local clone: HotbarSlots = {}
	for slotIndex, itemId in pairs(hotbarSlots) do
		clone[slotIndex] = itemId
	end

	return clone
end

function InventoryUtils.getItemQuantity(entries: { InventoryEntry }, itemId: ItemId): number
	for _, entry in ipairs(entries) do
		if entry.itemId == itemId then
			return entry.quantity
		end
	end

	return 0
end

function InventoryUtils.getSelectedItemId(snapshot: InventorySnapshot): ItemId?
	local selectedSlotIndex = snapshot.selectedSlotIndex
	if selectedSlotIndex == nil then
		return nil
	end

	return snapshot.hotbarSlots[selectedSlotIndex]
end

return table.freeze(InventoryUtils)

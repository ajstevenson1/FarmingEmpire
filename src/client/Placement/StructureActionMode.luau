--!strict

export type StructureActionModeId = "None" | "Pickup" | "Sell"
type ModeObserver = (mode: StructureActionModeId) -> ()

local currentMode: StructureActionModeId = "None"
local nextObserverId = 0
local observersById: { [number]: ModeObserver } = {}

local StructureActionMode = {}

local function publishModeChanged()
	for _, observer in pairs(observersById) do
		task.spawn(observer, currentMode)
	end
end

function StructureActionMode.getMode(): StructureActionModeId
	return currentMode
end

function StructureActionMode.isModeActive(mode: StructureActionModeId): boolean
	return currentMode == mode
end

function StructureActionMode.setMode(mode: StructureActionModeId)
	if currentMode == mode then
		return
	end

	currentMode = mode
	publishModeChanged()
end

function StructureActionMode.clearMode()
	StructureActionMode.setMode("None")
end

function StructureActionMode.observeModeChanged(observer: ModeObserver): () -> ()
	nextObserverId += 1
	local observerId = nextObserverId
	observersById[observerId] = observer
	observer(currentMode)

	return function()
		observersById[observerId] = nil
	end
end

return table.freeze(StructureActionMode)

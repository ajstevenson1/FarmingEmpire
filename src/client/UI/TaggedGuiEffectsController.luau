--!strict

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local SUNBURST_TAG = "SunburstEffect"
local BOUNCE_TAG = "BounceEffect"

local SUNBURST_ROTATION_DEGREES_PER_SECOND = 30
local BOUNCE_HEIGHT_PIXELS = 4
local BOUNCE_CYCLES_PER_SECOND = 0.8

type EffectConnectionSet = {
	added: RBXScriptConnection?,
	removed: RBXScriptConnection?,
}

type BounceState = {
	basePosition: UDim2,
	phase: number,
	lastOffset: number,
}

local hasStarted = false
local sunburstObjects: { [GuiObject]: true } = {}
local bounceStates: { [GuiObject]: BounceState } = {}
local tagConnections: { [string]: EffectConnectionSet } = {}
local renderConnection: RBXScriptConnection? = nil
local nextBouncePhase = 0

local function addPixelOffset(position: UDim2, xOffset: number, yOffset: number): UDim2
	return UDim2.new(position.X.Scale, position.X.Offset + xOffset, position.Y.Scale, position.Y.Offset + yOffset)
end

local function getGuiObject(instance: Instance): GuiObject?
	if not instance:IsA("GuiObject") then
		return nil
	end

	return instance
end

local function addSunburst(instance: Instance)
	local guiObject = getGuiObject(instance)
	if guiObject == nil then
		return
	end

	sunburstObjects[guiObject] = true
end

local function removeSunburst(instance: Instance)
	local guiObject = getGuiObject(instance)
	if guiObject == nil then
		return
	end

	sunburstObjects[guiObject] = nil
end

local function addBounce(instance: Instance)
	local guiObject = getGuiObject(instance)
	if guiObject == nil or bounceStates[guiObject] ~= nil then
		return
	end

	nextBouncePhase += math.pi / 3
	bounceStates[guiObject] = {
		basePosition = guiObject.Position,
		phase = nextBouncePhase,
		lastOffset = 0,
	}
end

local function removeBounce(instance: Instance)
	local guiObject = getGuiObject(instance)
	if guiObject == nil then
		return
	end

	local bounceState = bounceStates[guiObject]
	if bounceState ~= nil then
		guiObject.Position = bounceState.basePosition
	end

	bounceStates[guiObject] = nil
end

local function bindTag(tagName: string, addEffect: (Instance) -> (), removeEffect: (Instance) -> ())
	for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
		addEffect(instance)
	end

	tagConnections[tagName] = {
		added = CollectionService:GetInstanceAddedSignal(tagName):Connect(addEffect),
		removed = CollectionService:GetInstanceRemovedSignal(tagName):Connect(removeEffect),
	}
end

local function applySunburstEffects(deltaTime: number)
	for guiObject in pairs(sunburstObjects) do
		if guiObject.Parent == nil then
			sunburstObjects[guiObject] = nil
		else
			guiObject.Rotation = (guiObject.Rotation + SUNBURST_ROTATION_DEGREES_PER_SECOND * deltaTime) % 360
		end
	end
end

local function applyBounceEffects(now: number)
	for guiObject, bounceState in pairs(bounceStates) do
		if guiObject.Parent == nil then
			bounceStates[guiObject] = nil
		else
			local currentPosition = guiObject.Position
			local expectedPosition = addPixelOffset(bounceState.basePosition, 0, bounceState.lastOffset)
			if currentPosition ~= expectedPosition then
				bounceState.basePosition = addPixelOffset(currentPosition, 0, -bounceState.lastOffset)
			end

			local offset = math.sin((now * BOUNCE_CYCLES_PER_SECOND * math.pi * 2) + bounceState.phase)
				* BOUNCE_HEIGHT_PIXELS
			local roundedOffset = math.round(offset)
			bounceState.lastOffset = roundedOffset
			guiObject.Position = addPixelOffset(bounceState.basePosition, 0, roundedOffset)
		end
	end
end

local TaggedGuiEffectsController = {}

function TaggedGuiEffectsController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	bindTag(SUNBURST_TAG, addSunburst, removeSunburst)
	bindTag(BOUNCE_TAG, addBounce, removeBounce)

	renderConnection = RunService.RenderStepped:Connect(function(deltaTime: number)
		local now = os.clock()
		applySunburstEffects(deltaTime)
		applyBounceEffects(now)
	end)
end

return table.freeze(TaggedGuiEffectsController)

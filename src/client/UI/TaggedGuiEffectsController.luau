--!strict

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local SUNBURST_TAG = "SunburstEffect"
local BOUNCE_TAG = "BounceEffect"
local SHINE_TAG = "ShineEffect"
local SHINE_OVERLAY_NAME = "GeneratedShineEffectOverlay"

local SUNBURST_ROTATION_DEGREES_PER_SECOND = 30
local BOUNCE_HEIGHT_PIXELS = 4
local BOUNCE_CYCLES_PER_SECOND = 0.8
local SHINE_CYCLES_PER_SECOND = 0.45

type EffectConnectionSet = {
	added: RBXScriptConnection?,
	removed: RBXScriptConnection?,
}

type BounceState = {
	basePosition: UDim2,
	phase: number,
	lastOffset: number,
}

type ImageGuiObject = ImageLabel | ImageButton

type ShineState = {
	overlay: GuiObject,
	gradient: UIGradient,
	phase: number,
}

local hasStarted = false
local sunburstObjects: { [GuiObject]: true } = {}
local bounceStates: { [GuiObject]: BounceState } = {}
local shineStates: { [GuiObject]: ShineState } = {}
local tagConnections: { [string]: EffectConnectionSet } = {}
local renderConnection: RBXScriptConnection? = nil
local nextBouncePhase = 0
local nextShinePhase = 0

local function addPixelOffset(position: UDim2, xOffset: number, yOffset: number): UDim2
	return UDim2.new(position.X.Scale, position.X.Offset + xOffset, position.Y.Scale, position.Y.Offset + yOffset)
end

local function isImageGuiObject(guiObject: GuiObject): boolean
	return guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton")
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

local function addShineGradient(parent: GuiObject): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Gradient"
	gradient.Rotation = 25
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.44, 1),
		NumberSequenceKeypoint.new(0.5, 0.18),
		NumberSequenceKeypoint.new(0.56, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Offset = Vector2.new(-1.2, 0)
	gradient.Parent = parent
	return gradient
end

local function syncImageOverlay(source: ImageGuiObject, overlay: ImageGuiObject)
	overlay.Image = source.Image
	overlay.ImageRectOffset = source.ImageRectOffset
	overlay.ImageRectSize = source.ImageRectSize
	overlay.ScaleType = source.ScaleType
	overlay.SliceCenter = source.SliceCenter
	overlay.SliceScale = source.SliceScale
	overlay.TileSize = source.TileSize
end

local function createShineOverlay(guiObject: GuiObject): (GuiObject, UIGradient)
	local existingOverlay = guiObject:FindFirstChild(SHINE_OVERLAY_NAME)
	if existingOverlay ~= nil and existingOverlay:IsA("GuiObject") then
		local existingGradient = existingOverlay:FindFirstChildOfClass("UIGradient")
		if existingGradient ~= nil then
			return existingOverlay, existingGradient
		end

		return existingOverlay, addShineGradient(existingOverlay)
	end

	local overlay: GuiObject
	if isImageGuiObject(guiObject) then
		local imageOverlay = Instance.new("ImageLabel")
		imageOverlay.ImageColor3 = Color3.fromRGB(255, 255, 255)
		imageOverlay.ImageTransparency = 0
		imageOverlay.BackgroundTransparency = 1
		imageOverlay.Active = false
		syncImageOverlay(guiObject :: ImageGuiObject, imageOverlay)
		overlay = imageOverlay
	else
		local frameOverlay = Instance.new("Frame")
		frameOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		frameOverlay.BackgroundTransparency = 0
		overlay = frameOverlay
	end

	overlay.Name = SHINE_OVERLAY_NAME
	overlay.AnchorPoint = Vector2.new(0, 0)
	overlay.Position = UDim2.fromScale(0, 0)
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BorderSizePixel = 0
	overlay.ZIndex = guiObject.ZIndex + 1
	overlay.Parent = guiObject

	return overlay, addShineGradient(overlay)
end

local function addShine(instance: Instance)
	local guiObject = getGuiObject(instance)
	if guiObject == nil or shineStates[guiObject] ~= nil then
		return
	end

	local overlay, gradient = createShineOverlay(guiObject)
	nextShinePhase += 0.19
	shineStates[guiObject] = {
		overlay = overlay,
		gradient = gradient,
		phase = nextShinePhase,
	}
end

local function removeShine(instance: Instance)
	local guiObject = getGuiObject(instance)
	if guiObject == nil then
		return
	end

	local shineState = shineStates[guiObject]
	if shineState ~= nil then
		shineState.overlay:Destroy()
	end

	shineStates[guiObject] = nil
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

local function applyShineEffects(now: number)
	for guiObject, shineState in pairs(shineStates) do
		if guiObject.Parent == nil or shineState.overlay.Parent == nil then
			shineStates[guiObject] = nil
		else
			if isImageGuiObject(guiObject) and isImageGuiObject(shineState.overlay) then
				syncImageOverlay(guiObject :: ImageGuiObject, shineState.overlay :: ImageGuiObject)
			end

			shineState.overlay.Visible = guiObject.Visible
			shineState.overlay.ZIndex = guiObject.ZIndex + 1

			local progress = ((now * SHINE_CYCLES_PER_SECOND) + shineState.phase) % 1
			shineState.gradient.Offset = Vector2.new(-1.2 + (progress * 2.4), 0)
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
	bindTag(SHINE_TAG, addShine, removeShine)

	renderConnection = RunService.RenderStepped:Connect(function(deltaTime: number)
		local now = os.clock()
		applySunburstEffects(deltaTime)
		applyBounceEffects(now)
		applyShineEffects(now)
	end)
end

return table.freeze(TaggedGuiEffectsController)

--!strict

local UserInputService = game:GetService("UserInputService")

type GuiButtonLike = TextButton | ImageButton

export type SliderOptions = {
	defaultValue: number?,
	step: number?,
}

export type Slider = {
	_track: GuiObject,
	_filled: GuiObject,
	_knob: GuiButtonLike,
	_value: number,
	_step: number?,
	_isDraggingWithMouse: boolean,
	_activeTouchInput: InputObject?,
	_connections: { RBXScriptConnection },
	_changedCallbacks: { (number) -> () },
	setValue: (self: Slider, value: number, shouldFireChanged: boolean?) -> (),
	getValue: (self: Slider) -> number,
	connectChanged: (self: Slider, callback: (number) -> ()) -> (),
	destroy: (self: Slider) -> (),
}

local Slider = {}
Slider.__index = Slider

local function quantizeValue(value: number, step: number?): number
	local clampedValue = math.clamp(value, 0, 1)
	if step == nil or step <= 0 then
		return clampedValue
	end

	local steppedValue = math.round(clampedValue / step) * step
	return math.clamp(steppedValue, 0, 1)
end

local function getKnobRadius(knob: GuiButtonLike, trackWidth: number): number
	return math.min(knob.AbsoluteSize.X * 0.5, trackWidth * 0.5)
end

local function render(self: Slider)
	local trackWidth = self._track.AbsoluteSize.X
	if trackWidth <= 0 then
		return
	end

	local knobRadius = getKnobRadius(self._knob, trackWidth)
	local travelWidth = math.max(trackWidth - knobRadius * 2, 0)
	local knobCenterX = knobRadius + travelWidth * self._value
	local knobCenterScale = knobCenterX / trackWidth

	local knobPosition = self._knob.Position
	self._knob.Position = UDim2.new(knobCenterScale, 0, knobPosition.Y.Scale, knobPosition.Y.Offset)

	local filledSize = self._filled.Size
	self._filled.Size = UDim2.new(knobCenterScale, 0, filledSize.Y.Scale, filledSize.Y.Offset)
end

local function updateValueFromScreenPosition(self: Slider, screenPositionX: number)
	local trackWidth = self._track.AbsoluteSize.X
	if trackWidth <= 0 then
		return
	end

	local knobRadius = getKnobRadius(self._knob, trackWidth)
	local travelWidth = math.max(trackWidth - knobRadius * 2, 0)
	local travelStartX = self._track.AbsolutePosition.X + knobRadius
	local nextValue = if travelWidth <= 0 then 0 else (screenPositionX - travelStartX) / travelWidth
	self:setValue(nextValue, true)
end

local function beginDrag(self: Slider, inputObject: InputObject)
	if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
		self._isDraggingWithMouse = true
		self._activeTouchInput = nil
		updateValueFromScreenPosition(self, inputObject.Position.X)
		return
	end

	if inputObject.UserInputType == Enum.UserInputType.Touch then
		self._isDraggingWithMouse = false
		self._activeTouchInput = inputObject
		updateValueFromScreenPosition(self, inputObject.Position.X)
	end
end

function Slider.new(track: GuiObject, filled: GuiObject, knob: GuiButtonLike, options: SliderOptions?): Slider
	track.Active = true
	knob.Active = true

	local self = setmetatable({
		_track = track,
		_filled = filled,
		_knob = knob,
		_value = 0,
		_step = if options == nil then nil else options.step,
		_isDraggingWithMouse = false,
		_activeTouchInput = nil,
		_connections = {},
		_changedCallbacks = {},
	}, Slider) :: Slider

	table.insert(self._connections, track.InputBegan:Connect(function(inputObject: InputObject)
		beginDrag(self, inputObject)
	end))

	table.insert(self._connections, knob.InputBegan:Connect(function(inputObject: InputObject)
		beginDrag(self, inputObject)
	end))

	table.insert(self._connections, UserInputService.InputChanged:Connect(function(inputObject: InputObject)
		if self._isDraggingWithMouse then
			if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
				updateValueFromScreenPosition(self, inputObject.Position.X)
			end
			return
		end

		if self._activeTouchInput ~= nil and inputObject == self._activeTouchInput then
			updateValueFromScreenPosition(self, inputObject.Position.X)
		end
	end))

	table.insert(self._connections, UserInputService.InputEnded:Connect(function(inputObject: InputObject)
		if self._isDraggingWithMouse and inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			self._isDraggingWithMouse = false
			return
		end

		if self._activeTouchInput ~= nil and inputObject == self._activeTouchInput then
			self._activeTouchInput = nil
		end
	end))

	table.insert(self._connections, track:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		render(self)
	end))

	table.insert(self._connections, knob:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		render(self)
	end))

	self:setValue(if options == nil or options.defaultValue == nil then 0 else options.defaultValue, false)
	return self
end

function Slider:setValue(value: number, shouldFireChanged: boolean?)
	local nextValue = quantizeValue(value, self._step)
	if self._value == nextValue then
		render(self)
		return
	end

	self._value = nextValue
	render(self)

	if shouldFireChanged == true then
		for _, callback in ipairs(self._changedCallbacks) do
			callback(nextValue)
		end
	end
end

function Slider:getValue(): number
	return self._value
end

function Slider:connectChanged(callback: (number) -> ())
	table.insert(self._changedCallbacks, callback)
end

function Slider:destroy()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end

	table.clear(self._connections)
	table.clear(self._changedCallbacks)
	self._activeTouchInput = nil
	self._isDraggingWithMouse = false
end

return Slider

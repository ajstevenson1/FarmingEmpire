--!strict

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

export type InputControlScheme = "Touch" | "MouseKeyboard" | "Gamepad"
export type ScreenClass = "Phone" | "Tablet" | "Desktop"
type ProfileObserver = () -> ()

local PHONE_MAX_SHORT_AXIS_PIXELS = 700
local TABLET_MAX_SHORT_AXIS_PIXELS = 1100

local observersById: { [number]: ProfileObserver } = {}
local nextObserverId = 0
local hasStarted = false

local function isGamepadInputType(inputType: Enum.UserInputType): boolean
	return inputType == Enum.UserInputType.Gamepad1
		or inputType == Enum.UserInputType.Gamepad2
		or inputType == Enum.UserInputType.Gamepad3
		or inputType == Enum.UserInputType.Gamepad4
		or inputType == Enum.UserInputType.Gamepad5
		or inputType == Enum.UserInputType.Gamepad6
		or inputType == Enum.UserInputType.Gamepad7
		or inputType == Enum.UserInputType.Gamepad8
end

local function isMouseKeyboardInputType(inputType: Enum.UserInputType): boolean
	return inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.MouseButton2
		or inputType == Enum.UserInputType.MouseButton3
		or inputType == Enum.UserInputType.MouseMovement
		or inputType == Enum.UserInputType.MouseWheel
		or inputType == Enum.UserInputType.Keyboard
end

local function publishChanged()
	for _, observer in pairs(observersById) do
		task.spawn(observer)
	end
end

local function getViewportSize(): Vector2
	local currentCamera = Workspace.CurrentCamera
	if currentCamera ~= nil then
		local viewportSize = currentCamera.ViewportSize
		if viewportSize.X > 0 and viewportSize.Y > 0 then
			return viewportSize
		end
	end

	return Vector2.zero
end

local function connectCameraViewportObserver()
	local currentCamera = Workspace.CurrentCamera
	if currentCamera == nil then
		return
	end

	currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(publishChanged)
end

local ClientInputProfile = {}

function ClientInputProfile.getControlScheme(): InputControlScheme
	local lastInputType = UserInputService:GetLastInputType()
	if isGamepadInputType(lastInputType) then
		return "Gamepad"
	end

	if UserInputService.TouchEnabled and lastInputType == Enum.UserInputType.Touch then
		return "Touch"
	end

	if isMouseKeyboardInputType(lastInputType) then
		return "MouseKeyboard"
	end

	if UserInputService.TouchEnabled then
		return "Touch"
	end

	if UserInputService.GamepadEnabled then
		return "Gamepad"
	end

	return "MouseKeyboard"
end

function ClientInputProfile.usesTouchControls(): boolean
	return ClientInputProfile.getControlScheme() == "Touch"
end

function ClientInputProfile.usesGamepadControls(): boolean
	return ClientInputProfile.getControlScheme() == "Gamepad"
end

function ClientInputProfile.getScreenClass(): ScreenClass
	local viewportSize = getViewportSize()
	if viewportSize.X <= 0 or viewportSize.Y <= 0 then
		return if UserInputService.TouchEnabled then "Tablet" else "Desktop"
	end

	local shortAxis = math.min(viewportSize.X, viewportSize.Y)
	if UserInputService.TouchEnabled and shortAxis <= PHONE_MAX_SHORT_AXIS_PIXELS then
		return "Phone"
	end

	if UserInputService.TouchEnabled and shortAxis <= TABLET_MAX_SHORT_AXIS_PIXELS then
		return "Tablet"
	end

	return "Desktop"
end

function ClientInputProfile.observeChanged(observer: ProfileObserver): () -> ()
	if not hasStarted then
		hasStarted = true
		UserInputService.LastInputTypeChanged:Connect(function(_lastInputType: Enum.UserInputType)
			publishChanged()
		end)
		Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			connectCameraViewportObserver()
			publishChanged()
		end)
		connectCameraViewportObserver()
	end

	nextObserverId += 1
	local observerId = nextObserverId
	observersById[observerId] = observer
	observer()

	return function()
		observersById[observerId] = nil
	end
end

return table.freeze(ClientInputProfile)

--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

type GuiButtonLike = TextButton | ImageButton

type VariantConfig = {
	hoverSizeDelta: UDim2,
	hoverStrokeColor: Color3,
	tweenInfo: TweenInfo,
}

type BoundButtonState = {
	button: GuiButtonLike,
	designFrame: GuiObject,
	stroke: UIStroke,
	config: VariantConfig,
	defaultAutoButtonColor: boolean,
	defaultSize: UDim2,
	defaultStrokeColor: Color3,
	activeSizeTween: Tween?,
	activeStrokeTween: Tween?,
	connections: { RBXScriptConnection },
}

export type ButtonHoverController = {
	start: () -> (),
	destroy: () -> (),
}

local ROOT_GUI_NAME = "GUI"
local VARIANT_ATTRIBUTE_NAME = "Type"

local VARIANT_CONFIGS: { [string]: VariantConfig } = {
	Top = {
		hoverSizeDelta = UDim2.fromScale(0.2, 0.2),
		hoverStrokeColor = Color3.fromRGB(255, 255, 255),
		tweenInfo = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	},
}

local hasStarted = false
local rootConnection: RBXScriptConnection? = nil
local boundStatesByButton: { [GuiButtonLike]: BoundButtonState } = {}

local function isGuiButtonLike(instance: Instance): boolean
	return instance:IsA("TextButton") or instance:IsA("ImageButton")
end

local function getVariantConfig(button: GuiButtonLike): VariantConfig?
	local variantValue = button:GetAttribute(VARIANT_ATTRIBUTE_NAME)
	if typeof(variantValue) ~= "string" then
		return nil
	end

	return VARIANT_CONFIGS[variantValue]
end

local function getDesignFrame(button: GuiButtonLike): GuiObject?
	local designFrame = button:FindFirstChild("Design")
	if designFrame == nil then
		return nil
	end

	if not designFrame:IsA("GuiObject") then
		warn(string.format("%s.Design must be a GuiObject for hover styling", button:GetFullName()))
		return nil
	end

	return designFrame
end

local function getStroke(designFrame: GuiObject): UIStroke?
	local stroke = designFrame:FindFirstChild("Stroke")
	if stroke == nil then
		return nil
	end

	if not stroke:IsA("UIStroke") then
		warn(string.format("%s.Stroke must be a UIStroke for hover styling", designFrame:GetFullName()))
		return nil
	end

	return stroke
end

local function addSizeDelta(size: UDim2, sizeDelta: UDim2): UDim2
	return UDim2.new(
		size.X.Scale + sizeDelta.X.Scale,
		size.X.Offset + sizeDelta.X.Offset,
		size.Y.Scale + sizeDelta.Y.Scale,
		size.Y.Offset + sizeDelta.Y.Offset
	)
end

local function cancelTweens(boundState: BoundButtonState)
	local activeSizeTween = boundState.activeSizeTween
	if activeSizeTween ~= nil then
		activeSizeTween:Cancel()
		boundState.activeSizeTween = nil
	end

	local activeStrokeTween = boundState.activeStrokeTween
	if activeStrokeTween ~= nil then
		activeStrokeTween:Cancel()
		boundState.activeStrokeTween = nil
	end
end

local function tweenToState(boundState: BoundButtonState, isHovered: boolean)
	cancelTweens(boundState)

	local targetSize = if isHovered
		then addSizeDelta(boundState.defaultSize, boundState.config.hoverSizeDelta)
		else boundState.defaultSize
	local targetStrokeColor = if isHovered then boundState.config.hoverStrokeColor else boundState.defaultStrokeColor

	local sizeTween = TweenService:Create(boundState.button, boundState.config.tweenInfo, {
		Size = targetSize,
	})
	local strokeTween = TweenService:Create(boundState.stroke, boundState.config.tweenInfo, {
		Color = targetStrokeColor,
	})

	boundState.activeSizeTween = sizeTween
	boundState.activeStrokeTween = strokeTween

	sizeTween:Play()
	strokeTween:Play()
end

local function unbindButton(button: GuiButtonLike)
	local boundState = boundStatesByButton[button]
	if boundState == nil then
		return
	end

	cancelTweens(boundState)
	boundState.button.Size = boundState.defaultSize
	boundState.stroke.Color = boundState.defaultStrokeColor
	boundState.button.AutoButtonColor = boundState.defaultAutoButtonColor

	for _, connection in ipairs(boundState.connections) do
		connection:Disconnect()
	end

	boundStatesByButton[button] = nil
end

local function bindButton(button: GuiButtonLike)
	if boundStatesByButton[button] ~= nil then
		return
	end

	local variantConfig = getVariantConfig(button)
	if variantConfig == nil then
		return
	end

	local designFrame = getDesignFrame(button)
	if designFrame == nil then
		return
	end

	local stroke = getStroke(designFrame)
	if stroke == nil then
		return
	end

	local boundState: BoundButtonState = {
		button = button,
		designFrame = designFrame,
		stroke = stroke,
		config = variantConfig,
		defaultAutoButtonColor = button.AutoButtonColor,
		defaultSize = button.Size,
		defaultStrokeColor = stroke.Color,
		activeSizeTween = nil,
		activeStrokeTween = nil,
		connections = {},
	}

	button.AutoButtonColor = false

	table.insert(boundState.connections, button.MouseEnter:Connect(function()
		tweenToState(boundState, true)
	end))
	table.insert(boundState.connections, button.MouseLeave:Connect(function()
		tweenToState(boundState, false)
	end))
	table.insert(boundState.connections, button.Destroying:Connect(function()
		unbindButton(button)
	end))

	boundStatesByButton[button] = boundState
end

local function bindDescendantTree(rootGui: ScreenGui)
	for _, descendant in ipairs(rootGui:GetDescendants()) do
		if isGuiButtonLike(descendant) then
			bindButton(descendant :: GuiButtonLike)
		end
	end
end

local ButtonHoverController = {} :: ButtonHoverController

function ButtonHoverController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before starting ButtonHoverController")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild(ROOT_GUI_NAME)
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")

	bindDescendantTree(rootGui)

	rootConnection = rootGui.DescendantAdded:Connect(function(descendant: Instance)
		if isGuiButtonLike(descendant) then
			bindButton(descendant :: GuiButtonLike)
			return
		end

		local current: Instance? = descendant.Parent
		while current ~= nil and current ~= rootGui do
			if isGuiButtonLike(current) then
				bindButton(current :: GuiButtonLike)
				return
			end
			current = current.Parent
		end
	end)
end

function ButtonHoverController.destroy()
	if rootConnection ~= nil then
		rootConnection:Disconnect()
		rootConnection = nil
	end

	for button in pairs(table.clone(boundStatesByButton)) do
		unbindButton(button)
	end

	hasStarted = false
end

return table.freeze(ButtonHoverController)

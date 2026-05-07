--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

type GuiButtonLike = TextButton | ImageButton

type VariantConfig = {
	hoverSizeDelta: UDim2,
	hoverStrokeColor: Color3?,
	hoverImageRotationRange: NumberRange?,
	idleImageRotationRange: NumberRange?,
	idleSwingTweenInfo: TweenInfo?,
	idleActiveDurationSeconds: number?,
	idlePauseDurationSeconds: number?,
	tweenInfo: TweenInfo,
}

type BoundButtonState = {
	button: GuiButtonLike,
	stroke: UIStroke?,
	imageLabel: ImageLabel?,
	config: VariantConfig,
	defaultAutoButtonColor: boolean,
	defaultSize: UDim2,
	defaultStrokeColor: Color3?,
	defaultImageRotation: number?,
	activeSizeTween: Tween?,
	activeStrokeTween: Tween?,
	activeImageTween: Tween?,
	activeIdleImageTween: Tween?,
	idleAnimationToken: number,
	isHovered: boolean,
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
	Side = {
		hoverSizeDelta = UDim2.fromScale(0.05, 0.05),
		hoverImageRotationRange = NumberRange.new(-30, 30),
		tweenInfo = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	},
	Store = {
		hoverSizeDelta = UDim2.fromScale(0.05, 0.05),
		hoverImageRotationRange = NumberRange.new(-30, 30),
		idleImageRotationRange = NumberRange.new(-30, 30),
		idleSwingTweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		idleActiveDurationSeconds = 1,
		idlePauseDurationSeconds = 2,
		tweenInfo = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	},
}

local hasStarted = false
local rootConnection: RBXScriptConnection? = nil
local boundStatesByButton: { [GuiButtonLike]: BoundButtonState } = {}
local randomGenerator = Random.new()
local IDLE_WAIT_STEP_SECONDS = 0.1

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

local function getImageLabel(button: GuiButtonLike): ImageLabel?
	local imageLabel = button:FindFirstChild("Image", true)
	if imageLabel == nil then
		return nil
	end

	if not imageLabel:IsA("ImageLabel") then
		warn(string.format("%s.Image must be an ImageLabel for hover styling", button:GetFullName()))
		return nil
	end

	return imageLabel
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

	local activeImageTween = boundState.activeImageTween
	if activeImageTween ~= nil then
		activeImageTween:Cancel()
		boundState.activeImageTween = nil
	end
end

local function cancelIdleTween(boundState: BoundButtonState)
	local activeIdleImageTween = boundState.activeIdleImageTween
	if activeIdleImageTween ~= nil then
		activeIdleImageTween:Cancel()
		boundState.activeIdleImageTween = nil
	end
end

local function stopIdleAnimation(boundState: BoundButtonState)
	boundState.idleAnimationToken += 1
	cancelIdleTween(boundState)
end

local function waitForDurationWhileIdle(boundState: BoundButtonState, token: number, durationSeconds: number): boolean
	local elapsedSeconds = 0
	while elapsedSeconds < durationSeconds do
		if boundStatesByButton[boundState.button] ~= boundState or boundState.idleAnimationToken ~= token or boundState.isHovered then
			return false
		end

		local waitSeconds = math.min(IDLE_WAIT_STEP_SECONDS, durationSeconds - elapsedSeconds)
		task.wait(waitSeconds)
		elapsedSeconds += waitSeconds
	end

	return true
end

local function getIdleTargetRotation(rotationRange: NumberRange, directionSign: number): number
	if directionSign >= 0 then
		return randomGenerator:NextNumber(0, rotationRange.Max)
	end

	return randomGenerator:NextNumber(rotationRange.Min, 0)
end

local function startIdleAnimation(boundState: BoundButtonState, initialDelaySeconds: number)
	local imageLabel = boundState.imageLabel
	local defaultImageRotation = boundState.defaultImageRotation
	local idleImageRotationRange = boundState.config.idleImageRotationRange
	local idleSwingTweenInfo = boundState.config.idleSwingTweenInfo
	local idleActiveDurationSeconds = boundState.config.idleActiveDurationSeconds
	local idlePauseDurationSeconds = boundState.config.idlePauseDurationSeconds
	if imageLabel == nil
		or defaultImageRotation == nil
		or idleImageRotationRange == nil
		or idleSwingTweenInfo == nil
		or idleActiveDurationSeconds == nil
		or idlePauseDurationSeconds == nil
	then
		return
	end

	stopIdleAnimation(boundState)
	local token = boundState.idleAnimationToken

	task.spawn(function()
		if initialDelaySeconds > 0 and not waitForDurationWhileIdle(boundState, token, initialDelaySeconds) then
			return
		end

		local directionSign = if randomGenerator:NextInteger(0, 1) == 0 then -1 else 1
		while boundStatesByButton[boundState.button] == boundState and boundState.idleAnimationToken == token do
			if boundState.isHovered then
				task.wait(IDLE_WAIT_STEP_SECONDS)
				continue
			end

			local activeEndTime = os.clock() + idleActiveDurationSeconds
			while os.clock() < activeEndTime do
				if boundStatesByButton[boundState.button] ~= boundState or boundState.idleAnimationToken ~= token or boundState.isHovered then
					return
				end

				local targetRotation = getIdleTargetRotation(idleImageRotationRange, directionSign)
				directionSign *= -1

				local idleTween = TweenService:Create(imageLabel, idleSwingTweenInfo, {
					Rotation = targetRotation,
				})
				boundState.activeIdleImageTween = idleTween
				idleTween:Play()
				local playbackState = idleTween.Completed:Wait()
				if playbackState ~= Enum.PlaybackState.Completed then
					return
				end
			end

			if boundStatesByButton[boundState.button] ~= boundState or boundState.idleAnimationToken ~= token or boundState.isHovered then
				return
			end

			local resetTween = TweenService:Create(imageLabel, idleSwingTweenInfo, {
				Rotation = defaultImageRotation,
			})
			boundState.activeIdleImageTween = resetTween
			resetTween:Play()
			local playbackState = resetTween.Completed:Wait()
			if playbackState ~= Enum.PlaybackState.Completed then
				return
			end

			if not waitForDurationWhileIdle(boundState, token, idlePauseDurationSeconds) then
				return
			end
		end
	end)
end

local function tweenToState(boundState: BoundButtonState, isHovered: boolean)
	boundState.isHovered = isHovered
	if isHovered then
		stopIdleAnimation(boundState)
	end

	cancelTweens(boundState)

	local targetSize = if isHovered
		then addSizeDelta(boundState.defaultSize, boundState.config.hoverSizeDelta)
		else boundState.defaultSize
	local sizeTween = TweenService:Create(boundState.button, boundState.config.tweenInfo, {
		Size = targetSize,
	})

	boundState.activeSizeTween = sizeTween
	sizeTween:Play()

	local stroke = boundState.stroke
	local defaultStrokeColor = boundState.defaultStrokeColor
	local hoverStrokeColor = boundState.config.hoverStrokeColor
	if stroke ~= nil and defaultStrokeColor ~= nil and hoverStrokeColor ~= nil then
		local targetStrokeColor = if isHovered then hoverStrokeColor else defaultStrokeColor
		local strokeTween = TweenService:Create(stroke, boundState.config.tweenInfo, {
			Color = targetStrokeColor,
		})
		boundState.activeStrokeTween = strokeTween
		strokeTween:Play()
	end

	local imageLabel = boundState.imageLabel
	local defaultImageRotation = boundState.defaultImageRotation
	local hoverImageRotationRange = boundState.config.hoverImageRotationRange
	if imageLabel ~= nil and defaultImageRotation ~= nil and hoverImageRotationRange ~= nil then
		local targetRotation = if isHovered
			then randomGenerator:NextNumber(hoverImageRotationRange.Min, hoverImageRotationRange.Max)
			else defaultImageRotation
		local imageTween = TweenService:Create(imageLabel, boundState.config.tweenInfo, {
			Rotation = targetRotation,
		})
		boundState.activeImageTween = imageTween
		imageTween:Play()
	end

	if not isHovered then
		startIdleAnimation(boundState, boundState.config.tweenInfo.Time)
	end
end

local function unbindButton(button: GuiButtonLike)
	local boundState = boundStatesByButton[button]
	if boundState == nil then
		return
	end

	stopIdleAnimation(boundState)
	cancelTweens(boundState)
	boundState.button.Size = boundState.defaultSize
	boundState.button.AutoButtonColor = boundState.defaultAutoButtonColor

	local stroke = boundState.stroke
	local defaultStrokeColor = boundState.defaultStrokeColor
	if stroke ~= nil and defaultStrokeColor ~= nil then
		stroke.Color = defaultStrokeColor
	end

	local imageLabel = boundState.imageLabel
	local defaultImageRotation = boundState.defaultImageRotation
	if imageLabel ~= nil and defaultImageRotation ~= nil then
		imageLabel.Rotation = defaultImageRotation
	end

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

	local stroke: UIStroke? = nil
	local defaultStrokeColor: Color3? = nil
	local hoverStrokeColor = variantConfig.hoverStrokeColor
	if hoverStrokeColor ~= nil then
		local designFrame = getDesignFrame(button)
		if designFrame == nil then
			return
		end

		stroke = getStroke(designFrame)
		if stroke == nil then
			return
		end

		defaultStrokeColor = stroke.Color
	end

	local imageLabel: ImageLabel? = nil
	local defaultImageRotation: number? = nil
	local hoverImageRotationRange = variantConfig.hoverImageRotationRange
	if hoverImageRotationRange ~= nil then
		imageLabel = getImageLabel(button)
		if imageLabel == nil then
			return
		end

		defaultImageRotation = imageLabel.Rotation
	end

	local boundState: BoundButtonState = {
		button = button,
		stroke = stroke,
		imageLabel = imageLabel,
		config = variantConfig,
		defaultAutoButtonColor = button.AutoButtonColor,
		defaultSize = button.Size,
		defaultStrokeColor = defaultStrokeColor,
		defaultImageRotation = defaultImageRotation,
		activeSizeTween = nil,
		activeStrokeTween = nil,
		activeImageTween = nil,
		activeIdleImageTween = nil,
		idleAnimationToken = 0,
		isHovered = false,
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
	startIdleAnimation(boundState, 0)
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

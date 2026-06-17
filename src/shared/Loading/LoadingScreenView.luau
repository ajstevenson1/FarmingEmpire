--!strict

local TweenService = game:GetService("TweenService")

local LoadingScreenConfigModule = require(script.Parent.LoadingScreenConfig)

type LoadingScreenConfig = LoadingScreenConfigModule.LoadingScreenConfig

export type LoadingScreenView = {
	_gui: ScreenGui,
	_root: Frame,
	_content: Frame,
	_image: ImageLabel,
	_progressLabel: TextLabel,
	_skipButton: TextButton,
	_rockTween: Tween?,
	setProgress: (self: LoadingScreenView, loadedCount: number, totalCount: number) -> (),
	setSkipVisible: (self: LoadingScreenView, isVisible: boolean) -> (),
	connectSkipRequested: (self: LoadingScreenView, callback: () -> ()) -> RBXScriptConnection,
	playExit: (self: LoadingScreenView, onComplete: () -> ()) -> (),
	destroy: (self: LoadingScreenView) -> (),
}

local LoadingScreenView = {}
LoadingScreenView.__index = LoadingScreenView

local function addStroke(parent: GuiObject, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = 0.05
	stroke.Parent = parent
	return stroke
end

local function addCorner(parent: GuiObject, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function createRoot(config: LoadingScreenConfig): (ScreenGui, Frame, Frame, ImageLabel, TextLabel, TextButton)
	local gui = Instance.new("ScreenGui")
	gui.Name = "LoadingScreen"
	gui.DisplayOrder = config.DisplayOrder
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundColor3 = Color3.fromRGB(47, 178, 78)
	root.BorderSizePixel = 0
	root.Position = UDim2.fromScale(0, 0)
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = config.BackgroundZIndex
	root.Parent = gui

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(163, 238, 98)),
		ColorSequenceKeypoint.new(0.48, Color3.fromRGB(54, 190, 90)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 113, 76)),
	})
	gradient.Rotation = 35
	gradient.Parent = root

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromScale(0.5, 0.5)
	content.Size = UDim2.fromOffset(420, 380)
	content.ZIndex = config.ContentZIndex
	content.Parent = root

	local image = Instance.new("ImageLabel")
	image.Name = "LoadingImage"
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.BackgroundTransparency = 1
	image.Image = config.AssetImageId
	image.Position = UDim2.fromScale(0.5, 0.38)
	image.Rotation = -7
	image.Size = UDim2.fromOffset(220, 220)
	image.ScaleType = Enum.ScaleType.Fit
	image.ZIndex = config.ContentZIndex
	image.Parent = content

	local progressLabel = Instance.new("TextLabel")
	progressLabel.Name = "ProgressLabel"
	progressLabel.AnchorPoint = Vector2.new(0.5, 0)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Font = Enum.Font.FredokaOne
	progressLabel.Position = UDim2.fromScale(0.5, 0.68)
	progressLabel.Size = UDim2.new(1, -24, 0, 54)
	progressLabel.Text = "Loading assets... 0/0"
	progressLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	progressLabel.TextScaled = true
	progressLabel.TextStrokeColor3 = Color3.fromRGB(20, 72, 34)
	progressLabel.TextStrokeTransparency = 0.1
	progressLabel.ZIndex = config.ContentZIndex
	progressLabel.Parent = content
	addStroke(progressLabel, Color3.fromRGB(20, 72, 34), 2)

	local textSizeConstraint = Instance.new("UITextSizeConstraint")
	textSizeConstraint.MaxTextSize = 42
	textSizeConstraint.MinTextSize = 18
	textSizeConstraint.Parent = progressLabel

	local skipButton = Instance.new("TextButton")
	skipButton.Name = "SkipButton"
	skipButton.AnchorPoint = Vector2.new(0.5, 0)
	skipButton.AutoButtonColor = true
	skipButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	skipButton.BackgroundTransparency = 0.12
	skipButton.Font = Enum.Font.FredokaOne
	skipButton.Position = UDim2.fromScale(0.5, 0.84)
	skipButton.Size = UDim2.fromOffset(154, 44)
	skipButton.Text = "Skip"
	skipButton.TextColor3 = Color3.fromRGB(23, 111, 62)
	skipButton.TextSize = 24
	skipButton.Visible = false
	skipButton.ZIndex = config.SkipButtonZIndex
	skipButton.Parent = content
	addCorner(skipButton, 8)
	addStroke(skipButton, Color3.fromRGB(18, 93, 47), 2)

	return gui, root, content, image, progressLabel, skipButton
end

function LoadingScreenView.new(parent: Instance): LoadingScreenView
	local gui, root, content, image, progressLabel, skipButton = createRoot(LoadingScreenConfigModule)
	gui.Parent = parent

	local rockTween = TweenService:Create(image, LoadingScreenConfigModule.RockTweenInfo, {
		Rotation = 7,
	})
	rockTween:Play()

	local self = setmetatable({
		_gui = gui,
		_root = root,
		_content = content,
		_image = image,
		_progressLabel = progressLabel,
		_skipButton = skipButton,
		_rockTween = rockTween,
	}, LoadingScreenView) :: LoadingScreenView

	return self
end

function LoadingScreenView:setProgress(loadedCount: number, totalCount: number)
	local safeLoadedCount = math.max(0, math.floor(loadedCount))
	local safeTotalCount = math.max(safeLoadedCount, math.floor(totalCount))
	self._progressLabel.Text = string.format("Loading assets... %d/%d", safeLoadedCount, safeTotalCount)
end

function LoadingScreenView:setSkipVisible(isVisible: boolean)
	self._skipButton.Visible = isVisible
end

function LoadingScreenView:connectSkipRequested(callback: () -> ()): RBXScriptConnection
	return self._skipButton.Activated:Connect(callback)
end

function LoadingScreenView:playExit(onComplete: () -> ())
	local rockTween = self._rockTween
	if rockTween ~= nil then
		rockTween:Cancel()
		self._rockTween = nil
	end

	TweenService:Create(self._content, LoadingScreenConfigModule.ProgressTweenInfo, {
		Rotation = -5,
		Position = UDim2.fromScale(0.5, 0.58),
	}):Play()

	local exitTween = TweenService:Create(self._root, LoadingScreenConfigModule.ExitTweenInfo, {
		Position = UDim2.fromScale(0, 1.15),
	})

	local completedConnection: RBXScriptConnection? = nil
	completedConnection = exitTween.Completed:Connect(function()
		if completedConnection ~= nil then
			completedConnection:Disconnect()
			completedConnection = nil
		end

		onComplete()
	end)

	exitTween:Play()
end

function LoadingScreenView:destroy()
	local rockTween = self._rockTween
	if rockTween ~= nil then
		rockTween:Cancel()
		self._rockTween = nil
	end

	self._gui:Destroy()
end

return LoadingScreenView

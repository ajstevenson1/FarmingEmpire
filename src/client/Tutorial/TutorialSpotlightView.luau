--!strict

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local TutorialTargetResolver = require(script.Parent.TutorialTargetResolver)

type RectDefinition = {
	x: number,
	y: number,
	width: number,
	height: number,
}

export type TutorialSpotlightView = {
	_rootGui: ScreenGui,
	_frames: { Frame },
	_targetName: string,
	_updateConnection: RBXScriptConnection?,
	_slideTweens: { Tween },
	_slideCompletedCount: number,
	_hasVisibleRects: boolean,
	_isSlidingIn: boolean,
	_cancelSlideTweens: (self: TutorialSpotlightView) -> (),
	_getRects: (self: TutorialSpotlightView) -> { RectDefinition }?,
	_applyRects: (self: TutorialSpotlightView, rects: { RectDefinition }) -> (),
	_slideIn: (self: TutorialSpotlightView, rects: { RectDefinition }) -> (),
	_ensureUpdateConnection: (self: TutorialSpotlightView) -> (),
	_update: (self: TutorialSpotlightView) -> (),
	show: (self: TutorialSpotlightView, targetName: string) -> (),
	hide: (self: TutorialSpotlightView) -> (),
	destroy: (self: TutorialSpotlightView) -> (),
}

local FRAME_Z_INDEX = 15
local PADDING_PIXELS = 18
local PANEL_OVERLAP_PIXELS = 0
local OUTER_OVERSCAN_PIXELS = 96
local TARGET_Y_OFFSET_SCALE = 0
local VISIBLE_TRANSPARENCY = 0.5
local SLIDE_TWEEN_INFO = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local TutorialSpotlightView = {}
TutorialSpotlightView.__index = TutorialSpotlightView

local function createOverlayFrame(rootGui: ScreenGui, name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Active = false
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = VISIBLE_TRANSPARENCY
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = FRAME_Z_INDEX
	frame.Parent = rootGui
	return frame
end

local function setFrameRect(frame: Frame, x: number, y: number, width: number, height: number)
	frame.Position = UDim2.fromOffset(x, y)
	frame.Size = UDim2.fromOffset(math.max(width, 0), math.max(height, 0))
	frame.Visible = width > 0 and height > 0
end

function TutorialSpotlightView.new(rootGui: ScreenGui): TutorialSpotlightView
	return setmetatable({
		_rootGui = rootGui,
		_frames = {
			createOverlayFrame(rootGui, "TutorialSpotlightTop"),
			createOverlayFrame(rootGui, "TutorialSpotlightBottom"),
			createOverlayFrame(rootGui, "TutorialSpotlightLeft"),
			createOverlayFrame(rootGui, "TutorialSpotlightRight"),
		},
		_targetName = "None",
		_updateConnection = nil,
		_slideTweens = {},
		_slideCompletedCount = 0,
		_hasVisibleRects = false,
		_isSlidingIn = false,
	}, TutorialSpotlightView) :: TutorialSpotlightView
end

function TutorialSpotlightView:_cancelSlideTweens()
	for _, tween in ipairs(self._slideTweens) do
		tween:Cancel()
	end
	table.clear(self._slideTweens)
	self._slideCompletedCount = 0
	self._isSlidingIn = false
end

function TutorialSpotlightView:_getRects(): { RectDefinition }?
	local target = TutorialTargetResolver.getGuiTarget(self._targetName)
	if target == nil or not target.Visible then
		return nil
	end

	local rootSize = self._rootGui.AbsoluteSize
	local rootPosition = self._rootGui.AbsolutePosition
	local targetPosition = target.AbsolutePosition - rootPosition
	local targetSize = target.AbsoluteSize
	local targetYOffset = targetSize.Y * TARGET_Y_OFFSET_SCALE
	local left = math.max(0, targetPosition.X - PADDING_PIXELS)
	local top = math.max(0, targetPosition.Y + targetYOffset - PADDING_PIXELS)
	local right = math.min(rootSize.X, targetPosition.X + targetSize.X + PADDING_PIXELS)
	local bottom = math.min(rootSize.Y, targetPosition.Y + targetYOffset + targetSize.Y + PADDING_PIXELS)

	return {
		{
			x = -OUTER_OVERSCAN_PIXELS,
			y = -OUTER_OVERSCAN_PIXELS,
			width = rootSize.X + OUTER_OVERSCAN_PIXELS * 2,
			height = top + PANEL_OVERLAP_PIXELS + OUTER_OVERSCAN_PIXELS,
		},
		{
			x = -OUTER_OVERSCAN_PIXELS,
			y = bottom - PANEL_OVERLAP_PIXELS,
			width = rootSize.X + OUTER_OVERSCAN_PIXELS * 2,
			height = rootSize.Y - bottom + PANEL_OVERLAP_PIXELS + OUTER_OVERSCAN_PIXELS,
		},
		{
			x = -OUTER_OVERSCAN_PIXELS,
			y = top - PANEL_OVERLAP_PIXELS,
			width = left + PANEL_OVERLAP_PIXELS + OUTER_OVERSCAN_PIXELS,
			height = bottom - top + PANEL_OVERLAP_PIXELS * 2,
		},
		{
			x = right - PANEL_OVERLAP_PIXELS,
			y = top - PANEL_OVERLAP_PIXELS,
			width = rootSize.X - right + PANEL_OVERLAP_PIXELS + OUTER_OVERSCAN_PIXELS,
			height = bottom - top + PANEL_OVERLAP_PIXELS * 2,
		},
	}
end

function TutorialSpotlightView:_applyRects(rects: { RectDefinition })
	for index, rect in ipairs(rects) do
		setFrameRect(self._frames[index], rect.x, rect.y, rect.width, rect.height)
	end
	self._hasVisibleRects = true
end

function TutorialSpotlightView:_slideIn(rects: { RectDefinition })
	self:_cancelSlideTweens()
	self._isSlidingIn = true

	local rootSize = self._rootGui.AbsoluteSize
	local startRects: { RectDefinition } = {
		{ x = rects[1].x, y = -rects[1].height, width = rects[1].width, height = rects[1].height },
		{ x = rects[2].x, y = rootSize.Y, width = rects[2].width, height = rects[2].height },
		{ x = -rects[3].width, y = rects[3].y, width = rects[3].width, height = rects[3].height },
		{ x = rootSize.X, y = rects[4].y, width = rects[4].width, height = rects[4].height },
	}

	self:_applyRects(startRects)
	for index, rect in ipairs(rects) do
		local frame = self._frames[index]
		local tween = TweenService:Create(frame, SLIDE_TWEEN_INFO, {
			Position = UDim2.fromOffset(rect.x, rect.y),
			Size = UDim2.fromOffset(math.max(rect.width, 0), math.max(rect.height, 0)),
		})
		table.insert(self._slideTweens, tween)
		tween.Completed:Connect(function(playbackState: Enum.PlaybackState)
			if playbackState ~= Enum.PlaybackState.Completed then
				return
			end

			self._slideCompletedCount += 1
			if self._slideCompletedCount >= #self._frames and self._targetName ~= "None" and self._updateConnection == nil then
				self._isSlidingIn = false
				self._updateConnection = RunService.RenderStepped:Connect(function()
					self:_update()
				end)
			elseif self._slideCompletedCount >= #self._frames then
				self._isSlidingIn = false
			end
		end)
		tween:Play()
	end
end

function TutorialSpotlightView:_ensureUpdateConnection()
	if self._updateConnection ~= nil then
		return
	end

	self._updateConnection = RunService.RenderStepped:Connect(function()
		self:_update()
	end)
end

function TutorialSpotlightView:_update()
	local rects = self:_getRects()
	if rects == nil then
		for _, frame in ipairs(self._frames) do
			frame.Visible = false
		end
		self._hasVisibleRects = false
		return
	end

	if self._isSlidingIn then
		return
	end

	if self._hasVisibleRects then
		self:_applyRects(rects)
	else
		self:_slideIn(rects)
	end
end

function TutorialSpotlightView:show(targetName: string)
	local shouldSlideIn = self._targetName ~= targetName
	self._targetName = targetName
	local rects = self:_getRects()
	if rects == nil then
		if shouldSlideIn then
			self:_cancelSlideTweens()
			self._hasVisibleRects = false
			for _, frame in ipairs(self._frames) do
				frame.Visible = false
			end
		end
		self:_ensureUpdateConnection()
		return
	end

	if shouldSlideIn then
		if self._updateConnection ~= nil then
			self._updateConnection:Disconnect()
			self._updateConnection = nil
		end
		self:_slideIn(rects)
	else
		if self._updateConnection == nil then
			self._updateConnection = RunService.RenderStepped:Connect(function()
				self:_update()
			end)
		end
		self:_applyRects(rects)
	end
end

function TutorialSpotlightView:hide()
	self._targetName = "None"
	self:_cancelSlideTweens()
	self._hasVisibleRects = false
	if self._updateConnection ~= nil then
		self._updateConnection:Disconnect()
		self._updateConnection = nil
	end

	for _, frame in ipairs(self._frames) do
		frame.Visible = false
	end
end

function TutorialSpotlightView:destroy()
	self:hide()
	for _, frame in ipairs(self._frames) do
		frame:Destroy()
	end
	table.clear(self._frames)
end

return TutorialSpotlightView

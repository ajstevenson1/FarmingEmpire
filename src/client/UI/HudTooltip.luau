--!strict

local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before using HUD tooltip")

export type HudTooltip = {
	_frame: Frame,
	_textLabel: TextLabel,
	_ownerId: string?,
	show: (self: HudTooltip, text: string, richText: boolean?, ownerId: string?) -> (),
	hide: (self: HudTooltip, ownerId: string?) -> (),
}

local HudTooltip = {}
HudTooltip.__index = HudTooltip

local singleton: HudTooltip? = nil

local function getTooltipWidgets(): (Frame, TextLabel)
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild("GUI")
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")

	local hud = rootGui:WaitForChild("HUD")
	assert(hud:IsA("Frame"), "GUI.HUD must be a Frame")

	local tooltipFrame = hud:WaitForChild("Tooltip")
	assert(tooltipFrame:IsA("Frame"), "GUI.HUD.Tooltip must be a Frame")

	local textLabel = tooltipFrame:WaitForChild("Text")
	assert(textLabel:IsA("TextLabel"), "GUI.HUD.Tooltip.Text must be a TextLabel")

	return tooltipFrame, textLabel
end

function HudTooltip.get(): HudTooltip
	if singleton ~= nil then
		return singleton
	end

	local tooltipFrame, textLabel = getTooltipWidgets()
	local self = setmetatable({
		_frame = tooltipFrame,
		_textLabel = textLabel,
		_ownerId = nil,
	}, HudTooltip) :: HudTooltip
	self:hide()

	singleton = self
	return self
end

function HudTooltip:show(text: string, richText: boolean?, ownerId: string?)
	self._ownerId = ownerId
	self._textLabel.RichText = richText == true
	self._textLabel.Text = text
	self._frame.Visible = true
end

function HudTooltip:hide(ownerId: string?)
	if ownerId ~= nil and self._ownerId ~= nil and self._ownerId ~= ownerId then
		return
	end

	self._ownerId = nil
	self._frame.Visible = false
end

return table.freeze(HudTooltip)

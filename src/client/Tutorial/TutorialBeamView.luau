--!strict

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local TutorialTargetResolver = require(script.Parent.TutorialTargetResolver)

export type TutorialBeamView = {
	_beamTargetName: string,
	_beam: Beam?,
	_startAttachment: Attachment?,
	_endAttachment: Attachment?,
	_updateConnection: RBXScriptConnection?,
	_clearBeamInstances: (self: TutorialBeamView) -> (),
	_update: (self: TutorialBeamView) -> (),
	show: (self: TutorialBeamView, beamTargetName: string) -> (),
	hide: (self: TutorialBeamView) -> (),
	destroy: (self: TutorialBeamView) -> (),
}

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before creating TutorialBeamView")

local TutorialBeamView = {}
TutorialBeamView.__index = TutorialBeamView

local function getRootPart(): BasePart?
	local character = localPlayer.Character
	if character == nil then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart ~= nil and rootPart:IsA("BasePart") then
		return rootPart
	end

	return nil
end

local function createBeam(startAttachment: Attachment, endAttachment: Attachment): Beam
	local beam = Instance.new("Beam")
	beam.Name = "TutorialTargetBeam"
	beam.Attachment0 = startAttachment
	beam.Attachment1 = endAttachment
	beam.Color = ColorSequence.new(Color3.fromRGB(63, 221, 113))
	beam.FaceCamera = true
	beam.LightEmission = 0.35
	beam.Segments = 10
	beam.Transparency = NumberSequence.new(0.05)
	beam.Width0 = 0.35
	beam.Width1 = 0.12
	beam.Parent = startAttachment
	return beam
end

function TutorialBeamView.new(): TutorialBeamView
	return setmetatable({
		_beamTargetName = "None",
		_beam = nil,
		_startAttachment = nil,
		_endAttachment = nil,
		_updateConnection = nil,
	}, TutorialBeamView) :: TutorialBeamView
end

function TutorialBeamView:_clearBeamInstances()
	if self._beam ~= nil then
		self._beam:Destroy()
		self._beam = nil
	end
	if self._startAttachment ~= nil then
		self._startAttachment:Destroy()
		self._startAttachment = nil
	end
	if self._endAttachment ~= nil then
		self._endAttachment:Destroy()
		self._endAttachment = nil
	end
end

function TutorialBeamView:_update()
	local rootPart = getRootPart()
	local targetPart = TutorialTargetResolver.getPlacedBuildingTarget(self._beamTargetName)
	if rootPart == nil or targetPart == nil then
		self:_clearBeamInstances()
		return
	end

	if self._beam ~= nil and self._startAttachment ~= nil and self._startAttachment.Parent == rootPart
		and self._endAttachment ~= nil and self._endAttachment.Parent == targetPart
	then
		self._startAttachment.Position = Vector3.new(0, 2.6, 0)
		self._endAttachment.Position = Vector3.new(0, math.max(targetPart.Size.Y * 0.5, 1), 0)
		return
	end

	self:_clearBeamInstances()

	local startAttachment = Instance.new("Attachment")
	startAttachment.Name = "TutorialBeamStart"
	startAttachment.Position = Vector3.new(0, 2.6, 0)
	startAttachment.Parent = rootPart

	local endAttachment = Instance.new("Attachment")
	endAttachment.Name = "TutorialBeamEnd"
	endAttachment.Position = Vector3.new(0, math.max(targetPart.Size.Y * 0.5, 1), 0)
	endAttachment.Parent = targetPart

	self._startAttachment = startAttachment
	self._endAttachment = endAttachment
	self._beam = createBeam(startAttachment, endAttachment)
end

function TutorialBeamView:show(beamTargetName: string)
	self._beamTargetName = beamTargetName
	if self._updateConnection == nil then
		self._updateConnection = RunService.RenderStepped:Connect(function()
			self:_update()
		end)
	end
	self:_update()
end

function TutorialBeamView:hide()
	self._beamTargetName = "None"
	if self._updateConnection ~= nil then
		self._updateConnection:Disconnect()
		self._updateConnection = nil
	end
	self:_clearBeamInstances()
end

function TutorialBeamView:destroy()
	self:hide()
end

return TutorialBeamView

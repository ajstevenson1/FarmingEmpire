--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TutorialTargetResolver = require(script.Parent.TutorialTargetResolver)

export type TutorialBeamView = {
	_beamTargetName: string,
	_arrowPart: Part?,
	_arrowTexture: Texture?,
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

local ARROW_TEXTURE = "rbxassetid://10249261576"
local ARROW_STRIP_WIDTH_STUDS = 4
local ARROW_STRIP_THICKNESS_STUDS = 0.05
local ARROW_STRIP_HEIGHT_STUDS = 0.08
local ARROW_TEXTURE_TILE_WIDTH_STUDS = 4
local ARROW_TEXTURE_TILE_LENGTH_STUDS = 4
local ARROW_TEXTURE_SPEED_STUDS_PER_SECOND = 8
local BEAM_COLOR = Color3.fromRGB(255, 255, 255)

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

local function refreshArrowTextureAsync(arrowTexture: Texture)
	arrowTexture.Texture = ""

	task.defer(function()
		if arrowTexture.Parent == nil then
			return
		end

		arrowTexture.Texture = ARROW_TEXTURE
	end)

	task.delay(1, function()
		if arrowTexture.Parent == nil then
			return
		end

		arrowTexture.Texture = ""
		task.wait()
		if arrowTexture.Parent ~= nil then
			arrowTexture.Texture = ARROW_TEXTURE
		end
	end)
end

local function createArrowPart(): (Part, Texture)
	local arrowPart = Instance.new("Part")
	arrowPart.Name = "TutorialArrowGuide"
	arrowPart.Anchored = true
	arrowPart.CanCollide = false
	arrowPart.CanQuery = false
	arrowPart.CanTouch = false
	arrowPart.CastShadow = false
	arrowPart.Color = BEAM_COLOR
	arrowPart.Material = Enum.Material.SmoothPlastic
	arrowPart.Transparency = 0.99

	local arrowTexture = Instance.new("Texture")
	arrowTexture.Name = "ArrowTexture"
	arrowTexture.Face = Enum.NormalId.Top
	arrowTexture.Color3 = BEAM_COLOR
	arrowTexture.Transparency = 0
	arrowTexture.StudsPerTileU = ARROW_TEXTURE_TILE_WIDTH_STUDS
	arrowTexture.StudsPerTileV = ARROW_TEXTURE_TILE_LENGTH_STUDS
	arrowTexture.Parent = arrowPart

	arrowPart.Parent = workspace
	refreshArrowTextureAsync(arrowTexture)

	return arrowPart, arrowTexture
end

function TutorialBeamView.new(): TutorialBeamView
	return setmetatable({
		_beamTargetName = "None",
		_arrowPart = nil,
		_arrowTexture = nil,
		_updateConnection = nil,
	}, TutorialBeamView) :: TutorialBeamView
end

function TutorialBeamView:_clearBeamInstances()
	if self._arrowPart ~= nil then
		self._arrowPart:Destroy()
		self._arrowPart = nil
	end
	self._arrowTexture = nil
end

function TutorialBeamView:_update()
	local rootPart = getRootPart()
	local targetPart = TutorialTargetResolver.getPlacedBuildingTarget(self._beamTargetName)
	if rootPart == nil or targetPart == nil then
		self:_clearBeamInstances()
		return
	end

	local startPosition = rootPart.Position + Vector3.new(0, 0.25, 0)
	local endPosition = targetPart.Position + Vector3.new(0, math.max(targetPart.Size.Y * 0.5, 1), 0)
	local delta = endPosition - startPosition
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	local distance = flatDelta.Magnitude
	if distance <= 0.1 then
		self:_clearBeamInstances()
		return
	end

	if self._arrowPart == nil or self._arrowTexture == nil then
		local arrowPart, arrowTexture = createArrowPart()
		self._arrowPart = arrowPart
		self._arrowTexture = arrowTexture
	end

	local arrowPart = self._arrowPart :: Part
	local arrowTexture = self._arrowTexture :: Texture
	local direction = flatDelta.Unit
	local midpoint = startPosition + direction * (distance * 0.5)
	local stripPosition = Vector3.new(midpoint.X, startPosition.Y + ARROW_STRIP_HEIGHT_STUDS, midpoint.Z)

	arrowPart.Size = Vector3.new(ARROW_STRIP_WIDTH_STUDS, ARROW_STRIP_THICKNESS_STUDS, distance)
	arrowPart.CFrame = CFrame.lookAt(stripPosition, stripPosition + direction) * CFrame.Angles(0, math.pi, 0)
	arrowTexture.OffsetStudsV = os.clock() * ARROW_TEXTURE_SPEED_STUDS_PER_SECOND
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

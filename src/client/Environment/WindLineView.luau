--!strict

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local environmentFolder = sharedFolder:WaitForChild("Environment") :: Folder
local WindConfig = require(environmentFolder:WaitForChild("WindConfig") :: ModuleScript)

type WindLineConfig = WindConfig.WindLineConfig

type WindLineState = {
	attachment0: Attachment,
	attachment1: Attachment,
	trail: Trail,
	lifetimeSeconds: number,
	position: Vector3,
	direction: Vector3,
	speedStudsPerSecond: number,
	startedAt: number,
	seed: number,
}

export type WindLineView = {
	_config: WindLineConfig,
	_random: Random,
	_lines: { WindLineState },
	_updateConnection: RBXScriptConnection?,
	_lastSpawnedAt: number,
	_effectsFolder: Folder?,
	_attachmentHost: Part?,
	_getEffectsFolder: (self: WindLineView) -> Folder,
	_getAttachmentHost: (self: WindLineView) -> Part,
	_createLine: (self: WindLineView) -> (),
	_destroyLineAt: (self: WindLineView, index: number) -> (),
	_update: (self: WindLineView) -> (),
	start: (self: WindLineView) -> (),
	stop: (self: WindLineView) -> (),
	destroy: (self: WindLineView) -> (),
}

local CLIENT_EFFECTS_FOLDER_NAME = "ClientEffects"
local WIND_LINES_FOLDER_NAME = "WindLines"
local ATTACHMENT_HOST_NAME = "WindLineAttachmentHost"
local OFFSET_DIRECTION = Vector3.new(0, 1, 0)

local WindLineView = {}
WindLineView.__index = WindLineView

local function getOrCreateFolder(parent: Instance, folderName: string): Folder
	local existingFolder = parent:FindFirstChild(folderName)
	if existingFolder ~= nil then
		assert(existingFolder:IsA("Folder"), string.format("%s must be a Folder", existingFolder:GetFullName()))
		return existingFolder
	end

	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = parent
	return folder
end

function WindLineView.new(config: WindLineConfig?): WindLineView
	return setmetatable({
		_config = config or WindConfig.lines,
		_random = Random.new(),
		_lines = {},
		_updateConnection = nil,
		_lastSpawnedAt = 0,
		_effectsFolder = nil,
		_attachmentHost = nil,
	}, WindLineView) :: WindLineView
end

function WindLineView:_getEffectsFolder(): Folder
	local currentFolder = self._effectsFolder
	if currentFolder ~= nil and currentFolder.Parent ~= nil then
		return currentFolder
	end

	local clientEffectsFolder = getOrCreateFolder(Workspace, CLIENT_EFFECTS_FOLDER_NAME)
	local windLinesFolder = getOrCreateFolder(clientEffectsFolder, WIND_LINES_FOLDER_NAME)
	self._effectsFolder = windLinesFolder
	return windLinesFolder
end

function WindLineView:_getAttachmentHost(): Part
	local currentHost = self._attachmentHost
	if currentHost ~= nil and currentHost.Parent ~= nil then
		return currentHost
	end

	local effectsFolder = self:_getEffectsFolder()
	local existingHost = effectsFolder:FindFirstChild(ATTACHMENT_HOST_NAME)
	if existingHost ~= nil then
		assert(existingHost:IsA("Part"), string.format("%s must be a Part", existingHost:GetFullName()))
		self._attachmentHost = existingHost
		return existingHost
	end

	local host = Instance.new("Part")
	host.Name = ATTACHMENT_HOST_NAME
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.CastShadow = false
	host.Size = Vector3.new(1, 1, 1)
	host.Transparency = 1
	host.Parent = effectsFolder
	self._attachmentHost = host
	return host
end

function WindLineView:_destroyLineAt(index: number)
	local windLine = self._lines[index]
	if windLine == nil then
		return
	end

	windLine.attachment0:Destroy()
	windLine.attachment1:Destroy()
	windLine.trail:Destroy()

	local length = #self._lines
	self._lines[index] = self._lines[length]
	self._lines[length] = nil
end

function WindLineView:_createLine()
	local config = self._config
	local camera = Workspace.CurrentCamera
	if camera == nil or config.speedStudsPerSecond <= 0 or config.lifetimeSeconds <= 0 then
		return
	end

	while #self._lines >= config.maxActiveLines do
		self:_destroyLineAt(1)
	end

	local pitchRadians = math.rad(self._random:NextNumber(config.spawnPitchDegreesMin, config.spawnPitchDegreesMax))
	local yawRadians = math.rad(self._random:NextNumber(config.spawnYawDegreesMin, config.spawnYawDegreesMax))
	local distance = self._random:NextNumber(config.spawnDistanceStudsMin, config.spawnDistanceStudsMax)
	local position = (camera.CFrame * CFrame.Angles(pitchRadians, yawRadians, 0) * CFrame.new(0, 0, -distance)).Position
	local direction = if config.direction.Magnitude > 0 then config.direction.Unit else Vector3.new(1, 0, 0)

	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "WindLineAttachment0"
	attachment0.WorldPosition = position

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "WindLineAttachment1"
	attachment1.WorldPosition = position + OFFSET_DIRECTION * config.heightStuds

	local trail = Instance.new("Trail")
	trail.Name = "WindLineTrail"
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, config.widthStuds * 3),
		NumberSequenceKeypoint.new(0.2, config.widthStuds * 10),
		NumberSequenceKeypoint.new(0.8, config.widthStuds * 10),
		NumberSequenceKeypoint.new(1, config.widthStuds * 3),
	})
	trail.Transparency = NumberSequence.new(config.transparency)
	trail.FaceCamera = true
	trail.Parent = attachment0

	local attachmentHost = self:_getAttachmentHost()
	attachment0.Parent = attachmentHost
	attachment1.Parent = attachmentHost

	local lifetimeJitter = self._random:NextNumber(-config.lifetimeJitterSeconds, config.lifetimeJitterSeconds)
	local speedJitter = self._random:NextNumber(-config.speedJitterStudsPerSecond, config.speedJitterStudsPerSecond)

	table.insert(self._lines, {
		attachment0 = attachment0,
		attachment1 = attachment1,
		trail = trail,
		lifetimeSeconds = math.max(0.1, config.lifetimeSeconds + lifetimeJitter),
		position = position,
		direction = direction,
		speedStudsPerSecond = math.max(0.1, config.speedStudsPerSecond + speedJitter),
		startedAt = os.clock(),
		seed = self._random:NextNumber(0, 100),
	})
end

function WindLineView:_update()
	local config = self._config
	local now = os.clock()
	local spawnInterval = 1 / math.max(config.spawnRatePerSecond, 0.1)

	if now - self._lastSpawnedAt >= spawnInterval then
		self:_createLine()
		self._lastSpawnedAt = now
	end

	debug.profilebegin("WindLineView")
	for index = #self._lines, 1, -1 do
		local windLine = self._lines[index]
		local aliveTime = now - windLine.startedAt
		if aliveTime >= windLine.lifetimeSeconds then
			self:_destroyLineAt(index)
			continue
		end

		local lifetimeAlpha = aliveTime / windLine.lifetimeSeconds
		windLine.trail.MaxLength = config.maxTrailLengthStuds * (1 - lifetimeAlpha)

		local seededClock = (now + windLine.seed) * (windLine.speedStudsPerSecond * config.waveSpeedMultiplier)
		local waveOffset = Vector3.new(
			math.sin(seededClock) * config.waveAmplitudeStuds.X,
			math.sin(seededClock) * config.waveAmplitudeStuds.Y,
			math.sin(seededClock) * config.waveAmplitudeStuds.Z
		)

		local startPosition = windLine.position
		local movementCFrame = CFrame.lookAt(startPosition, startPosition + windLine.direction)
			* CFrame.new(0, 0, -windLine.speedStudsPerSecond * aliveTime)
		windLine.attachment0.WorldPosition = movementCFrame.Position + waveOffset
		windLine.attachment1.WorldPosition = windLine.attachment0.WorldPosition + OFFSET_DIRECTION * config.heightStuds
	end
	debug.profileend()
end

function WindLineView:start()
	if self._updateConnection ~= nil then
		return
	end

	self._lastSpawnedAt = os.clock()
	self._updateConnection = RunService.Heartbeat:Connect(function()
		self:_update()
	end)
end

function WindLineView:stop()
	if self._updateConnection ~= nil then
		self._updateConnection:Disconnect()
		self._updateConnection = nil
	end

	for index = #self._lines, 1, -1 do
		self:_destroyLineAt(index)
	end
end

function WindLineView:destroy()
	self:stop()
end

return WindLineView

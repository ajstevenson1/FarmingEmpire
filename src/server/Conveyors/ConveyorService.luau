--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local conveyorsFolder = sharedFolder:WaitForChild("Conveyors") :: Folder

local ConveyorConfig = require(conveyorsFolder:WaitForChild("ConveyorConfig") :: ModuleScript)

type ConveyorSettings = {
	speed: number,
	textureSpeedV: number,
}

type TrackedConveyor = {
	part: BasePart,
	speed: number,
	textureSpeedV: number,
	textures: { Texture },
}

local trackedConveyorsByPart: { [BasePart]: TrackedConveyor } = {}
local sourceConnections: { RBXScriptConnection } = {}
local tagConnections: { RBXScriptConnection } = {}
local hasStarted = false
local heartbeatConnection: RBXScriptConnection? = nil
local rebuildTrackedConveyors: () -> () = function() end

local function getNumberAttribute(instance: Instance, attributeName: string, fallback: number): number
	local value = instance:GetAttribute(attributeName)
	if type(value) == "number" then
		return value
	end

	return fallback
end

local function getSettings(source: Instance, part: BasePart): ConveyorSettings
	local sourceSpeed = getNumberAttribute(source, ConveyorConfig.speedAttributeName, ConveyorConfig.defaultConveyorSpeed)
	local sourceTextureSpeedV =
		getNumberAttribute(source, ConveyorConfig.textureSpeedVAttributeName, ConveyorConfig.defaultTextureSpeedV)

	return {
		speed = getNumberAttribute(part, ConveyorConfig.speedAttributeName, sourceSpeed),
		textureSpeedV = getNumberAttribute(part, ConveyorConfig.textureSpeedVAttributeName, sourceTextureSpeedV),
	}
end

local function getTextures(part: BasePart): { Texture }
	local textures: { Texture } = {}

	for _, descendant in ipairs(part:GetDescendants()) do
		if descendant:IsA("Texture") then
			table.insert(textures, descendant)
		end
	end

	return textures
end

local function trackPart(source: Instance, part: BasePart)
	if trackedConveyorsByPart[part] ~= nil then
		return
	end

	local settings = getSettings(source, part)

	part.AssemblyLinearVelocity = part.CFrame.LookVector * settings.speed
	trackedConveyorsByPart[part] = {
		part = part,
		speed = settings.speed,
		textureSpeedV = settings.textureSpeedV,
		textures = getTextures(part),
	}

	table.insert(sourceConnections, part:GetAttributeChangedSignal(ConveyorConfig.speedAttributeName):Connect(rebuildTrackedConveyors))
	table.insert(
		sourceConnections,
		part:GetAttributeChangedSignal(ConveyorConfig.textureSpeedVAttributeName):Connect(rebuildTrackedConveyors)
	)
end

local function trackSource(source: Instance)
	table.insert(sourceConnections, source:GetAttributeChangedSignal(ConveyorConfig.speedAttributeName):Connect(rebuildTrackedConveyors))
	table.insert(
		sourceConnections,
		source:GetAttributeChangedSignal(ConveyorConfig.textureSpeedVAttributeName):Connect(rebuildTrackedConveyors)
	)

	if source:IsA("BasePart") then
		trackPart(source, source)
		return
	end

	if not source:IsA("Model") then
		return
	end

	for _, descendant in ipairs(source:GetDescendants()) do
		if descendant:IsA("BasePart") then
			trackPart(source, descendant)
		end
	end
end

local function disconnectSourceConnections()
	for _, connection in ipairs(sourceConnections) do
		connection:Disconnect()
	end

	table.clear(sourceConnections)
end

local function isConveyorSource(instance: Instance): boolean
	return instance.Name == ConveyorConfig.fallbackInstanceName and (instance:IsA("BasePart") or instance:IsA("Model"))
end

local function addSource(sources: { Instance }, seenSources: { [Instance]: boolean }, source: Instance)
	if seenSources[source] then
		return
	end

	seenSources[source] = true
	table.insert(sources, source)
end

local function getConveyorSources(): { Instance }
	local sources: { Instance } = {}
	local seenSources: { [Instance]: boolean } = {}

	for _, source in ipairs(CollectionService:GetTagged(ConveyorConfig.tagName)) do
		if source:IsA("BasePart") or source:IsA("Model") then
			addSource(sources, seenSources, source)
		end
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if isConveyorSource(descendant) then
			addSource(sources, seenSources, descendant)
		end
	end

	return sources
end

rebuildTrackedConveyors = function()
	disconnectSourceConnections()
	table.clear(trackedConveyorsByPart)

	for _, source in ipairs(getConveyorSources()) do
		trackSource(source)

		table.insert(
			sourceConnections,
			source.DescendantAdded:Connect(function(descendant: Instance)
				if descendant:IsA("BasePart") or descendant:IsA("Texture") then
					rebuildTrackedConveyors()
				end
			end)
		)

		table.insert(
			sourceConnections,
			source.DescendantRemoving:Connect(function(descendant: Instance)
				if descendant:IsA("BasePart") or descendant:IsA("Texture") then
					rebuildTrackedConveyors()
				end
			end)
		)
	end
end

local function updateConveyors(deltaTime: number)
	for part, trackedConveyor in pairs(trackedConveyorsByPart) do
		if part.Parent == nil then
			trackedConveyorsByPart[part] = nil
			continue
		end

		part.AssemblyLinearVelocity = part.CFrame.LookVector * trackedConveyor.speed

		local offsetDelta = trackedConveyor.textureSpeedV * deltaTime
		for _, texture in ipairs(trackedConveyor.textures) do
			if texture.Parent ~= nil then
				texture.OffsetStudsV += offsetDelta
			end
		end
	end
end

local ConveyorService = {}

function ConveyorService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	rebuildTrackedConveyors()

	table.insert(
		tagConnections,
		CollectionService:GetInstanceAddedSignal(ConveyorConfig.tagName):Connect(rebuildTrackedConveyors)
	)
	table.insert(
		tagConnections,
		CollectionService:GetInstanceRemovedSignal(ConveyorConfig.tagName):Connect(rebuildTrackedConveyors)
	)
	table.insert(
		tagConnections,
		Workspace.DescendantAdded:Connect(function(descendant: Instance)
			if isConveyorSource(descendant) then
				rebuildTrackedConveyors()
			end
		end)
	)
	table.insert(
		tagConnections,
		Workspace.DescendantRemoving:Connect(function(descendant: Instance)
			if isConveyorSource(descendant) then
				rebuildTrackedConveyors()
			end
		end)
	)

	heartbeatConnection = RunService.Heartbeat:Connect(updateConveyors)
end

function ConveyorService.stop()
	if not hasStarted then
		return
	end

	hasStarted = false
	disconnectSourceConnections()
	for _, connection in ipairs(tagConnections) do
		connection:Disconnect()
	end

	table.clear(tagConnections)
	table.clear(trackedConveyorsByPart)

	if heartbeatConnection ~= nil then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end

return table.freeze(ConveyorService)

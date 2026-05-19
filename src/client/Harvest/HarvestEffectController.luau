--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before starting HarvestEffectController")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder

local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)

type AppleHarvestEffectPayload = {
	buildingPart: BasePart,
	sourcePosition: Vector3,
	appleModelName: string,
	appleCount: number,
}

type AnimatedPart = {
	part: BasePart,
	transparency: number,
}

local APPLES_FOLDER_NAME = "Apples"
local FALLBACK_APPLE_MODEL_NAME = "Apple"
local EFFECTS_FOLDER_NAME = "HarvestEffects"
local CURRENT_VISUAL_MODEL_NAME = "CurrentVisual"
local LEAVES_PART_NAME = "Leaves"
local POP_DURATION_SECONDS = 0.28
local HANG_DURATION_SECONDS = 0.1
local HOMING_DURATION_SECONDS = 0.42
local SPAWN_STAGGER_SECONDS = 0.04
local LEAVES_RUSTLE_START_DELAY_SECONDS = 0.06
local LEAVES_RUSTLE_DURATION_SECONDS = 0.58
local LEAVES_RUSTLE_ANGLE_RADIANS = math.rad(12)
local LEAVES_RUSTLE_OFFSET_STUDS = 0.18
local LEAVES_RUSTLE_FREQUENCY = 24
local MAX_APPLES_PER_PAYLOAD = 3
local MAX_PAYLOADS_PER_EVENT = 12
local BASE_APPLE_SCALE = 1.6
local MIN_SCALE = 0.06
local SHRINK_START_ALPHA = 0.74

local random = Random.new()
local hasStarted = false
local effectsFolder: Folder? = nil
local warnedMissingAppleAssets = false
local rustleConnectionsByPart: { [BasePart]: RBXScriptConnection } = {}

local HarvestEffectController = {}

local function getHarvestEffectRemote(): RemoteEvent
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local harvestFolder = rootFolder:WaitForChild(RemoteNames.harvestFolderName) :: Folder
	return harvestFolder:WaitForChild(RemoteNames.harvestEffectEventName) :: RemoteEvent
end

local function getEffectsFolder(): Folder
	local existingFolder = effectsFolder
	if existingFolder ~= nil and existingFolder.Parent ~= nil then
		return existingFolder
	end

	local folder = Instance.new("Folder")
	folder.Name = EFFECTS_FOLDER_NAME
	folder.Parent = Workspace
	effectsFolder = folder
	return folder
end

local function getHumanoidRootPart(): BasePart?
	local character = localPlayer.Character
	if character == nil then
		return nil
	end

	local candidate = character:FindFirstChild("HumanoidRootPart")
	if candidate == nil or not candidate:IsA("BasePart") then
		return nil
	end

	return candidate
end

local function getAppleSourceModel(appleModelName: string): Model?
	local applesFolder = ReplicatedStorage:FindFirstChild(APPLES_FOLDER_NAME)
	if applesFolder == nil or not applesFolder:IsA("Folder") then
		if not warnedMissingAppleAssets then
			warn(string.format("[HarvestEffectController] Missing ReplicatedStorage.%s", APPLES_FOLDER_NAME))
			warnedMissingAppleAssets = true
		end
		return nil
	end

	local model = applesFolder:FindFirstChild(appleModelName)
	if model ~= nil and model:IsA("Model") then
		return model
	end

	local fallbackModel = applesFolder:FindFirstChild(FALLBACK_APPLE_MODEL_NAME)
	if fallbackModel ~= nil and fallbackModel:IsA("Model") then
		return fallbackModel
	end

	if not warnedMissingAppleAssets then
		warn(string.format("[HarvestEffectController] Missing %s.%s fallback apple model", APPLES_FOLDER_NAME, FALLBACK_APPLE_MODEL_NAME))
		warnedMissingAppleAssets = true
	end

	return nil
end

local function prepareEffectModel(model: Model): { AnimatedPart }
	local animatedParts: { AnimatedPart } = {}

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			table.insert(animatedParts, {
				part = descendant,
				transparency = descendant.Transparency,
			})
		end
	end

	return animatedParts
end

local function setModelFade(animatedParts: { AnimatedPart }, fadeAlpha: number)
	local clampedFadeAlpha = math.clamp(fadeAlpha, 0, 1)
	for _, animatedPart in ipairs(animatedParts) do
		animatedPart.part.Transparency = animatedPart.transparency + (1 - animatedPart.transparency) * clampedFadeAlpha
	end
end

local function easeOutCubic(alpha: number): number
	local inverse = 1 - math.clamp(alpha, 0, 1)
	return 1 - inverse * inverse * inverse
end

local function easeInCubic(alpha: number): number
	local clampedAlpha = math.clamp(alpha, 0, 1)
	return clampedAlpha * clampedAlpha * clampedAlpha
end

local function quadraticBezier(startPosition: Vector3, controlPosition: Vector3, endPosition: Vector3, alpha: number): Vector3
	local inverse = 1 - alpha
	return startPosition * inverse * inverse
		+ controlPosition * 2 * inverse * alpha
		+ endPosition * alpha * alpha
end

local function getAbsorbTargetPosition(): Vector3?
	local rootPart = getHumanoidRootPart()
	if rootPart == nil then
		return nil
	end

	return rootPart.Position + Vector3.new(0, 1.4, 0)
end

local function findLeavesPart(buildingPart: BasePart): BasePart?
	local currentVisual = buildingPart:FindFirstChild(CURRENT_VISUAL_MODEL_NAME)
	if currentVisual == nil then
		return nil
	end

	local leavesPart = currentVisual:FindFirstChild(LEAVES_PART_NAME, true)
	if leavesPart == nil or not leavesPart:IsA("BasePart") then
		return nil
	end

	return leavesPart
end

local function playLeavesRustle(buildingPart: BasePart)
	task.delay(LEAVES_RUSTLE_START_DELAY_SECONDS, function()
		local leavesPart = findLeavesPart(buildingPart)
		if leavesPart == nil then
			return
		end

		local existingConnection = rustleConnectionsByPart[leavesPart]
		if existingConnection ~= nil then
			existingConnection:Disconnect()
			rustleConnectionsByPart[leavesPart] = nil
		end

		local baseCFrame = leavesPart.CFrame
		local startedAt = os.clock()
		local connection: RBXScriptConnection? = nil

		connection = RunService.Heartbeat:Connect(function()
			if leavesPart.Parent == nil then
				if connection ~= nil then
					connection:Disconnect()
				end
				rustleConnectionsByPart[leavesPart] = nil
				return
			end

			local elapsed = os.clock() - startedAt
			local alpha = math.clamp(elapsed / LEAVES_RUSTLE_DURATION_SECONDS, 0, 1)
			if alpha >= 1 then
				leavesPart.CFrame = baseCFrame
				if connection ~= nil then
					connection:Disconnect()
				end
				rustleConnectionsByPart[leavesPart] = nil
				return
			end

			local strength = (1 - alpha) ^ 1.35
			local sway = math.sin(elapsed * LEAVES_RUSTLE_FREQUENCY) * LEAVES_RUSTLE_ANGLE_RADIANS * strength
			local twist = math.sin(elapsed * LEAVES_RUSTLE_FREQUENCY * 0.73) * LEAVES_RUSTLE_ANGLE_RADIANS * 0.45 * strength
			local offset = math.sin(elapsed * LEAVES_RUSTLE_FREQUENCY * 0.82) * LEAVES_RUSTLE_OFFSET_STUDS * strength
			leavesPart.CFrame = baseCFrame
				* CFrame.new(offset, math.abs(offset) * 0.35, 0)
				* CFrame.Angles(sway, twist, -sway * 0.35)
		end)

		if connection ~= nil then
			rustleConnectionsByPart[leavesPart] = connection
		end
	end)
end

local function animateApple(sourceModel: Model, sourcePosition: Vector3, appleIndex: number, appleCount: number)
	local model = sourceModel:Clone()
	model.Name = "HarvestAppleEffect"
	local animatedParts = prepareEffectModel(model)
	if #animatedParts == 0 then
		model:Destroy()
		return
	end

	local angle = random:NextNumber(0, math.pi * 2)
	local ringOffset = ((appleIndex - 1) - ((appleCount - 1) * 0.5)) * 0.45
	local sidewaysDirection = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local startPosition = sourcePosition + Vector3.new(0, random:NextNumber(-0.15, 0.2), 0) + sidewaysDirection * ringOffset
	local popPosition = startPosition
		+ sidewaysDirection * random:NextNumber(1.5, 3.2)
		+ Vector3.new(0, random:NextNumber(2.6, 4.0), 0)
	local popSpin = CFrame.Angles(
		random:NextNumber(-math.pi, math.pi),
		random:NextNumber(-math.pi, math.pi),
		random:NextNumber(-math.pi, math.pi)
	)
	local spinVelocity = Vector3.new(
		random:NextNumber(5, 8),
		random:NextNumber(7, 11),
		random:NextNumber(4, 7)
	)

	model.Parent = getEffectsFolder()
	model:PivotTo(CFrame.new(startPosition))

	local startedAt = os.clock()
	local popEndsAt = startedAt + POP_DURATION_SECONDS
	local hangEndsAt = popEndsAt + HANG_DURATION_SECONDS
	local homingStartPosition = popPosition
	local homingControlOffset = Vector3.new(0, random:NextNumber(1.2, 2.0), 0)

	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local targetPosition = getAbsorbTargetPosition()
		if targetPosition == nil then
			if connection ~= nil then
				connection:Disconnect()
			end
			model:Destroy()
			return
		end

		local position: Vector3
		local scale = 1
		local fadeAlpha = 0

		if now < popEndsAt then
			local alpha = easeOutCubic((now - startedAt) / POP_DURATION_SECONDS)
			position = startPosition:Lerp(popPosition, alpha)
		elseif now < hangEndsAt then
			position = popPosition
		else
			local alpha = math.clamp((now - hangEndsAt) / HOMING_DURATION_SECONDS, 0, 1)
			local easedAlpha = easeInCubic(alpha)
			position = quadraticBezier(
				homingStartPosition,
				homingStartPosition + homingControlOffset,
				targetPosition,
				easedAlpha
			)

			if alpha > SHRINK_START_ALPHA then
				local shrinkAlpha = (alpha - SHRINK_START_ALPHA) / (1 - SHRINK_START_ALPHA)
				scale = math.max(MIN_SCALE, 1 - shrinkAlpha * (1 - MIN_SCALE))
				fadeAlpha = shrinkAlpha
			end

			if alpha >= 1 then
				if connection ~= nil then
					connection:Disconnect()
				end
				model:Destroy()
				return
			end
		end

		local elapsed = now - startedAt
		model:ScaleTo(BASE_APPLE_SCALE * scale)
		model:PivotTo(CFrame.new(position) * popSpin * CFrame.Angles(
			spinVelocity.X * elapsed,
			spinVelocity.Y * elapsed,
			spinVelocity.Z * elapsed
		))
		setModelFade(animatedParts, fadeAlpha)
	end)
end

local function playPayload(payload: AppleHarvestEffectPayload)
	if typeof(payload.sourcePosition) ~= "Vector3"
		or type(payload.appleModelName) ~= "string"
		or type(payload.appleCount) ~= "number"
	then
		return
	end

	if typeof(payload.buildingPart) == "Instance" and payload.buildingPart:IsA("BasePart") then
		playLeavesRustle(payload.buildingPart)
	end

	local sourceModel = getAppleSourceModel(payload.appleModelName)
	if sourceModel == nil then
		return
	end

	local appleCount = math.clamp(math.floor(payload.appleCount), 1, MAX_APPLES_PER_PAYLOAD)
	for appleIndex = 1, appleCount do
		task.delay((appleIndex - 1) * SPAWN_STAGGER_SECONDS, function()
			animateApple(sourceModel, payload.sourcePosition, appleIndex, appleCount)
		end)
	end
end

local function playPayloads(rawPayloads: unknown)
	if type(rawPayloads) ~= "table" then
		return
	end

	local payloads = rawPayloads :: { unknown }
	for index, payload in ipairs(payloads) do
		if index > MAX_PAYLOADS_PER_EVENT then
			break
		end

		if type(payload) == "table" then
			playPayload(payload :: AppleHarvestEffectPayload)
		end
	end
end

function HarvestEffectController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	getHarvestEffectRemote().OnClientEvent:Connect(playPayloads)
end

return table.freeze(HarvestEffectController)

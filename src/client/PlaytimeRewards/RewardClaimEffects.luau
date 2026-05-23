--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local AudioService = require(script.Parent.Parent.Audio.AudioService)

export type RewardClaimEffects = {
	play: (rootGui: ScreenGui) -> (),
}

local CLAIM_SOUND_NAME = "RewardClaimSound"
local CLAIM_SOUND_ID = "rbxassetid://99550892352190"
local CLAIM_SOUND_VOLUME = 1

local SHAKE_BIND_NAME = "RewardClaimCameraShake"
local SHAKE_DURATION_SECONDS = 0.5
local SHAKE_STRENGTH = 0.75
local SHAKE_FREQUENCY = 42

local CONFETTI_OVERLAY_NAME = "RewardClaimConfettiOverlay"
local CONFETTI_PIECE_COUNT = 56
local CONFETTI_MIN_WIDTH_PIXELS = 7
local CONFETTI_MAX_WIDTH_PIXELS = 14
local CONFETTI_MIN_HEIGHT_PIXELS = 11
local CONFETTI_MAX_HEIGHT_PIXELS = 24
local CONFETTI_MIN_DURATION_SECONDS = 1.1
local CONFETTI_MAX_DURATION_SECONDS = 1.9
local CONFETTI_MAX_DRIFT_PIXELS = 180
local CONFETTI_Z_INDEX = 1000

local CONFETTI_COLORS: { Color3 } = {
	Color3.fromRGB(255, 69, 97),
	Color3.fromRGB(255, 196, 61),
	Color3.fromRGB(79, 220, 113),
	Color3.fromRGB(68, 178, 255),
	Color3.fromRGB(174, 102, 255),
	Color3.fromRGB(255, 126, 58),
	Color3.fromRGB(255, 255, 255),
}

local random = Random.new()
local activeShakeHumanoid: Humanoid? = nil
local activeShakeBaseOffset = Vector3.zero
local activeShakeToken = 0

local function getOrCreateClaimSound(): Sound
	local existing = SoundService:FindFirstChild(CLAIM_SOUND_NAME)
	if existing ~= nil then
		assert(existing:IsA("Sound"), string.format("SoundService.%s must be a Sound", CLAIM_SOUND_NAME))
		existing.SoundId = CLAIM_SOUND_ID
		existing.Volume = CLAIM_SOUND_VOLUME
		existing.PlaybackSpeed = 1
		existing.Looped = false
		AudioService.assignSoundToBus(existing, "SFX")
		return existing
	end

	local sound = Instance.new("Sound")
	sound.Name = CLAIM_SOUND_NAME
	sound.SoundId = CLAIM_SOUND_ID
	sound.Volume = CLAIM_SOUND_VOLUME
	sound.PlaybackSpeed = 1
	sound.Looped = false
	AudioService.assignSoundToBus(sound, "SFX")
	sound.Parent = SoundService
	return sound
end

local function playClaimSound()
	AudioService.start()

	local sound = getOrCreateClaimSound()
	sound:Stop()
	sound.TimePosition = 0
	sound:Play()
end

local function getLocalHumanoid(): Humanoid?
	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		return nil
	end

	local character = localPlayer.Character
	if character == nil then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return nil
	end

	return humanoid
end

local function stopActiveShake()
	RunService:UnbindFromRenderStep(SHAKE_BIND_NAME)

	if activeShakeHumanoid ~= nil then
		activeShakeHumanoid.CameraOffset = activeShakeBaseOffset
		activeShakeHumanoid = nil
	end
end

local function playCameraShake()
	stopActiveShake()

	local humanoid = getLocalHumanoid()
	if humanoid == nil then
		return
	end

	activeShakeToken += 1
	local shakeToken = activeShakeToken
	local startedAt = os.clock()
	activeShakeHumanoid = humanoid
	activeShakeBaseOffset = humanoid.CameraOffset

	RunService:BindToRenderStep(SHAKE_BIND_NAME, Enum.RenderPriority.Camera.Value - 1, function()
		if activeShakeToken ~= shakeToken or activeShakeHumanoid ~= humanoid then
			return
		end

		local elapsed = os.clock() - startedAt
		local alpha = math.clamp(elapsed / SHAKE_DURATION_SECONDS, 0, 1)
		if alpha >= 1 then
			stopActiveShake()
			return
		end

		local falloff = (1 - alpha) * (1 - alpha)
		local strength = SHAKE_STRENGTH * falloff
		local jitterX = random:NextNumber(-strength, strength)
		local jitterY = random:NextNumber(-strength, strength)
		local wave = math.sin(elapsed * SHAKE_FREQUENCY) * strength * 0.35
		humanoid.CameraOffset = activeShakeBaseOffset + Vector3.new(jitterX + wave, jitterY, 0)
	end)
end

local function getConfettiSize(): UDim2
	local width = random:NextInteger(CONFETTI_MIN_WIDTH_PIXELS, CONFETTI_MAX_WIDTH_PIXELS)
	local height = random:NextInteger(CONFETTI_MIN_HEIGHT_PIXELS, CONFETTI_MAX_HEIGHT_PIXELS)
	return UDim2.fromOffset(width, height)
end

local function createConfettiPiece(overlay: Frame): Frame
	local piece = Instance.new("Frame")
	piece.Name = "Confetti"
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.BackgroundColor3 = CONFETTI_COLORS[random:NextInteger(1, #CONFETTI_COLORS)]
	piece.BackgroundTransparency = 0
	piece.BorderSizePixel = 0
	piece.Position = UDim2.new(random:NextNumber(0, 1), 0, 0, random:NextInteger(-120, -12))
	piece.Rotation = random:NextNumber(-35, 35)
	piece.Size = getConfettiSize()
	piece.ZIndex = CONFETTI_Z_INDEX
	piece.Parent = overlay
	return piece
end

local function playConfetti(rootGui: ScreenGui)
	local overlay = Instance.new("Frame")
	overlay.Name = CONFETTI_OVERLAY_NAME
	overlay.Active = false
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.ClipsDescendants = false
	overlay.Position = UDim2.fromScale(0, 0)
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = CONFETTI_Z_INDEX
	overlay.Parent = rootGui

	local remainingPieces = CONFETTI_PIECE_COUNT
	local longestDuration = 0

	for _ = 1, CONFETTI_PIECE_COUNT do
		local piece = createConfettiPiece(overlay)
		local duration = random:NextNumber(CONFETTI_MIN_DURATION_SECONDS, CONFETTI_MAX_DURATION_SECONDS)
		longestDuration = math.max(longestDuration, duration)

		local drift = random:NextInteger(-CONFETTI_MAX_DRIFT_PIXELS, CONFETTI_MAX_DRIFT_PIXELS)
		local spinDirection = if random:NextNumber() > 0.5 then 1 else -1
		local targetRotation = piece.Rotation + random:NextNumber(260, 760) * spinDirection
		local targetPosition = UDim2.new(piece.Position.X.Scale, piece.Position.X.Offset + drift, 1, random:NextInteger(42, 180))
		local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

		local tween = TweenService:Create(piece, tweenInfo, {
			BackgroundTransparency = 0.25,
			Position = targetPosition,
			Rotation = targetRotation,
		})

		tween.Completed:Connect(function()
			if piece.Parent ~= nil then
				piece:Destroy()
			end

			remainingPieces -= 1
			if remainingPieces <= 0 and overlay.Parent ~= nil then
				overlay:Destroy()
			end
		end)

		tween:Play()
	end

	task.delay(longestDuration + 0.25, function()
		if overlay.Parent ~= nil then
			overlay:Destroy()
		end
	end)
end

local RewardClaimEffects = {} :: RewardClaimEffects

function RewardClaimEffects.play(rootGui: ScreenGui)
	playClaimSound()
	playCameraShake()
	playConfetti(rootGui)
end

return table.freeze(RewardClaimEffects)

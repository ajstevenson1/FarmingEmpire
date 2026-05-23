--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FrameManager = require(script.Parent.FrameManager)

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local uiFolder = sharedFolder:WaitForChild("UI") :: Folder
local MenuPresentationConfig = require(uiFolder:WaitForChild("MenuPresentationConfig") :: ModuleScript)

export type MenuPresentationController = {
	start: () -> (),
	destroy: () -> (),
}

type PresentationState = {
	blurEffect: BlurEffect?,
	baselineFieldOfView: number?,
	isMenuPresented: boolean,
	activeBlurTween: Tween?,
	activeCameraTween: Tween?,
	cameraConnection: RBXScriptConnection?,
}

local state: PresentationState = {
	blurEffect = nil,
	baselineFieldOfView = nil,
	isMenuPresented = false,
	activeBlurTween = nil,
	activeCameraTween = nil,
	cameraConnection = nil,
}

local hasStarted = false

local function getOrCreateBlurEffect(): BlurEffect
	local existing = Lighting:FindFirstChild(MenuPresentationConfig.BlurEffectName)
	if existing ~= nil then
		assert(existing:IsA("BlurEffect"), string.format("Lighting.%s must be a BlurEffect", MenuPresentationConfig.BlurEffectName))
		state.blurEffect = existing
		return existing
	end

	local created = Instance.new("BlurEffect")
	created.Name = MenuPresentationConfig.BlurEffectName
	created.Enabled = false
	created.Size = 0
	created.Parent = Lighting
	state.blurEffect = created
	return created
end

local function cancelTween(tween: Tween?)
	if tween ~= nil then
		tween:Cancel()
	end
end

local function tweenBlur(targetSize: number, shouldDisableWhenComplete: boolean)
	local blurEffect = getOrCreateBlurEffect()
	blurEffect.Enabled = true

	cancelTween(state.activeBlurTween)
	local tween = TweenService:Create(blurEffect, MenuPresentationConfig.TweenInfo, {
		Size = targetSize,
	})
	state.activeBlurTween = tween

	tween.Completed:Connect(function(playbackState: Enum.PlaybackState)
		if state.activeBlurTween ~= tween then
			return
		end

		state.activeBlurTween = nil
		if playbackState == Enum.PlaybackState.Completed and shouldDisableWhenComplete then
			blurEffect.Enabled = false
		end
	end)

	tween:Play()
end

local function getCurrentCamera(): Camera?
	return Workspace.CurrentCamera
end

local function captureBaselineFieldOfView(camera: Camera?)
	if camera == nil or state.baselineFieldOfView ~= nil then
		return
	end

	state.baselineFieldOfView = camera.FieldOfView
end

local function tweenCamera(targetFieldOfView: number)
	local camera = getCurrentCamera()
	if camera == nil then
		return
	end

	cancelTween(state.activeCameraTween)
	local tween = TweenService:Create(camera, MenuPresentationConfig.TweenInfo, {
		FieldOfView = targetFieldOfView,
	})
	state.activeCameraTween = tween

	tween.Completed:Connect(function()
		if state.activeCameraTween == tween then
			state.activeCameraTween = nil
		end
	end)

	tween:Play()
end

local function applyPresentationState(shouldPresentMenu: boolean)
	if state.isMenuPresented == shouldPresentMenu then
		return
	end

	state.isMenuPresented = shouldPresentMenu

	local camera = getCurrentCamera()
	captureBaselineFieldOfView(camera)
	local baselineFieldOfView = state.baselineFieldOfView or (if camera ~= nil then camera.FieldOfView else 70)

	if shouldPresentMenu then
		tweenBlur(MenuPresentationConfig.BlurSize, false)
		tweenCamera(baselineFieldOfView + MenuPresentationConfig.CameraZoomOutFovDelta)
		return
	end

	tweenBlur(0, true)
	tweenCamera(baselineFieldOfView)
	state.baselineFieldOfView = nil
end

local function refreshPresentationState()
	local openMenuFrameId = FrameManager.getOpenFrame(MenuPresentationConfig.MenuFrameGroup)
	applyPresentationState(openMenuFrameId ~= nil)
end

local MenuPresentationController = {} :: MenuPresentationController

function MenuPresentationController.start()
	if hasStarted then
		return
	end

	hasStarted = true
	getOrCreateBlurEffect()

	FrameManager.observeFrameOpened(function(_frameId: string)
		refreshPresentationState()
	end)

	FrameManager.observeFrameClosed(function(_frameId: string)
		refreshPresentationState()
	end)

	state.cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if not state.isMenuPresented then
			return
		end

		state.baselineFieldOfView = nil
		applyPresentationState(false)
		applyPresentationState(true)
	end)

	refreshPresentationState()
end

function MenuPresentationController.destroy()
	cancelTween(state.activeBlurTween)
	cancelTween(state.activeCameraTween)
	state.activeBlurTween = nil
	state.activeCameraTween = nil

	if state.cameraConnection ~= nil then
		state.cameraConnection:Disconnect()
		state.cameraConnection = nil
	end

	local blurEffect = state.blurEffect
	if blurEffect ~= nil then
		blurEffect.Size = 0
		blurEffect.Enabled = false
	end

	local camera = getCurrentCamera()
	local baselineFieldOfView = state.baselineFieldOfView
	if camera ~= nil and baselineFieldOfView ~= nil then
		camera.FieldOfView = baselineFieldOfView
	end

	state.baselineFieldOfView = nil
	state.isMenuPresented = false
	hasStarted = false
end

return table.freeze(MenuPresentationController)

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local loadingFolder = sharedFolder:WaitForChild("Loading") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local tutorialFolder = sharedFolder:WaitForChild("Tutorial") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder

local LoadingGate = require(loadingFolder:WaitForChild("LoadingGate") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local TutorialTypes = require(tutorialFolder:WaitForChild("TutorialTypes") :: ModuleScript)
local InventoryController = require(script.Parent.Parent.Inventory.InventoryController)
local PlaytimeRewardsController = require(script.Parent.Parent.PlaytimeRewards.PlaytimeRewardsController)
local TutorialHudView = require(script.Parent.TutorialHudView)
local TutorialSpotlightView = require(script.Parent.TutorialSpotlightView)
local TutorialBeamView = require(script.Parent.TutorialBeamView)
local TutorialClientState = require(script.Parent.TutorialClientState)
local TutorialTargetResolver = require(script.Parent.TutorialTargetResolver)

type TutorialStepPayload = TutorialTypes.TutorialStepPayload
type InventorySnapshot = InventoryTypes.InventorySnapshot
type GuiButtonLike = TextButton | ImageButton

local LOADING_GATE_TIMEOUT_SECONDS = 12

local hasStarted = false
local hudView: TutorialHudView.TutorialHudView? = nil
local spotlightView: TutorialSpotlightView.TutorialSpotlightView? = nil
local beamView: TutorialBeamView.TutorialBeamView? = nil
local shouldHideEquippedHotbarSpotlight = false
local currentSpotlightTargetName = "None"
local hasSeenIncompleteTutorial = false
local didAutoOpenDailyRewards = false
local activeOnboardingIndicator: GuiObject? = nil
local activeOnboardingIndicatorOriginalVisible = false
local activeOnboardingTargetName = "None"
local activeTargetActivatedConnection: RBXScriptConnection? = nil

local function getTutorialRemotes(): (RemoteEvent, RemoteEvent, RemoteEvent, RemoteFunction)
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName)
	assert(rootFolder:IsA("Folder"), "ReplicatedStorage.GameRemotes must be a Folder")

	local remotesFolder = rootFolder:WaitForChild(RemoteNames.tutorialFolderName)
	assert(remotesFolder:IsA("Folder"), "GameRemotes.Tutorial must be a Folder")

	local stepUpdated = remotesFolder:WaitForChild(RemoteNames.tutorialStepUpdatedEventName)
	local tapContinue = remotesFolder:WaitForChild(RemoteNames.tutorialTapContinueEventName)
	local skipRequested = remotesFolder:WaitForChild(RemoteNames.tutorialSkipRequestedEventName)
	local getSnapshot = remotesFolder:WaitForChild(RemoteNames.getTutorialSnapshotFunctionName)
	assert(stepUpdated:IsA("RemoteEvent"), "TutorialStepUpdated must be a RemoteEvent")
	assert(tapContinue:IsA("RemoteEvent"), "TutorialTapContinue must be a RemoteEvent")
	assert(skipRequested:IsA("RemoteEvent"), "TutorialSkipRequested must be a RemoteEvent")
	assert(getSnapshot:IsA("RemoteFunction"), "GetTutorialSnapshot must be a RemoteFunction")

	return stepUpdated, tapContinue, skipRequested, getSnapshot
end

local function getRootGui(): ScreenGui
	local Players = game:GetService("Players")
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before starting TutorialController")
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild("GUI")
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")
	return rootGui
end

local function getSelectedItemId(snapshot: InventorySnapshot): string?
	local selectedSlotIndex = snapshot.selectedSlotIndex
	if selectedSlotIndex == nil then
		return nil
	end

	return snapshot.hotbarSlots[selectedSlotIndex]
end

local function getEquippedItemIdForSpotlightTarget(targetName: string): string?
	if targetName == "OakTreeHotbar" then
		return "OakTree"
	elseif targetName == "CiderMillHotbar" then
		return "CiderMill"
	end

	return nil
end

local function updateEquipStepSpotlight(snapshot: InventorySnapshot?)
	local spotlight = spotlightView
	if spotlight == nil or shouldHideEquippedHotbarSpotlight then
		return
	end

	local targetItemId = getEquippedItemIdForSpotlightTarget(currentSpotlightTargetName)
	if targetItemId ~= nil and snapshot ~= nil and getSelectedItemId(snapshot) == targetItemId then
		shouldHideEquippedHotbarSpotlight = true
		spotlight:hide()
		local indicator = activeOnboardingIndicator
		if indicator ~= nil and indicator.Parent ~= nil then
			indicator.Visible = activeOnboardingIndicatorOriginalVisible
		end
		activeOnboardingIndicator = nil
		activeOnboardingTargetName = "None"
	end
end

local function clearOnboardingIndicator()
	local indicator = activeOnboardingIndicator
	if indicator ~= nil and indicator.Parent ~= nil then
		indicator.Visible = activeOnboardingIndicatorOriginalVisible
	end

	activeOnboardingIndicator = nil
	activeOnboardingTargetName = "None"
end

local function disconnectActiveTargetActivated()
	local connection = activeTargetActivatedConnection
	if connection ~= nil then
		connection:Disconnect()
	end

	activeTargetActivatedConnection = nil
end

local function hideCurrentTargetGuidance()
	disconnectActiveTargetActivated()

	local spotlight = spotlightView
	if spotlight ~= nil then
		spotlight:hide()
	end

	clearOnboardingIndicator()
end

local function getActivatedButton(target: GuiObject): GuiButtonLike?
	if target:IsA("TextButton") then
		return target :: TextButton
	elseif target:IsA("ImageButton") then
		return target :: ImageButton
	end

	return nil
end

local function connectTargetActivated(targetName: string)
	disconnectActiveTargetActivated()

	if targetName == "None" then
		return
	end

	local target = TutorialTargetResolver.getGuiTarget(targetName)
	if target == nil then
		return
	end

	local button = getActivatedButton(target)
	if button == nil then
		return
	end

	activeTargetActivatedConnection = button.Activated:Connect(hideCurrentTargetGuidance)
end

local function findOnboardingIndicator(target: GuiObject): GuiObject?
	local directChild = target:FindFirstChild("Onboarding")
	if directChild ~= nil and directChild:IsA("GuiObject") then
		return directChild
	end

	for _, descendant in ipairs(target:GetDescendants()) do
		if descendant.Name == "Onboarding" and descendant:IsA("GuiObject") then
			return descendant
		end
	end

	return nil
end

local function updateOnboardingIndicator(targetName: string)
	if targetName == "None" then
		clearOnboardingIndicator()
		return
	end

	local target = TutorialTargetResolver.getGuiTarget(targetName)
	if target == nil or not TutorialTargetResolver.isGuiObjectEffectivelyVisible(target) then
		clearOnboardingIndicator()
		return
	end

	local indicator = findOnboardingIndicator(target)
	if indicator == nil then
		clearOnboardingIndicator()
		return
	end

	if indicator == activeOnboardingIndicator then
		indicator.Visible = true
		return
	end

	local previousIndicator = activeOnboardingIndicator
	if previousIndicator ~= nil and previousIndicator.Parent ~= nil then
		previousIndicator.Visible = activeOnboardingIndicatorOriginalVisible
	end

	activeOnboardingIndicator = indicator
	activeOnboardingIndicatorOriginalVisible = indicator.Visible
	indicator.Visible = true
end

local function showOnboardingIndicatorForTarget(targetName: string)
	if activeOnboardingTargetName ~= targetName then
		clearOnboardingIndicator()
	end

	activeOnboardingTargetName = targetName
	updateOnboardingIndicator(targetName)
end

local function applyPayload(payload: TutorialStepPayload)
	local hud = hudView
	local spotlight = spotlightView
	local beam = beamView
	assert(hud ~= nil and spotlight ~= nil and beam ~= nil, "Tutorial views must exist before applying payload")

	local step = payload.step
	TutorialClientState.setCurrentStep(if step ~= nil then step.id else nil, payload.data.completed)
	if payload.data.completed or step == nil then
		clearOnboardingIndicator()
		if hasSeenIncompleteTutorial and not didAutoOpenDailyRewards then
			didAutoOpenDailyRewards = true
			PlaytimeRewardsController.open("Daily")
		end

		shouldHideEquippedHotbarSpotlight = false
		currentSpotlightTargetName = "None"
		disconnectActiveTargetActivated()
		hud:hide()
		spotlight:hide()
		beam:hide()
		return
	end

	hasSeenIncompleteTutorial = true
	hud:showStep(step)
	shouldHideEquippedHotbarSpotlight = false
	currentSpotlightTargetName = step.spotlightTarget
	connectTargetActivated(step.spotlightTarget)
	showOnboardingIndicatorForTarget(step.spotlightTarget)

	if step.spotlightTarget == "None" then
		spotlight:hide()
	else
		spotlight:show(step.spotlightTarget)
	end

	if step.beamTarget == "None" then
		beam:hide()
	else
		beam:show(step.beamTarget)
	end

	updateEquipStepSpotlight(InventoryController.getLatestSnapshot())
end

local function waitForLoadingScreenCleared()
	if not LoadingGate.waitUntilCleared(LOADING_GATE_TIMEOUT_SECONDS) then
		warn("TutorialController loading gate timed out; starting tutorial anyway.")
	end
end

local function startTutorialAfterLoadingCleared()
	waitForLoadingScreenCleared()

	local stepUpdated, tapContinue, skipRequested, getSnapshot = getTutorialRemotes()
	hudView = TutorialHudView.new()
	spotlightView = TutorialSpotlightView.new(getRootGui())
	beamView = TutorialBeamView.new()

	hudView:connectContinueRequested(function()
		tapContinue:FireServer()
	end)
	hudView:connectSkipRequested(function()
		skipRequested:FireServer()
	end)

	stepUpdated.OnClientEvent:Connect(function(payload: TutorialStepPayload)
		applyPayload(payload)
	end)
	InventoryController.observeSnapshotChanged(updateEquipStepSpotlight)
	RunService.RenderStepped:Connect(function()
		if activeOnboardingTargetName ~= "None" then
			updateOnboardingIndicator(activeOnboardingTargetName)
		end
	end)

	applyPayload(getSnapshot:InvokeServer() :: TutorialStepPayload)
end

local TutorialController = {}

function TutorialController.start()
	if hasStarted then
		return
	end

	hasStarted = true
	task.spawn(startTutorialAfterLoadingCleared)
end

return table.freeze(TutorialController)

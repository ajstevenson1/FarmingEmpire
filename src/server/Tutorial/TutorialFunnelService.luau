--!strict

local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local tutorialFolder = sharedFolder:WaitForChild("Tutorial") :: Folder

local TutorialConfig = require(tutorialFolder:WaitForChild("TutorialConfig") :: ModuleScript)
local TutorialFunnelTypes = require(tutorialFolder:WaitForChild("TutorialFunnelTypes") :: ModuleScript)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)

type TutorialCompletionSource = TutorialFunnelTypes.TutorialCompletionSource
type PlayerTutorialFunnelData = PlayerDataService.PlayerTutorialFunnelData
type PlayerTutorialFunnelStepData = PlayerDataService.PlayerTutorialFunnelStepData

local FUNNEL_VERSION = 1

local TutorialFunnelService = {}

local function getUnixTime(): number
	return os.time()
end

local function findStepData(funnelData: PlayerTutorialFunnelData, stepId: number): PlayerTutorialFunnelStepData?
	for _, stepData in ipairs(funnelData.steps) do
		if stepData.stepId == stepId then
			return stepData
		end
	end

	return nil
end

local function sortSteps(funnelData: PlayerTutorialFunnelData)
	table.sort(funnelData.steps, function(leftStep, rightStep)
		return leftStep.stepId < rightStep.stepId
	end)
end

local function ensureStarted(funnelData: PlayerTutorialFunnelData, timestampUnix: number): boolean
	local didChange = false
	if funnelData.version ~= FUNNEL_VERSION then
		funnelData.version = FUNNEL_VERSION
		didChange = true
	end

	if funnelData.startedAtUnix <= 0 then
		funnelData.startedAtUnix = timestampUnix
		didChange = true
	end

	return didChange
end

local function ensureStepReached(funnelData: PlayerTutorialFunnelData, stepId: number, timestampUnix: number): boolean
	if findStepData(funnelData, stepId) ~= nil then
		return false
	end

	table.insert(funnelData.steps, {
		stepId = stepId,
		reachedAtUnix = timestampUnix,
		completedAtUnix = nil,
		completionSource = nil,
	})
	sortSteps(funnelData)
	return true
end

local function saveIfChanged(player: Player, funnelData: PlayerTutorialFunnelData, didChange: boolean)
	if didChange then
		PlayerDataService.setTutorialFunnelData(player, funnelData)
	end
end

local function logOnboardingStep(player: Player, stepId: number)
	local stepDefinition = TutorialConfig.getStep(stepId)
	if stepDefinition == nil then
		warn(string.format("Cannot log tutorial funnel step %d because it is not configured.", stepId))
		return
	end

	local success, result = pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, stepId, stepDefinition.analyticsName)
	end)
	if not success then
		warn(string.format("Failed to log onboarding funnel step %d for %s: %s", stepId, player.Name, tostring(result)))
	end
end

function TutorialFunnelService.reachStep(player: Player, stepId: number)
	local timestampUnix = getUnixTime()
	local funnelData = PlayerDataService.getTutorialFunnelData(player)
	local didChange = ensureStarted(funnelData, timestampUnix)
	local didReachStep = ensureStepReached(funnelData, stepId, timestampUnix)
	didChange = didReachStep or didChange
	if didReachStep and stepId == 1 then
		logOnboardingStep(player, stepId)
	end
	saveIfChanged(player, funnelData, didChange)
end

function TutorialFunnelService.completeStep(player: Player, stepId: number, completionSource: TutorialCompletionSource)
	local timestampUnix = getUnixTime()
	local funnelData = PlayerDataService.getTutorialFunnelData(player)
	local didChange = ensureStarted(funnelData, timestampUnix)
	didChange = ensureStepReached(funnelData, stepId, timestampUnix) or didChange

	local stepData = findStepData(funnelData, stepId)
	if stepData ~= nil and stepData.completedAtUnix == nil then
		stepData.completedAtUnix = timestampUnix
		stepData.completionSource = completionSource
		didChange = true
		if stepId ~= 1 then
			logOnboardingStep(player, stepId)
		end
	end

	saveIfChanged(player, funnelData, didChange)
end

function TutorialFunnelService.completeTutorial(player: Player, finalStepId: number, completionSource: TutorialCompletionSource)
	local timestampUnix = getUnixTime()
	local funnelData = PlayerDataService.getTutorialFunnelData(player)
	local didChange = ensureStarted(funnelData, timestampUnix)
	didChange = ensureStepReached(funnelData, finalStepId, timestampUnix) or didChange

	local finalStepData = findStepData(funnelData, finalStepId)
	if finalStepData ~= nil and finalStepData.completedAtUnix == nil then
		finalStepData.completedAtUnix = timestampUnix
		finalStepData.completionSource = completionSource
		didChange = true
		logOnboardingStep(player, finalStepId)
	end

	if funnelData.completedAtUnix == nil then
		funnelData.completedAtUnix = timestampUnix
		didChange = true
	end

	saveIfChanged(player, funnelData, didChange)
end

function TutorialFunnelService.skipTutorial(player: Player, stepId: number)
	local timestampUnix = getUnixTime()
	local funnelData = PlayerDataService.getTutorialFunnelData(player)
	local didChange = ensureStarted(funnelData, timestampUnix)
	didChange = ensureStepReached(funnelData, stepId, timestampUnix) or didChange

	if funnelData.skippedAtUnix == nil then
		funnelData.skippedAtUnix = timestampUnix
		funnelData.skippedAtStepId = stepId
		didChange = true
	end

	saveIfChanged(player, funnelData, didChange)
end

return table.freeze(TutorialFunnelService)

--!strict

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local tutorialFolder = sharedFolder:WaitForChild("Tutorial") :: Folder

local TutorialConfig = require(tutorialFolder:WaitForChild("TutorialConfig") :: ModuleScript)
local TutorialFunnelTypes = require(tutorialFolder:WaitForChild("TutorialFunnelTypes") :: ModuleScript)
local TutorialTypes = require(tutorialFolder:WaitForChild("TutorialTypes") :: ModuleScript)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)

type TutorialCompletionSource = TutorialFunnelTypes.TutorialCompletionSource
type TutorialVariant = TutorialTypes.TutorialVariant
type PlayerTutorialFunnelData = PlayerDataService.PlayerTutorialFunnelData
type PlayerTutorialFunnelStepData = PlayerDataService.PlayerTutorialFunnelStepData
type AnalyticsCustomFields = { [string]: string | number | boolean }

local FUNNEL_VERSION = TutorialConfig.getFunnelVersion()

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

local function resetFunnelData(funnelData: PlayerTutorialFunnelData, variant: TutorialVariant, timestampUnix: number)
	funnelData.version = FUNNEL_VERSION
	funnelData.tutorialVariant = variant
	funnelData.funnelSessionId = HttpService:GenerateGUID(false)
	funnelData.startedAtUnix = timestampUnix
	funnelData.completedAtUnix = nil
	funnelData.skippedAtUnix = nil
	funnelData.skippedAtStepId = nil
	table.clear(funnelData.steps)
end

local function ensureStarted(
	funnelData: PlayerTutorialFunnelData,
	variant: TutorialVariant,
	timestampUnix: number
): boolean
	local didChange = false
	if funnelData.version ~= FUNNEL_VERSION or funnelData.tutorialVariant ~= variant then
		resetFunnelData(funnelData, variant, timestampUnix)
		return true
	end

	if funnelData.funnelSessionId == nil then
		funnelData.funnelSessionId = HttpService:GenerateGUID(false)
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

local function getTutorialVariant(player: Player): TutorialVariant
	return PlayerDataService.ensureTutorialVariant(player)
end

local function buildCustomFields(
	variant: TutorialVariant,
	completionSource: TutorialCompletionSource?
): AnalyticsCustomFields
	local customFields: AnalyticsCustomFields = {
		tutorialVariant = variant,
		tutorialFunnelVersion = FUNNEL_VERSION,
	}

	if completionSource ~= nil then
		customFields.completionSource = completionSource
	end

	return customFields
end

local function logAnalyticsStep(
	player: Player,
	funnelData: PlayerTutorialFunnelData,
	analyticsStepId: number,
	analyticsName: string,
	completionSource: TutorialCompletionSource?
)
	local variant = funnelData.tutorialVariant or getTutorialVariant(player)
	local funnelSessionId = funnelData.funnelSessionId
	if funnelSessionId == nil then
		warn(
			string.format(
				"Cannot log tutorial funnel step %d because the funnel session id is missing.",
				analyticsStepId
			)
		)
		return
	end

	local customFields = buildCustomFields(variant, completionSource)
	local funnelName = TutorialConfig.getFunnelName(variant)
	local success, result = pcall(function()
		AnalyticsService:LogFunnelStepEvent(
			player,
			funnelName,
			funnelSessionId,
			analyticsStepId,
			analyticsName,
			customFields
		)
	end)
	if not success then
		warn(
			string.format(
				"Failed to log named tutorial funnel step %d for %s: %s",
				analyticsStepId,
				player.Name,
				tostring(result)
			)
		)
	end

	local onboardingSuccess, onboardingResult = pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, analyticsStepId, analyticsName, customFields)
	end)
	if not onboardingSuccess then
		warn(
			string.format(
				"Failed to log onboarding funnel step %d for %s: %s",
				analyticsStepId,
				player.Name,
				tostring(onboardingResult)
			)
		)
	end
end

local function logTutorialStart(player: Player, funnelData: PlayerTutorialFunnelData)
	logAnalyticsStep(
		player,
		funnelData,
		TutorialConfig.getStartAnalyticsStepId(),
		TutorialConfig.getStartAnalyticsName(),
		nil
	)
end

local function logTutorialStepCompletion(
	player: Player,
	funnelData: PlayerTutorialFunnelData,
	stepId: number,
	completionSource: TutorialCompletionSource
)
	local variant = funnelData.tutorialVariant or getTutorialVariant(player)
	if not TutorialConfig.shouldLogStepCompletion(variant, stepId) then
		return
	end

	local stepDefinition = TutorialConfig.getStep(variant, stepId)
	if stepDefinition == nil then
		warn(string.format("Cannot log tutorial funnel step %d because it is not configured.", stepId))
		return
	end

	logAnalyticsStep(
		player,
		funnelData,
		stepDefinition.analyticsStepId or stepDefinition.id,
		stepDefinition.analyticsName,
		completionSource
	)
end

function TutorialFunnelService.reachStep(player: Player, stepId: number)
	local timestampUnix = getUnixTime()
	local variant = getTutorialVariant(player)
	local funnelData = PlayerDataService.getTutorialFunnelData(player)
	local didChange = ensureStarted(funnelData, variant, timestampUnix)
	local didReachStep = ensureStepReached(funnelData, stepId, timestampUnix)
	didChange = didReachStep or didChange
	if didReachStep and stepId == 1 then
		logTutorialStart(player, funnelData)
	end
	saveIfChanged(player, funnelData, didChange)
end

function TutorialFunnelService.completeStep(player: Player, stepId: number, completionSource: TutorialCompletionSource)
	local timestampUnix = getUnixTime()
	local variant = getTutorialVariant(player)
	local funnelData = PlayerDataService.getTutorialFunnelData(player)
	local didChange = ensureStarted(funnelData, variant, timestampUnix)
	didChange = ensureStepReached(funnelData, stepId, timestampUnix) or didChange

	local stepData = findStepData(funnelData, stepId)
	if stepData ~= nil and stepData.completedAtUnix == nil then
		stepData.completedAtUnix = timestampUnix
		stepData.completionSource = completionSource
		didChange = true
		logTutorialStepCompletion(player, funnelData, stepId, completionSource)
	end

	saveIfChanged(player, funnelData, didChange)
end

function TutorialFunnelService.completeTutorial(player: Player, finalStepId: number, completionSource: TutorialCompletionSource)
	local timestampUnix = getUnixTime()
	local variant = getTutorialVariant(player)
	local funnelData = PlayerDataService.getTutorialFunnelData(player)
	local didChange = ensureStarted(funnelData, variant, timestampUnix)
	didChange = ensureStepReached(funnelData, finalStepId, timestampUnix) or didChange

	local finalStepData = findStepData(funnelData, finalStepId)
	if finalStepData ~= nil and finalStepData.completedAtUnix == nil then
		finalStepData.completedAtUnix = timestampUnix
		finalStepData.completionSource = completionSource
		didChange = true
		logTutorialStepCompletion(player, funnelData, finalStepId, completionSource)
	end

	if funnelData.completedAtUnix == nil then
		funnelData.completedAtUnix = timestampUnix
		didChange = true
	end

	saveIfChanged(player, funnelData, didChange)
end

function TutorialFunnelService.skipTutorial(player: Player, stepId: number)
	local timestampUnix = getUnixTime()
	local variant = getTutorialVariant(player)
	local funnelData = PlayerDataService.getTutorialFunnelData(player)
	local didChange = ensureStarted(funnelData, variant, timestampUnix)
	didChange = ensureStepReached(funnelData, stepId, timestampUnix) or didChange

	if funnelData.skippedAtUnix == nil then
		funnelData.skippedAtUnix = timestampUnix
		funnelData.skippedAtStepId = stepId
		didChange = true
	end

	saveIfChanged(player, funnelData, didChange)
end

return table.freeze(TutorialFunnelService)

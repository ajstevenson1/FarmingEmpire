--!strict

local TutorialTypes = require(script.Parent.TutorialTypes)

type TutorialStepDefinition = TutorialTypes.TutorialStepDefinition
type TutorialVariant = TutorialTypes.TutorialVariant

local TutorialConfig = {}

local FUNNEL_VERSION = 2
local STARTER_KIT_SPLIT_PERCENT = 100
local FORCE_STARTER_KIT_FOR_INCOMPLETE_TUTORIALS = true
local START_ANALYTICS_STEP_ID = 1
local START_ANALYTICS_NAME = "Tutorial Started"

local SHOP_V1: TutorialVariant = "ShopV1"
local STARTER_KIT_V2: TutorialVariant = "StarterKitV2"

local shopV1Steps: { TutorialStepDefinition } = {
	{
		id = 1,
		text = "<b>Welcome to Juice Empire!</b> Let's get you started with your first buildings.",
		analyticsName = "Tutorial Started",
		tapToContinue = true,
		spotlightTarget = "None",
		beamTarget = "None",
	},
	{
		id = 2,
		text = "Teleport to the shops.",
		analyticsName = "Reached Shops",
		tapToContinue = false,
		spotlightTarget = "ShopTeleportButton",
		beamTarget = "None",
	},
	{
		id = 3,
		text = "Walk up to the trees shop.",
		analyticsName = "Opened Trees Shop",
		tapToContinue = false,
		spotlightTarget = "None",
		beamTarget = "TreesShop",
	},
	{
		id = 4,
		text = 'Purchase <font color="#38d96b">1 Oak Tree</font> from the shop.',
		analyticsName = "Purchased Oak Tree",
		tapToContinue = false,
		spotlightTarget = "OakTreeBuyButton",
		beamTarget = "None",
	},
	{
		id = 5,
		text = "Now, head over to the mills shop.",
		analyticsName = "Opened Mills Shop",
		tapToContinue = false,
		spotlightTarget = "None",
		beamTarget = "MillsShop",
	},
	{
		id = 6,
		text = 'Purchase <font color="#38d96b">1 Juice Mill</font> from the shop.',
		analyticsName = "Purchased Cider Mill",
		tapToContinue = false,
		spotlightTarget = "CiderMillBuyButton",
		beamTarget = "None",
	},
	{
		id = 7,
		text = "Now, head back to your farm.",
		analyticsName = "Returned To Farm",
		tapToContinue = false,
		spotlightTarget = "PlotTeleportButton",
		beamTarget = "None",
	},
	{
		id = 8,
		text = "Equip your tree and place it down.",
		analyticsName = "Placed Oak Tree",
		tapToContinue = false,
		spotlightTarget = "OakTreeHotbar",
		beamTarget = "None",
	},
	{
		id = 9,
		text = "Now, place your mill down.",
		analyticsName = "Placed Cider Mill",
		tapToContinue = false,
		spotlightTarget = "None",
		beamTarget = "None",
	},
	{
		id = 10,
		text = "Pull out your scythe.",
		analyticsName = "Equipped Scythe",
		tapToContinue = false,
		spotlightTarget = "ScytheHotbar",
		beamTarget = "None",
	},
	{
		id = 11,
		text = "Swing at your tree to harvest.",
		analyticsName = "Harvested Apples",
		tapToContinue = false,
		spotlightTarget = "None",
		beamTarget = "OakTree",
	},
	{
		id = 12,
		text = "Your apples will automatically be turned into juice by your mills.",
		analyticsName = "Continued After Cider Explanation",
		tapToContinue = true,
		spotlightTarget = "None",
		beamTarget = "None",
	},
	{
		id = 13,
		text = "Walk over your mill to collect the juice.",
		analyticsName = "Collected Cider",
		tapToContinue = false,
		spotlightTarget = "None",
		beamTarget = "CiderMill",
	},
	{
		id = 14,
		text = "Now you need to sell your juice. Teleport to the sell stand.",
		analyticsName = "Reached Sell Area",
		tapToContinue = false,
		spotlightTarget = "SellTeleportButton",
		beamTarget = "None",
	},
	{
		id = 15,
		text = "Walk up to the sell stand.",
		analyticsName = "Opened Sell Stand",
		tapToContinue = false,
		spotlightTarget = "None",
		beamTarget = "SellStand",
	},
	{
		id = 16,
		text = "Sell your juice.",
		analyticsName = "Sold Cider",
		tapToContinue = false,
		spotlightTarget = "CiderSellButton",
		beamTarget = "None",
	},
	{
		id = 17,
		text = "Nice! Now you can afford more trees and mills. Make sure to buy both!",
		analyticsName = "Continued After Expansion Tip",
		tapToContinue = true,
		spotlightTarget = "None",
		beamTarget = "None",
	},
	{
		id = 18,
		text = "Congrats! You are ready to start your Juice Empire!",
		analyticsName = "Tutorial Completed",
		tapToContinue = false,
		spotlightTarget = "None",
		beamTarget = "None",
		autoContinueDelaySeconds = 2,
	},
}

local starterKitV2Steps: { TutorialStepDefinition } = {
	{
		id = 1,
		text = "Place your tree.",
		analyticsName = "Placed Oak Tree",
		analyticsStepId = 2,
		tapToContinue = false,
		spotlightTarget = "OakTreeHotbar",
		beamTarget = "None",
	},
	{
		id = 2,
		text = "Place your juice mill.",
		analyticsName = "Placed Cider Mill",
		analyticsStepId = 3,
		tapToContinue = false,
		spotlightTarget = "CiderMillHotbar",
		beamTarget = "None",
	},
	{
		id = 3,
		text = "Equip your scythe.",
		analyticsName = "Equipped Scythe",
		analyticsStepId = 4,
		tapToContinue = false,
		spotlightTarget = "ScytheHotbar",
		beamTarget = "None",
	},
	{
		id = 4,
		text = "Harvest your tree.",
		analyticsName = "Harvested Apples",
		analyticsStepId = 5,
		tapToContinue = false,
		spotlightTarget = "None",
		beamTarget = "OakTree",
	},
	{
		id = 5,
		text = "Walk over your mill to collect juice.",
		analyticsName = "Collected Cider",
		analyticsStepId = 6,
		tapToContinue = false,
		spotlightTarget = "None",
		beamTarget = "CiderMill",
	},
	{
		id = 6,
		text = "Go to the sell stand.",
		analyticsName = "Reached Sell Area",
		analyticsStepId = 7,
		tapToContinue = false,
		spotlightTarget = "SellTeleportButton",
		beamTarget = "SellStand",
	},
	{
		id = 7,
		text = "Sell your juice.",
		analyticsName = "Sold Cider",
		analyticsStepId = 8,
		tapToContinue = false,
		spotlightTarget = "CiderSellButton",
		beamTarget = "None",
	},
}

local stepsByVariant: { [TutorialVariant]: { TutorialStepDefinition } } = {
	ShopV1 = shopV1Steps,
	StarterKitV2 = starterKitV2Steps,
}

local funnelNamesByVariant: { [TutorialVariant]: string } = {
	ShopV1 = "Tutorial_ShopV1",
	StarterKitV2 = "Tutorial_StarterKitV2",
}

local stepsByIdByVariant: { [TutorialVariant]: { [number]: TutorialStepDefinition } } = {}
for variant, steps in pairs(stepsByVariant) do
	local stepsById: { [number]: TutorialStepDefinition } = {}
	for _, step in ipairs(steps) do
		stepsById[step.id] = table.freeze(step)
	end
	stepsByIdByVariant[variant] = table.freeze(stepsById)
	stepsByVariant[variant] = table.freeze(steps)
end

function TutorialConfig.isVariant(value: string): boolean
	return value == SHOP_V1 or value == STARTER_KIT_V2
end

function TutorialConfig.getFunnelVersion(): number
	return FUNNEL_VERSION
end

function TutorialConfig.getFunnelName(variant: TutorialVariant): string
	return funnelNamesByVariant[variant]
end

function TutorialConfig.getStartAnalyticsStepId(): number
	return START_ANALYTICS_STEP_ID
end

function TutorialConfig.getStartAnalyticsName(): string
	return START_ANALYTICS_NAME
end

function TutorialConfig.shouldLogStepCompletion(variant: TutorialVariant, stepIndex: number): boolean
	return not (variant == SHOP_V1 and stepIndex == 1)
end

function TutorialConfig.shouldForceStarterKitForIncompleteTutorials(): boolean
	return FORCE_STARTER_KIT_FOR_INCOMPLETE_TUTORIALS
end

function TutorialConfig.getAssignedVariant(userId: number): TutorialVariant
	local bucket = userId % 100
	return if bucket < STARTER_KIT_SPLIT_PERCENT then STARTER_KIT_V2 else SHOP_V1
end

function TutorialConfig.getVariantForUnassignedTutorial(userId: number, stepIndex: number): TutorialVariant
	if FORCE_STARTER_KIT_FOR_INCOMPLETE_TUTORIALS then
		return STARTER_KIT_V2
	end

	if stepIndex > 1 then
		return SHOP_V1
	end

	return TutorialConfig.getAssignedVariant(userId)
end

function TutorialConfig.getDefaultVariant(): TutorialVariant
	return SHOP_V1
end

function TutorialConfig.getStep(variant: TutorialVariant, stepIndex: number): TutorialStepDefinition?
	return stepsByIdByVariant[variant][stepIndex]
end

function TutorialConfig.getFinalStepIndex(variant: TutorialVariant): number
	return #stepsByVariant[variant]
end

return table.freeze(TutorialConfig)

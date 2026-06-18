--!strict

local TutorialTypes = require(script.Parent.TutorialTypes)

type TutorialStepDefinition = TutorialTypes.TutorialStepDefinition

local TutorialConfig = {}

local steps: { TutorialStepDefinition } = {
	{
		id = 1,
		text = "<b>Welcome to Cider Empire!</b> Let's get you started with your first buildings.",
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
		text = 'Purchase <font color="#38d96b">1 Cider Mill</font> from the shop.',
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
		text = "Your apples will automatically be turned into cider by your mills.",
		analyticsName = "Continued After Cider Explanation",
		tapToContinue = true,
		spotlightTarget = "None",
		beamTarget = "None",
	},
	{
		id = 13,
		text = "Walk over your mill to collect the cider.",
		analyticsName = "Collected Cider",
		tapToContinue = false,
		spotlightTarget = "None",
		beamTarget = "CiderMill",
	},
	{
		id = 14,
		text = "Now you need to sell your cider. Teleport to the sell stand.",
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
		text = "Sell your cider.",
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
		text = "Congrats! You are ready to start your Cider Empire!",
		analyticsName = "Tutorial Completed",
		tapToContinue = false,
		spotlightTarget = "None",
		beamTarget = "None",
		autoContinueDelaySeconds = 2,
	},
}

local stepsById: { [number]: TutorialStepDefinition } = {}
for _, step in ipairs(steps) do
	stepsById[step.id] = table.freeze(step)
end

function TutorialConfig.getStep(stepIndex: number): TutorialStepDefinition?
	return stepsById[stepIndex]
end

function TutorialConfig.getFinalStepIndex(): number
	return #steps
end

return table.freeze(TutorialConfig)

--!strict

local TutorialTypes = require(script.Parent.TutorialTypes)

type TutorialStepDefinition = TutorialTypes.TutorialStepDefinition

local TutorialConfig = {}

local steps: { TutorialStepDefinition } = {
	{
		id = 1,
		text = "<b>Welcome to Cider Empire!</b> Let's get you started with your first buildings.",
		tapToContinue = true,
		spotlightTarget = "None",
		beamTarget = "None",
	},
	{
		id = 2,
		text = "Teleport to the shops.",
		tapToContinue = false,
		spotlightTarget = "ShopTeleportButton",
		beamTarget = "None",
	},
	{
		id = 3,
		text = "Walk up to the trees shop.",
		tapToContinue = false,
		spotlightTarget = "None",
		beamTarget = "TreesShop",
	},
	{
		id = 4,
		text = 'Purchase <font color="#38d96b">1 Oak Tree</font> from the shop.',
		tapToContinue = false,
		spotlightTarget = "OakTreeBuyButton",
		beamTarget = "None",
	},
	{
		id = 5,
		text = "Now, head over to the mills shop.",
		tapToContinue = false,
		spotlightTarget = "None",
		beamTarget = "MillsShop",
	},
	{
		id = 6,
		text = 'Purchase <font color="#38d96b">1 Cider Mill</font> from the shop.',
		tapToContinue = false,
		spotlightTarget = "CiderMillBuyButton",
		beamTarget = "None",
	},
	{
		id = 7,
		text = "Now, head back to your farm.",
		tapToContinue = false,
		spotlightTarget = "PlotTeleportButton",
		beamTarget = "None",
	},
	{
		id = 8,
		text = "Equip your tree and place it down.",
		tapToContinue = false,
		spotlightTarget = "OakTreeHotbar",
		beamTarget = "None",
	},
	{
		id = 9,
		text = "Now, place your mill down.",
		tapToContinue = false,
		spotlightTarget = "None",
		beamTarget = "None",
	},
	{
		id = 10,
		text = "Pull out your scythe.",
		tapToContinue = false,
		spotlightTarget = "ScytheHotbar",
		beamTarget = "None",
	},
	{
		id = 11,
		text = "Swing at your tree to harvest.",
		tapToContinue = false,
		spotlightTarget = "None",
		beamTarget = "OakTree",
	},
	{
		id = 12,
		text = "Your apples will automatically be turned into cider by your mills.",
		tapToContinue = true,
		spotlightTarget = "None",
		beamTarget = "None",
	},
	{
		id = 13,
		text = "Walk over your mill to collect the cider.",
		tapToContinue = false,
		spotlightTarget = "None",
		beamTarget = "CiderMill",
	},
	{
		id = 14,
		text = "Now you need to sell your cider. Teleport to the sell stand.",
		tapToContinue = false,
		spotlightTarget = "SellTeleportButton",
		beamTarget = "None",
	},
	{
		id = 15,
		text = "Walk up to the sell stand.",
		tapToContinue = false,
		spotlightTarget = "None",
		beamTarget = "SellStand",
	},
	{
		id = 16,
		text = "Sell your cider.",
		tapToContinue = false,
		spotlightTarget = "CiderSellButton",
		beamTarget = "None",
	},
	{
		id = 17,
		text = "Nice! Now you can afford more trees and mills. Make sure to buy both!",
		tapToContinue = true,
		spotlightTarget = "None",
		beamTarget = "None",
	},
	{
		id = 18,
		text = "Congrats! You are ready to start your Cider Empire!",
		tapToContinue = false,
		spotlightTarget = "None",
		beamTarget = "None",
		autoDismissSeconds = 2,
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

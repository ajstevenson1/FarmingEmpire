--!strict

local currentStepIndex: number? = nil
local completed = false

local TutorialClientState = {}

function TutorialClientState.setCurrentStep(stepIndex: number?, isCompleted: boolean)
	currentStepIndex = stepIndex
	completed = isCompleted
end

function TutorialClientState.shouldUseFreePurchase(shopId: string, productId: string): boolean
	if completed then
		return false
	end

	return (currentStepIndex == 4 and shopId == "TreesShop" and productId == "OakTree")
		or (currentStepIndex == 6 and shopId == "MillsShop" and productId == "CiderMill")
end

return table.freeze(TutorialClientState)

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local tutorialFolder = sharedFolder:WaitForChild("Tutorial") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder
local shopsFolder = sharedFolder:WaitForChild("Shops") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local TutorialConfig = require(tutorialFolder:WaitForChild("TutorialConfig") :: ModuleScript)
local TutorialTypes = require(tutorialFolder:WaitForChild("TutorialTypes") :: ModuleScript)
local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)
local ShopTypes = require(shopsFolder:WaitForChild("ShopTypes") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)

local InventoryService = require(script.Parent.Parent.Inventory.InventoryService)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)
local PlotService = require(script.Parent.Parent.Plots.PlotService)
local Remotes = require(script.Parent.Parent.Networking.Remotes)
local ResourceService = require(script.Parent.Parent.Resources.ResourceService)

type TutorialData = TutorialTypes.TutorialData
type TutorialStepPayload = TutorialTypes.TutorialStepPayload
type ItemId = InventoryTypes.ItemId
type ResourceId = ResourceTypes.ResourceId
type ShopId = ShopTypes.ShopId
type ShopProductId = ShopTypes.ShopProductId
type BuildingId = BuildingTypes.BuildingId

local OAK_TREE_ITEM_ID: ItemId = "OakTree"
local CIDER_MILL_ITEM_ID: ItemId = "CiderMill"
local SCYTHE_ITEM_ID: ItemId = "Scythe"

local SHOP_NEAR_PART_NAME = "ShopTeleport"
local TREES_SHOP_MODEL_NAME = "TreesShop"
local MILLS_SHOP_MODEL_NAME = "MillsShop"
local SHOP_TOUCH_PART_NAME = "Touch"
local SELL_NEAR_MODEL_NAME = "CiderSell"
local SELL_NEAR_TOUCH_PART_NAME = "Touch"
local NEAR_DISTANCE_STUDS = 55
local POLL_INTERVAL_SECONDS = 0.5
local FINAL_STEP_COMPLETE_DELAY_SECONDS = 2

local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
local ITEM_ID_ATTRIBUTE = "ItemId"
local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"

local hasStarted = false
local completionTaskByPlayer: { [Player]: thread } = {}

local function cloneTutorialData(data: TutorialData): TutorialData
	return {
		stepIndex = data.stepIndex,
		completed = data.completed,
	}
end

local function buildPayload(player: Player): TutorialStepPayload
	local data = PlayerDataService.getTutorialData(player)
	return {
		step = if data.completed then nil else TutorialConfig.getStep(data.stepIndex),
		data = cloneTutorialData(data),
	}
end

local function sendStep(player: Player)
	Remotes.getTutorialRemotes().tutorialStepUpdated:FireClient(player, buildPayload(player))
end

local function getHumanoidRootPart(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil
	end

	return rootPart
end

local function findWorkspaceBasePartByName(name: string): BasePart?
	local candidate = Workspace:FindFirstChild(name, true)
	if candidate ~= nil and candidate:IsA("BasePart") then
		return candidate
	end

	return nil
end

local function isPlayerNearPart(player: Player, part: BasePart?, distanceStuds: number): boolean
	local rootPart = getHumanoidRootPart(player)
	if rootPart == nil or part == nil then
		return false
	end

	return (rootPart.Position - part.Position).Magnitude <= distanceStuds
end

local function getSellTouchPart(): BasePart?
	local sellModel = Workspace:FindFirstChild(SELL_NEAR_MODEL_NAME)
	if sellModel == nil then
		return nil
	end

	local touchPart = sellModel:FindFirstChild(SELL_NEAR_TOUCH_PART_NAME, true)
	if touchPart ~= nil and touchPart:IsA("BasePart") then
		return touchPart
	end

	return nil
end

local function getModelTouchPart(modelName: string, touchPartName: string): BasePart?
	local model = Workspace:FindFirstChild(modelName)
	if model == nil then
		return nil
	end

	local touchPart = model:FindFirstChild(touchPartName, true)
	if touchPart ~= nil and touchPart:IsA("BasePart") then
		return touchPart
	end

	return nil
end

local function isPlayerNearShopArea(player: Player): boolean
	return isPlayerNearPart(player, findWorkspaceBasePartByName(SHOP_NEAR_PART_NAME), NEAR_DISTANCE_STUDS)
		or isPlayerNearPart(player, getModelTouchPart(TREES_SHOP_MODEL_NAME, SHOP_TOUCH_PART_NAME), NEAR_DISTANCE_STUDS)
		or isPlayerNearPart(player, getModelTouchPart(MILLS_SHOP_MODEL_NAME, SHOP_TOUCH_PART_NAME), NEAR_DISTANCE_STUDS)
end

local function isPlayerNearAssignedPlot(player: Player): boolean
	local rootPart = getHumanoidRootPart(player)
	local plotBase = PlotService.getAssignedPlotBase(player)
	if rootPart == nil or plotBase == nil then
		return false
	end

	return (rootPart.Position - plotBase.Position).Magnitude <= math.max(plotBase.Size.X, plotBase.Size.Z) * 0.5 + 35
end

local function getPlacedObjectsFolder(): Folder?
	local folder = Workspace:FindFirstChild(PLACED_OBJECTS_FOLDER_NAME)
	if folder == nil then
		return nil
	end

	if not folder:IsA("Folder") then
		return nil
	end

	return folder
end

local function hasPlacedBuilding(player: Player, buildingId: BuildingId): boolean
	local placedObjectsFolder = getPlacedObjectsFolder()
	if placedObjectsFolder == nil then
		return false
	end

	for _, child in ipairs(placedObjectsFolder:GetChildren()) do
		if child:IsA("BasePart")
			and child:GetAttribute(OWNER_USER_ID_ATTRIBUTE) == player.UserId
			and child:GetAttribute(ITEM_ID_ATTRIBUTE) == buildingId
		then
			return true
		end
	end

	return false
end

local function hasItem(player: Player, itemId: ItemId): boolean
	return InventoryService.getItemQuantity(player, itemId) > 0
end

local function cancelFinalCompletionTask(player: Player)
	local existingTask = completionTaskByPlayer[player]
	if existingTask ~= nil then
		local success, result = pcall(function()
			if coroutine.status(existingTask) ~= "running" and coroutine.status(existingTask) ~= "dead" then
				task.cancel(existingTask)
			end
		end)
		if not success then
			warn(string.format("Failed to cancel tutorial completion task for %s: %s", player.Name, tostring(result)))
		end
		completionTaskByPlayer[player] = nil
	end
end

local TutorialService = {}

local function completeTutorial(player: Player)
	cancelFinalCompletionTask(player)
	PlayerDataService.completeTutorial(player)
	sendStep(player)
end

local function scheduleFinalCompletion(player: Player)
	cancelFinalCompletionTask(player)
	completionTaskByPlayer[player] = task.delay(FINAL_STEP_COMPLETE_DELAY_SECONDS, function()
		completionTaskByPlayer[player] = nil
		if PlayerDataService.getTutorialData(player).stepIndex == TutorialConfig.getFinalStepIndex() then
			completeTutorial(player)
		end
	end)
end

local function advanceToStep(player: Player, stepIndex: number)
	local currentData = PlayerDataService.getTutorialData(player)
	if currentData.completed then
		return
	end

	local finalStepIndex = TutorialConfig.getFinalStepIndex()
	if stepIndex > finalStepIndex then
		completeTutorial(player)
		return
	end

	PlayerDataService.setTutorialStep(player, stepIndex)
	sendStep(player)

	if stepIndex == finalStepIndex then
		scheduleFinalCompletion(player)
	end
end

local function advanceIfCurrentStep(player: Player, expectedStepIndex: number)
	local data = PlayerDataService.getTutorialData(player)
	if data.completed or data.stepIndex ~= expectedStepIndex then
		return
	end

	advanceToStep(player, expectedStepIndex + 1)
end

local function advancePastAlreadySatisfiedSteps(player: Player)
	local didAdvance = true
	while didAdvance do
		didAdvance = false
		local data = PlayerDataService.getTutorialData(player)
		if data.completed then
			return
		end

		if data.stepIndex == 4 and hasItem(player, OAK_TREE_ITEM_ID) then
			advanceToStep(player, 5)
			didAdvance = true
		elseif data.stepIndex == 6 and hasItem(player, CIDER_MILL_ITEM_ID) then
			advanceToStep(player, 7)
			didAdvance = true
		elseif data.stepIndex == 8 and hasPlacedBuilding(player, OAK_TREE_ITEM_ID :: BuildingId) then
			advanceToStep(player, 9)
			didAdvance = true
		elseif data.stepIndex == 9 and hasPlacedBuilding(player, CIDER_MILL_ITEM_ID :: BuildingId) then
			advanceToStep(player, 10)
			didAdvance = true
		elseif data.stepIndex == 10 and InventoryService.getEquippedItemId(player) == SCYTHE_ITEM_ID then
			advanceToStep(player, 11)
			didAdvance = true
		elseif data.stepIndex == 11 and ResourceService.getResourceAmount(player, "Apple") > 0 then
			advanceToStep(player, 12)
			didAdvance = true
		elseif data.stepIndex == 13 and ResourceService.getResourceAmount(player, "Cider") > 0 then
			advanceToStep(player, 14)
			didAdvance = true
		end
	end
end

local function initializePlayer(player: Player)
	PlayerDataService.waitForData(player)
	advancePastAlreadySatisfiedSteps(player)
	sendStep(player)

	if PlayerDataService.getTutorialData(player).stepIndex == TutorialConfig.getFinalStepIndex() then
		scheduleFinalCompletion(player)
	end
end

local function startProximityLoop()
	task.spawn(function()
		while hasStarted do
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerDataService.getTutorialData(player)
				if data.completed then
					continue
				end

				if data.stepIndex == 2 and isPlayerNearShopArea(player) then
					advanceToStep(player, 3)
				elseif data.stepIndex == 7 and isPlayerNearAssignedPlot(player) then
					advanceToStep(player, 8)
				elseif data.stepIndex == 14 and isPlayerNearPart(player, getSellTouchPart(), NEAR_DISTANCE_STUDS) then
					advanceToStep(player, 15)
				end
			end

			task.wait(POLL_INTERVAL_SECONDS)
		end
	end)
end

function TutorialService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local tutorialRemotes = Remotes.getTutorialRemotes()
	tutorialRemotes.getTutorialSnapshot.OnServerInvoke = function(player: Player): TutorialStepPayload
		return buildPayload(player)
	end
	tutorialRemotes.tutorialTapContinue.OnServerEvent:Connect(function(player: Player)
		local data = PlayerDataService.getTutorialData(player)
		if data.stepIndex == 1 or data.stepIndex == 12 or data.stepIndex == 17 then
			advanceIfCurrentStep(player, data.stepIndex)
		end
	end)

	InventoryService.observeEquippedItemChanged(function(player: Player, itemId: ItemId?)
		if itemId == SCYTHE_ITEM_ID then
			advanceIfCurrentStep(player, 10)
		end
	end)

	ResourceService.observeResourceAdded(function(player: Player, resourceId: ResourceId, _amount: number)
		if resourceId == "Apple" then
			advanceIfCurrentStep(player, 11)
		elseif resourceId == "Cider" then
			advanceIfCurrentStep(player, 13)
		end
	end)

	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		cancelFinalCompletionTask(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		initializePlayer(player)
	end

	startProximityLoop()
end

function TutorialService.handleShopOpened(player: Player, shopId: ShopId)
	local data = PlayerDataService.getTutorialData(player)
	if shopId == "TreesShop" then
		if data.stepIndex == 2 then
			advanceToStep(player, 4)
			return
		end
		advanceIfCurrentStep(player, 3)
	elseif shopId == "MillsShop" then
		advanceIfCurrentStep(player, 5)
	end
end

function TutorialService.shouldUseFreeTutorialPurchase(player: Player, shopId: ShopId, productId: ShopProductId): boolean
	local data = PlayerDataService.getTutorialData(player)
	return (data.stepIndex == 4 and shopId == "TreesShop" and productId == OAK_TREE_ITEM_ID)
		or (data.stepIndex == 6 and shopId == "MillsShop" and productId == CIDER_MILL_ITEM_ID)
end

function TutorialService.handleShopPurchaseSucceeded(player: Player, _shopId: ShopId, productId: ShopProductId)
	if productId == OAK_TREE_ITEM_ID then
		advanceIfCurrentStep(player, 4)
	elseif productId == CIDER_MILL_ITEM_ID then
		advanceIfCurrentStep(player, 6)
	end
end

function TutorialService.handleBuildingPlaced(player: Player, buildingId: BuildingId)
	if buildingId == OAK_TREE_ITEM_ID then
		advanceIfCurrentStep(player, 8)
	elseif buildingId == CIDER_MILL_ITEM_ID then
		advanceIfCurrentStep(player, 9)
	end
end

function TutorialService.handleCiderSellOpened(player: Player)
	advanceIfCurrentStep(player, 15)
end

function TutorialService.handleCiderSold(player: Player)
	advanceIfCurrentStep(player, 16)
end

return table.freeze(TutorialService)

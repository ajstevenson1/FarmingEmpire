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
local TutorialFunnelTypes = require(tutorialFolder:WaitForChild("TutorialFunnelTypes") :: ModuleScript)
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
local TutorialFunnelService = require(script.Parent.TutorialFunnelService)

type TutorialData = TutorialTypes.TutorialData
type TutorialStepDefinition = TutorialTypes.TutorialStepDefinition
type TutorialStepPayload = TutorialTypes.TutorialStepPayload
type TutorialVariant = TutorialTypes.TutorialVariant
type TutorialCompletionSource = TutorialFunnelTypes.TutorialCompletionSource
type ItemId = InventoryTypes.ItemId
type ResourceId = ResourceTypes.ResourceId
type ShopId = ShopTypes.ShopId
type ShopProductId = ShopTypes.ShopProductId
type BuildingId = BuildingTypes.BuildingId

local SHOP_V1: TutorialVariant = "ShopV1"
local STARTER_KIT_V2: TutorialVariant = "StarterKitV2"

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

local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
local ITEM_ID_ATTRIBUTE = "ItemId"
local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"

local hasStarted = false

local function cloneTutorialData(data: TutorialData, variant: TutorialVariant): TutorialData
	return {
		stepIndex = data.stepIndex,
		completed = data.completed,
		variant = variant,
		starterKitGranted = data.starterKitGranted,
	}
end

local function getTutorialVariant(player: Player): TutorialVariant
	local data = PlayerDataService.getTutorialData(player)
	if data.completed then
		return data.variant or TutorialConfig.getDefaultVariant()
	end

	return PlayerDataService.ensureTutorialVariant(player)
end

local function buildPayload(player: Player): TutorialStepPayload
	local variant = getTutorialVariant(player)
	local data = PlayerDataService.getTutorialData(player)
	return {
		step = if data.completed then nil else TutorialConfig.getStep(variant, data.stepIndex),
		data = cloneTutorialData(data, variant),
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

local function grantStarterKitItemIfMissing(player: Player, itemId: ItemId, buildingId: BuildingId)
	if hasItem(player, itemId) or hasPlacedBuilding(player, buildingId) then
		return
	end

	InventoryService.addItem(player, itemId, 1)
end

local function isShopV1(player: Player): boolean
	return getTutorialVariant(player) == SHOP_V1
end

local function isStarterKitV2(player: Player): boolean
	return getTutorialVariant(player) == STARTER_KIT_V2
end

local function getCurrentStepDefinition(player: Player, data: TutorialData): TutorialStepDefinition?
	return TutorialConfig.getStep(getTutorialVariant(player), data.stepIndex)
end

local TutorialService = {}

local function completeTutorial(player: Player, completionSource: TutorialCompletionSource)
	local currentData = PlayerDataService.getTutorialData(player)
	if currentData.completed then
		return
	end

	TutorialFunnelService.completeTutorial(player, currentData.stepIndex, completionSource)
	PlayerDataService.completeTutorial(player)
	sendStep(player)
end

local function advanceToStep(player: Player, stepIndex: number, completionSource: TutorialCompletionSource)
	local currentData = PlayerDataService.getTutorialData(player)
	if currentData.completed then
		return
	end

	local variant = getTutorialVariant(player)
	local finalStepIndex = TutorialConfig.getFinalStepIndex(variant)
	if stepIndex > finalStepIndex then
		completeTutorial(player, completionSource)
		return
	end

	TutorialFunnelService.completeStep(player, currentData.stepIndex, completionSource)
	PlayerDataService.setTutorialStep(player, stepIndex)
	TutorialFunnelService.reachStep(player, stepIndex)
	sendStep(player)
end

local function advanceIfCurrentStep(player: Player, expectedStepIndex: number, completionSource: TutorialCompletionSource)
	local data = PlayerDataService.getTutorialData(player)
	if data.completed or data.stepIndex ~= expectedStepIndex then
		return
	end

	advanceToStep(player, expectedStepIndex + 1, completionSource)
end

local function grantStarterKitIfNeeded(player: Player)
	local variant = getTutorialVariant(player)
	local data = PlayerDataService.getTutorialData(player)
	if variant ~= STARTER_KIT_V2 or data.completed or data.starterKitGranted then
		return
	end

	grantStarterKitItemIfMissing(player, OAK_TREE_ITEM_ID, OAK_TREE_ITEM_ID :: BuildingId)
	grantStarterKitItemIfMissing(player, CIDER_MILL_ITEM_ID, CIDER_MILL_ITEM_ID :: BuildingId)
	PlayerDataService.markTutorialStarterKitGranted(player)
end

local function advanceShopV1PastAlreadySatisfiedSteps(player: Player, data: TutorialData): boolean
	if data.stepIndex == 4 and hasItem(player, OAK_TREE_ITEM_ID) then
		advanceToStep(player, 5, "AlreadySatisfied")
		return true
	elseif data.stepIndex == 6 and hasItem(player, CIDER_MILL_ITEM_ID) then
		advanceToStep(player, 7, "AlreadySatisfied")
		return true
	elseif data.stepIndex == 8 and hasPlacedBuilding(player, OAK_TREE_ITEM_ID :: BuildingId) then
		advanceToStep(player, 9, "AlreadySatisfied")
		return true
	elseif data.stepIndex == 9 and hasPlacedBuilding(player, CIDER_MILL_ITEM_ID :: BuildingId) then
		advanceToStep(player, 10, "AlreadySatisfied")
		return true
	elseif data.stepIndex == 10 and InventoryService.getEquippedItemId(player) == SCYTHE_ITEM_ID then
		advanceToStep(player, 11, "AlreadySatisfied")
		return true
	elseif data.stepIndex == 11 and ResourceService.getResourceAmount(player, "Apple") > 0 then
		advanceToStep(player, 12, "AlreadySatisfied")
		return true
	elseif data.stepIndex == 13 and ResourceService.getResourceAmount(player, "Cider") > 0 then
		advanceToStep(player, 14, "AlreadySatisfied")
		return true
	end

	return false
end

local function advanceStarterKitV2PastAlreadySatisfiedSteps(player: Player, data: TutorialData): boolean
	if data.stepIndex == 1 and hasPlacedBuilding(player, OAK_TREE_ITEM_ID :: BuildingId) then
		advanceToStep(player, 2, "AlreadySatisfied")
		return true
	elseif data.stepIndex == 2 and hasPlacedBuilding(player, CIDER_MILL_ITEM_ID :: BuildingId) then
		advanceToStep(player, 3, "AlreadySatisfied")
		return true
	elseif data.stepIndex == 3 and InventoryService.getEquippedItemId(player) == SCYTHE_ITEM_ID then
		advanceToStep(player, 4, "AlreadySatisfied")
		return true
	elseif data.stepIndex == 4 and ResourceService.getResourceAmount(player, "Apple") > 0 then
		advanceToStep(player, 5, "AlreadySatisfied")
		return true
	elseif data.stepIndex == 5 and ResourceService.getResourceAmount(player, "Cider") > 0 then
		advanceToStep(player, 6, "AlreadySatisfied")
		return true
	end

	return false
end

local function advancePastAlreadySatisfiedSteps(player: Player)
	local didAdvance = true
	while didAdvance do
		didAdvance = false
		local data = PlayerDataService.getTutorialData(player)
		if data.completed then
			return
		end

		if isShopV1(player) then
			didAdvance = advanceShopV1PastAlreadySatisfiedSteps(player, data)
		elseif isStarterKitV2(player) then
			didAdvance = advanceStarterKitV2PastAlreadySatisfiedSteps(player, data)
		end
	end
end

local function initializePlayer(player: Player)
	PlayerDataService.waitForData(player)
	getTutorialVariant(player)
	grantStarterKitIfNeeded(player)
	advancePastAlreadySatisfiedSteps(player)

	local data = PlayerDataService.getTutorialData(player)
	if not data.completed then
		TutorialFunnelService.reachStep(player, data.stepIndex)
	end

	sendStep(player)
end

local function startProximityLoop()
	task.spawn(function()
		while hasStarted do
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerDataService.getTutorialData(player)
				if data.completed then
					continue
				end

				if isShopV1(player) then
					if data.stepIndex == 2 and isPlayerNearShopArea(player) then
						advanceToStep(player, 3, "Proximity")
					elseif data.stepIndex == 7 and isPlayerNearAssignedPlot(player) then
						advanceToStep(player, 8, "Proximity")
					elseif data.stepIndex == 14 and isPlayerNearPart(player, getSellTouchPart(), NEAR_DISTANCE_STUDS) then
						advanceToStep(player, 15, "Proximity")
					end
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
		if data.completed then
			return
		end

		local step = getCurrentStepDefinition(player, data)
		if step == nil or (not step.tapToContinue and step.autoContinueDelaySeconds == nil) then
			return
		end

		local variant = getTutorialVariant(player)
		local completionSource: TutorialCompletionSource = if data.stepIndex == TutorialConfig.getFinalStepIndex(variant)
			then "AutoContinue"
			else "TapContinue"
		advanceIfCurrentStep(player, data.stepIndex, completionSource)
	end)
	tutorialRemotes.tutorialSkipRequested.OnServerEvent:Connect(function(player: Player)
		local data = PlayerDataService.getTutorialData(player)
		if not data.completed then
			TutorialFunnelService.skipTutorial(player, data.stepIndex)
			PlayerDataService.completeTutorial(player)
			sendStep(player)
		end
	end)

	InventoryService.observeEquippedItemChanged(function(player: Player, itemId: ItemId?)
		if itemId ~= SCYTHE_ITEM_ID then
			return
		end

		if isShopV1(player) then
			advanceIfCurrentStep(player, 10, "ItemEquipped")
		elseif isStarterKitV2(player) then
			advanceIfCurrentStep(player, 3, "ItemEquipped")
		end
	end)

	ResourceService.observeResourceAdded(function(player: Player, resourceId: ResourceId, _amount: number)
		if isShopV1(player) then
			if resourceId == "Apple" then
				advanceIfCurrentStep(player, 11, "ResourceAdded")
			elseif resourceId == "Cider" then
				advanceIfCurrentStep(player, 13, "ResourceAdded")
			end
		elseif isStarterKitV2(player) then
			if resourceId == "Apple" then
				advanceIfCurrentStep(player, 4, "ResourceAdded")
			elseif resourceId == "Cider" then
				advanceIfCurrentStep(player, 5, "ResourceAdded")
			end
		end
	end)

	Players.PlayerAdded:Connect(initializePlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		initializePlayer(player)
	end

	startProximityLoop()
end

function TutorialService.handleShopOpened(player: Player, shopId: ShopId)
	if not isShopV1(player) then
		return
	end

	local data = PlayerDataService.getTutorialData(player)
	if shopId == "TreesShop" then
		if data.stepIndex == 2 then
			advanceToStep(player, 4, "ShopOpened")
			return
		end
		advanceIfCurrentStep(player, 3, "ShopOpened")
	elseif shopId == "MillsShop" then
		advanceIfCurrentStep(player, 5, "ShopOpened")
	end
end

function TutorialService.shouldUseFreeTutorialPurchase(player: Player, shopId: ShopId, productId: ShopProductId): boolean
	local data = PlayerDataService.getTutorialData(player)
	if data.completed then
		return false
	end

	if not isShopV1(player) then
		return false
	end

	return (data.stepIndex == 4 and shopId == "TreesShop" and productId == OAK_TREE_ITEM_ID)
		or (data.stepIndex == 6 and shopId == "MillsShop" and productId == CIDER_MILL_ITEM_ID)
end

function TutorialService.getFreeTutorialProductId(player: Player, shopId: ShopId): ShopProductId?
	local data = PlayerDataService.getTutorialData(player)
	if data.completed then
		return nil
	end

	if not isShopV1(player) then
		return nil
	end

	if data.stepIndex == 4 and shopId == "TreesShop" then
		return OAK_TREE_ITEM_ID
	elseif data.stepIndex == 6 and shopId == "MillsShop" then
		return CIDER_MILL_ITEM_ID
	end

	return nil
end

function TutorialService.handleShopPurchaseSucceeded(player: Player, _shopId: ShopId, productId: ShopProductId)
	if not isShopV1(player) then
		return
	end

	if productId == OAK_TREE_ITEM_ID then
		advanceIfCurrentStep(player, 4, "ShopPurchase")
	elseif productId == CIDER_MILL_ITEM_ID then
		advanceIfCurrentStep(player, 6, "ShopPurchase")
	end
end

function TutorialService.handleBuildingPlaced(player: Player, buildingId: BuildingId)
	if isShopV1(player) then
		if buildingId == OAK_TREE_ITEM_ID then
			advanceIfCurrentStep(player, 8, "BuildingPlaced")
		elseif buildingId == CIDER_MILL_ITEM_ID then
			advanceIfCurrentStep(player, 9, "BuildingPlaced")
		end
	elseif isStarterKitV2(player) then
		if buildingId == OAK_TREE_ITEM_ID then
			advanceIfCurrentStep(player, 1, "BuildingPlaced")
		elseif buildingId == CIDER_MILL_ITEM_ID then
			advanceIfCurrentStep(player, 2, "BuildingPlaced")
		end
	end
end

function TutorialService.handleCiderSellOpened(player: Player)
	if isShopV1(player) then
		advanceIfCurrentStep(player, 15, "ShopOpened")
	elseif isStarterKitV2(player) then
		advanceIfCurrentStep(player, 6, "ShopOpened")
	end
end

function TutorialService.handleCiderSold(player: Player)
	if isShopV1(player) then
		advanceIfCurrentStep(player, 16, "CiderSold")
	elseif isStarterKitV2(player) then
		advanceIfCurrentStep(player, 7, "CiderSold")
	end
end

return table.freeze(TutorialService)

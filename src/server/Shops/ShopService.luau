--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local shopsFolder = sharedFolder:WaitForChild("Shops") :: Folder

local ShopCatalog = require(shopsFolder:WaitForChild("ShopCatalog") :: ModuleScript)
local ShopTypes = require(shopsFolder:WaitForChild("ShopTypes") :: ModuleScript)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)
local EconomyService = require(script.Parent.Parent.Economy.EconomyService)
local InventoryService = require(script.Parent.Parent.Inventory.InventoryService)
local Remotes = require(script.Parent.Parent.Networking.Remotes)

type ShopDefinition = ShopTypes.ShopDefinition
type ShopId = ShopTypes.ShopId
type ShopProductDefinition = ShopTypes.ShopProductDefinition
type ShopProductId = ShopTypes.ShopProductId
type ShopPurchaseResult = ShopTypes.ShopPurchaseResult
type ShopPurchaseStatus = ShopTypes.ShopPurchaseStatus
type ShopRestockState = ShopTypes.ShopRestockState
type ShopSnapshot = ShopTypes.ShopSnapshot

local TOUCH_OPEN_DEBOUNCE_SECONDS = 1
local MAX_PURCHASE_DISTANCE_STUDS = 40

local hasStarted = false
local nextRestockAtByPlayer: { [Player]: { [ShopId]: number } } = {}
local stockRemainingByPlayer: { [Player]: { [ShopId]: { [ShopProductId]: number } } } = {}
local nextAllowedOpenAtByPlayer: { [Player]: { [ShopId]: number } } = {}

local function getCurrentTime(): number
	return Workspace:GetServerTimeNow()
end

local function getPlayerRestockState(player: Player): { [ShopId]: number }
	local state = nextRestockAtByPlayer[player]
	if state == nil then
		state = {}
		nextRestockAtByPlayer[player] = state
	end

	return state
end

local function getPlayerOpenDebounces(player: Player): { [ShopId]: number }
	local state = nextAllowedOpenAtByPlayer[player]
	if state == nil then
		state = {}
		nextAllowedOpenAtByPlayer[player] = state
	end

	return state
end

local function getPlayerStockState(player: Player): { [ShopId]: { [ShopProductId]: number } }
	local state = stockRemainingByPlayer[player]
	if state == nil then
		state = {}
		stockRemainingByPlayer[player] = state
	end

	return state
end

local function getShopStockState(player: Player, shopId: ShopId): { [ShopProductId]: number }
	local playerStockState = getPlayerStockState(player)
	local shopStockState = playerStockState[shopId]
	if shopStockState == nil then
		shopStockState = {}
		playerStockState[shopId] = shopStockState
	end

	return shopStockState
end

local function hasAnyStockEntry(stockState: { [ShopProductId]: number }): boolean
	for _ in pairs(stockState) do
		return true
	end

	return false
end

local function setFullShopStock(shopId: ShopId, stockState: { [ShopProductId]: number })
	local validProductIds: { [ShopProductId]: boolean } = {}
	for _, productDefinition in ipairs(ShopCatalog.getShopProducts(shopId)) do
		validProductIds[productDefinition.id] = true
		stockState[productDefinition.id] = productDefinition.stockPerRestock
	end

	for productId in pairs(stockState) do
		if validProductIds[productId] ~= true then
			stockState[productId] = nil
		end
	end
end

local function fillMissingShopStock(shopId: ShopId, stockState: { [ShopProductId]: number })
	local validProductIds: { [ShopProductId]: boolean } = {}
	for _, productDefinition in ipairs(ShopCatalog.getShopProducts(shopId)) do
		validProductIds[productDefinition.id] = true
		if stockState[productDefinition.id] == nil then
			stockState[productDefinition.id] = productDefinition.stockPerRestock
		end
	end

	for productId in pairs(stockState) do
		if validProductIds[productId] ~= true then
			stockState[productId] = nil
		end
	end
end

local function getNormalizedNextRestockAt(player: Player, definition: ShopDefinition, currentTime: number): number
	local playerState = getPlayerRestockState(player)
	local shopStockState = getShopStockState(player, definition.id)
	local nextRestockAt = playerState[definition.id]
	local shouldResetStock = false
	if nextRestockAt == nil then
		nextRestockAt = currentTime + definition.restockIntervalSeconds
		shouldResetStock = true
	end

	while nextRestockAt <= currentTime do
		nextRestockAt += definition.restockIntervalSeconds
		shouldResetStock = true
	end

	playerState[definition.id] = nextRestockAt
	if shouldResetStock or not hasAnyStockEntry(shopStockState) then
		setFullShopStock(definition.id, shopStockState)
	else
		fillMissingShopStock(definition.id, shopStockState)
	end

	return nextRestockAt
end

local function cloneShopStockState(stockState: { [ShopProductId]: number }): { [ShopProductId]: number }
	local clone: { [ShopProductId]: number } = {}
	for productId, remainingStock in pairs(stockState) do
		clone[productId] = remainingStock
	end

	return clone
end

local function buildSnapshot(player: Player): ShopSnapshot
	local currentTime = getCurrentTime()
	local shopsById: { [ShopId]: ShopRestockState } = {}

	for _, shopId in ipairs(ShopCatalog.getShopIds()) do
		local definition = ShopCatalog.getShopDefinition(shopId)
		shopsById[shopId] = {
			nextRestockAt = getNormalizedNextRestockAt(player, definition, currentTime),
			stockRemainingByProductId = cloneShopStockState(getShopStockState(player, shopId)),
		}
	end

	return {
		shopsById = shopsById,
	}
end

local function canOpenShopForPlayer(player: Player, shopId: ShopId, currentTime: number): boolean
	local debounces = getPlayerOpenDebounces(player)
	local nextAllowedOpenAt = debounces[shopId] or 0
	if currentTime < nextAllowedOpenAt then
		return false
	end

	debounces[shopId] = currentTime + TOUCH_OPEN_DEBOUNCE_SECONDS
	return true
end

local function findPlayerFromTouchedPart(touchedPart: BasePart): Player?
	local current: Instance? = touchedPart
	while current ~= nil and current ~= Workspace do
		if current:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(current)
			if player ~= nil then
				return player
			end
		end

		current = current.Parent
	end

	return nil
end

local function findTouchPart(definition: ShopDefinition): BasePart?
	local model = Workspace:FindFirstChild(definition.worldModelName)
	if model == nil then
		warn(string.format("[ShopService] Missing Workspace.%s.", definition.worldModelName))
		return nil
	end

	if not model:IsA("Model") then
		warn(string.format("[ShopService] Workspace.%s must be a Model.", definition.worldModelName))
		return nil
	end

	local touchPart = model:FindFirstChild(definition.touchPartName)
	if touchPart == nil then
		warn(string.format("[ShopService] Missing %s.%s.", model:GetFullName(), definition.touchPartName))
		return nil
	end

	if not touchPart:IsA("BasePart") then
		warn(string.format("[ShopService] %s must be a BasePart.", touchPart:GetFullName()))
		return nil
	end

	return touchPart
end

local function openShopForPlayer(player: Player, shopId: ShopId)
	local currentTime = getCurrentTime()
	if not canOpenShopForPlayer(player, shopId, currentTime) then
		return
	end

	Remotes.getShopRemotes().shopOpened:FireClient(player, {
		shopId = shopId,
		snapshot = buildSnapshot(player),
	})
end

local function isPlayerCloseEnoughToShop(player: Player, definition: ShopDefinition): boolean
	local character = player.Character
	if character == nil then
		return false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return false
	end

	local touchPart = findTouchPart(definition)
	if touchPart == nil then
		return false
	end

	return (rootPart.Position - touchPart.Position).Magnitude <= MAX_PURCHASE_DISTANCE_STUDS
end

local function createPurchaseResult(
	player: Player,
	success: boolean,
	status: ShopPurchaseStatus,
	shopId: ShopId?,
	productId: ShopProductId?
): ShopPurchaseResult
	return {
		success = success,
		status = status,
		shopId = shopId,
		productId = productId,
		snapshot = buildSnapshot(player),
	}
end

local function getStockRemaining(player: Player, shopId: ShopId, productDefinition: ShopProductDefinition): number
	local shopDefinition = ShopCatalog.getShopDefinition(shopId)
	getNormalizedNextRestockAt(player, shopDefinition, getCurrentTime())

	local stockState = getShopStockState(player, shopId)
	return stockState[productDefinition.id] or 0
end

local function decrementStock(player: Player, shopId: ShopId, productDefinition: ShopProductDefinition)
	local stockState = getShopStockState(player, shopId)
	stockState[productDefinition.id] = math.max(0, (stockState[productDefinition.id] or 0) - 1)
end

local function handlePurchaseRequest(player: Player, request: unknown): ShopPurchaseResult
	if type(request) ~= "table" then
		return createPurchaseResult(player, false, "InvalidShop", nil, nil)
	end

	local requestValues = request :: { [string]: unknown }
	local rawShopId = requestValues.shopId
	if type(rawShopId) ~= "string" or not ShopCatalog.isShopId(rawShopId) then
		return createPurchaseResult(player, false, "InvalidShop", nil, nil)
	end

	local shopId = rawShopId :: ShopId
	local rawProductId = requestValues.productId
	if type(rawProductId) ~= "string" then
		return createPurchaseResult(player, false, "InvalidProduct", shopId, nil)
	end

	local productId = rawProductId :: ShopProductId
	local productDefinition = ShopCatalog.getShopProductDefinition(shopId, productId)
	if productDefinition == nil then
		return createPurchaseResult(player, false, "InvalidProduct", shopId, productId)
	end

	local shopDefinition = ShopCatalog.getShopDefinition(shopId)
	if not isPlayerCloseEnoughToShop(player, shopDefinition) then
		return createPurchaseResult(player, false, "TooFar", shopId, productId)
	end

	if productDefinition.quantityPerPurchase <= 0 then
		return createPurchaseResult(player, false, "InvalidQuantity", shopId, productId)
	end

	if PlayerDataService.getLifetimeCashEarned(player) < productDefinition.unlockLifetimeCash then
		return createPurchaseResult(player, false, "Locked", shopId, productId)
	end

	if getStockRemaining(player, shopId, productDefinition) <= 0 then
		return createPurchaseResult(player, false, "OutOfStock", shopId, productId)
	end

	if not EconomyService.trySpendCash(player, productDefinition.price) then
		return createPurchaseResult(player, false, "InsufficientCash", shopId, productId)
	end

	decrementStock(player, shopId, productDefinition)
	InventoryService.addItem(player, productDefinition.itemId, productDefinition.quantityPerPurchase)

	return createPurchaseResult(player, true, "Purchased", shopId, productId)
end

local function connectShopTouch(definition: ShopDefinition)
	local touchPart = findTouchPart(definition)
	if touchPart == nil then
		return
	end

	touchPart.Touched:Connect(function(touchedPart: BasePart)
		local player = findPlayerFromTouchedPart(touchedPart)
		if player == nil then
			return
		end

		openShopForPlayer(player, definition.id)
	end)
end

local ShopService = {}

function ShopService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local shopRemotes = Remotes.getShopRemotes()
	shopRemotes.getShopSnapshot.OnServerInvoke = function(player: Player): ShopSnapshot
		return buildSnapshot(player)
	end
	shopRemotes.requestShopPurchase.OnServerInvoke = handlePurchaseRequest

	for _, shopId in ipairs(ShopCatalog.getShopIds()) do
		connectShopTouch(ShopCatalog.getShopDefinition(shopId))
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		nextRestockAtByPlayer[player] = nil
		stockRemainingByPlayer[player] = nil
		nextAllowedOpenAtByPlayer[player] = nil
	end)
end

return table.freeze(ShopService)

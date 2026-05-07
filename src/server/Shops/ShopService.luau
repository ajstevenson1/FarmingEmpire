--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local shopsFolder = sharedFolder:WaitForChild("Shops") :: Folder

local ShopCatalog = require(shopsFolder:WaitForChild("ShopCatalog") :: ModuleScript)
local ShopTypes = require(shopsFolder:WaitForChild("ShopTypes") :: ModuleScript)
local Remotes = require(script.Parent.Parent.Networking.Remotes)

type ShopDefinition = ShopTypes.ShopDefinition
type ShopId = ShopTypes.ShopId
type ShopRestockState = ShopTypes.ShopRestockState
type ShopSnapshot = ShopTypes.ShopSnapshot

local TOUCH_OPEN_DEBOUNCE_SECONDS = 1

local hasStarted = false
local nextRestockAtByPlayer: { [Player]: { [ShopId]: number } } = {}
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

local function getNormalizedNextRestockAt(player: Player, definition: ShopDefinition, currentTime: number): number
	local playerState = getPlayerRestockState(player)
	local nextRestockAt = playerState[definition.id]
	if nextRestockAt == nil then
		nextRestockAt = currentTime + definition.restockIntervalSeconds
	end

	while nextRestockAt <= currentTime do
		nextRestockAt += definition.restockIntervalSeconds
	end

	playerState[definition.id] = nextRestockAt
	return nextRestockAt
end

local function buildSnapshot(player: Player): ShopSnapshot
	local currentTime = getCurrentTime()
	local shopsById: { [ShopId]: ShopRestockState } = {}

	for _, shopId in ipairs(ShopCatalog.getShopIds()) do
		local definition = ShopCatalog.getShopDefinition(shopId)
		shopsById[shopId] = {
			nextRestockAt = getNormalizedNextRestockAt(player, definition, currentTime),
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

	for _, shopId in ipairs(ShopCatalog.getShopIds()) do
		connectShopTouch(ShopCatalog.getShopDefinition(shopId))
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		nextRestockAtByPlayer[player] = nil
		nextAllowedOpenAtByPlayer[player] = nil
	end)
end

return table.freeze(ShopService)

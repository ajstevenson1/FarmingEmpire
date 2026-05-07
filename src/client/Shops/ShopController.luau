--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local shopsFolder = sharedFolder:WaitForChild("Shops") :: Folder

local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local ShopCatalog = require(shopsFolder:WaitForChild("ShopCatalog") :: ModuleScript)
local ShopTypes = require(shopsFolder:WaitForChild("ShopTypes") :: ModuleScript)
local FrameManager = require(script.Parent.Parent.UI.FrameManager)
local ShopMenuView = require(script.Parent.ShopMenuView)

type ShopId = ShopTypes.ShopId
type ShopOpenedPayload = ShopTypes.ShopOpenedPayload
type ShopSnapshot = ShopTypes.ShopSnapshot
type ShopMenuViewInstance = ShopMenuView.ShopMenuView

local SHOP_FRAME_ID = "ShopMenu"
local MENU_FRAME_GROUP = "Menu"
local hasStarted = false
local activeShopId: ShopId? = nil
local latestSnapshot: ShopSnapshot? = nil

local function getShopRemotes(): (RemoteEvent, RemoteFunction)
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local shopFolder = rootFolder:WaitForChild(RemoteNames.shopFolderName) :: Folder
	local shopOpened = shopFolder:WaitForChild(RemoteNames.shopOpenedEventName) :: RemoteEvent
	local getShopSnapshot = shopFolder:WaitForChild(RemoteNames.getShopSnapshotFunctionName) :: RemoteFunction
	return shopOpened, getShopSnapshot
end

local function getClosedPanelPosition(panel: Frame): UDim2
	return UDim2.new(panel.Position.X.Scale, panel.Position.X.Offset, 1, 180)
end

local function getSecondsUntilRestock(snapshot: ShopSnapshot, shopId: ShopId): number
	local state = snapshot.shopsById[shopId]
	if state == nil then
		return 0
	end

	return math.max(0, math.ceil(state.nextRestockAt - Workspace:GetServerTimeNow()))
end

local function advanceRestockIfNeeded(snapshot: ShopSnapshot)
	local currentTime = Workspace:GetServerTimeNow()
	for _, shopId in ipairs(ShopCatalog.getShopIds()) do
		local state = snapshot.shopsById[shopId]
		if state == nil then
			continue
		end

		local definition = ShopCatalog.getShopDefinition(shopId)
		while state.nextRestockAt <= currentTime do
			state.nextRestockAt += definition.restockIntervalSeconds
		end
	end
end

local function renderIfReady(view: ShopMenuViewInstance)
	local shopId = activeShopId
	local snapshot = latestSnapshot
	if shopId == nil or snapshot == nil then
		return
	end

	advanceRestockIfNeeded(snapshot)

	local definition = ShopCatalog.getShopDefinition(shopId)
	view:render(definition.displayName, getSecondsUntilRestock(snapshot, shopId))
end

local ShopController = {}

function ShopController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local view = ShopMenuView.new()
	local panel = view:getFrame()
	FrameManager.registerFrame({
		id = SHOP_FRAME_ID,
		frame = panel,
		group = MENU_FRAME_GROUP,
		defaultOpen = false,
		closedPosition = getClosedPanelPosition(panel),
	})

	local shopOpened, getShopSnapshot = getShopRemotes()
	latestSnapshot = getShopSnapshot:InvokeServer() :: ShopSnapshot

	view:connectCloseRequested(function()
		FrameManager.close(SHOP_FRAME_ID)
	end)

	shopOpened.OnClientEvent:Connect(function(payload: ShopOpenedPayload)
		activeShopId = payload.shopId
		latestSnapshot = payload.snapshot
		renderIfReady(view)
		FrameManager.open(SHOP_FRAME_ID)
	end)

	task.spawn(function()
		while true do
			renderIfReady(view)
			task.wait(1)
		end
	end)
end

function ShopController.getLatestSnapshot(): ShopSnapshot?
	return latestSnapshot
end

return table.freeze(ShopController)

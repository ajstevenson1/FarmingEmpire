--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local shopsFolder = sharedFolder:WaitForChild("Shops") :: Folder

local ShopCatalog = require(shopsFolder:WaitForChild("ShopCatalog") :: ModuleScript)
local ShopTypes = require(shopsFolder:WaitForChild("ShopTypes") :: ModuleScript)
local ShopController = require(script.Parent.ShopController)

type ShopDefinition = ShopTypes.ShopDefinition
type ShopId = ShopTypes.ShopId
type ShopSnapshot = ShopTypes.ShopSnapshot

type WorldShopWidgets = {
	nameLabel: TextLabel,
	timerLabel: TextLabel,
}

local hasStarted = false
local widgetsByShopId: { [ShopId]: WorldShopWidgets } = {}

local function formatSeconds(totalSeconds: number): string
	local minutes = math.floor(totalSeconds / 60)
	local seconds = totalSeconds % 60
	return string.format("%02d:%02d", minutes, seconds)
end

local function getTextLabel(parent: Instance, labelName: string): TextLabel?
	local label = parent:FindFirstChild(labelName, true)
	if label == nil then
		return nil
	end

	if not label:IsA("TextLabel") then
		warn(string.format("[WorldShopTimerController] %s must be a TextLabel.", label:GetFullName()))
		return nil
	end

	return label
end

local function findWidgets(definition: ShopDefinition): WorldShopWidgets?
	local model = Workspace:FindFirstChild(definition.worldModelName)
	if model == nil then
		warn(string.format("[WorldShopTimerController] Missing Workspace.%s.", definition.worldModelName))
		return nil
	end

	local restockGui = model:FindFirstChild(definition.restockGuiName, true)
	if restockGui == nil then
		warn(string.format("[WorldShopTimerController] Missing %s.%s.", model:GetFullName(), definition.restockGuiName))
		return nil
	end

	local nameLabel = getTextLabel(restockGui, definition.nameLabelName)
	local timerLabel = getTextLabel(restockGui, definition.timerLabelName)
	if nameLabel == nil or timerLabel == nil then
		return nil
	end

	nameLabel.Text = definition.displayName

	return {
		nameLabel = nameLabel,
		timerLabel = timerLabel,
	}
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

local function getSecondsUntilRestock(snapshot: ShopSnapshot, shopId: ShopId): number
	local state = snapshot.shopsById[shopId]
	if state == nil then
		return 0
	end

	return math.max(0, math.ceil(state.nextRestockAt - Workspace:GetServerTimeNow()))
end

local function registerWorldShopWidgets()
	for _, shopId in ipairs(ShopCatalog.getShopIds()) do
		local definition = ShopCatalog.getShopDefinition(shopId)
		local widgets = findWidgets(definition)
		if widgets ~= nil then
			widgetsByShopId[shopId] = widgets
		end
	end
end

local function render()
	local snapshot = ShopController.getLatestSnapshot()
	if snapshot == nil then
		for _, widgets in pairs(widgetsByShopId) do
			widgets.timerLabel.Text = "Restock: --:--"
		end
		return
	end

	advanceRestockIfNeeded(snapshot)

	for shopId, widgets in pairs(widgetsByShopId) do
		widgets.timerLabel.Text = string.format("Restock: %s", formatSeconds(getSecondsUntilRestock(snapshot, shopId)))
	end
end

local WorldShopTimerController = {}

function WorldShopTimerController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	registerWorldShopWidgets()
	render()

	task.spawn(function()
		while true do
			render()
			task.wait(1)
		end
	end)
end

return table.freeze(WorldShopTimerController)

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local economyFolder = sharedFolder:WaitForChild("Economy") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder

local EconomyTypes = require(economyFolder:WaitForChild("EconomyTypes") :: ModuleScript)
local MarketPriceRank = require(economyFolder:WaitForChild("MarketPriceRank") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)

type MarketSnapshot = EconomyTypes.MarketSnapshot

type WorldCiderMarketWidgets = {
	nameLabel: TextLabel,
	timerLabel: TextLabel,
}

local CIDER_SELL_MODEL_NAME = "CiderSell"
local RESTOCK_GUI_NAME = "RestockGUI"
local NAME_LABEL_NAME = "NameLabel"
local TIMER_LABEL_NAME = "TimerLabel"

local hasStarted = false
local widgets: WorldCiderMarketWidgets? = nil
local latestMarketSnapshot: MarketSnapshot? = nil

local function formatSeconds(totalSeconds: number): string
	local minutes = math.floor(totalSeconds / 60)
	local seconds = totalSeconds % 60
	return string.format("%02d:%02d", minutes, seconds)
end

local function getMarketRemotes(): (RemoteEvent, RemoteFunction)
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local marketFolder = rootFolder:WaitForChild(RemoteNames.marketFolderName) :: Folder
	local marketUpdated = marketFolder:WaitForChild(RemoteNames.marketUpdatedEventName) :: RemoteEvent
	local getMarketSnapshot = marketFolder:WaitForChild(RemoteNames.getMarketSnapshotFunctionName) :: RemoteFunction
	return marketUpdated, getMarketSnapshot
end

local function getTextLabel(parent: Instance, labelName: string): TextLabel?
	local label = parent:FindFirstChild(labelName, true)
	if label == nil then
		return nil
	end

	if not label:IsA("TextLabel") then
		warn(string.format("[WorldCiderMarketController] %s must be a TextLabel.", label:GetFullName()))
		return nil
	end

	return label
end

local function findWidgets(): WorldCiderMarketWidgets?
	local model = Workspace:FindFirstChild(CIDER_SELL_MODEL_NAME)
	if model == nil then
		warn(string.format("[WorldCiderMarketController] Missing Workspace.%s.", CIDER_SELL_MODEL_NAME))
		return nil
	end

	local restockGui = model:FindFirstChild(RESTOCK_GUI_NAME, true)
	if restockGui == nil then
		warn(string.format("[WorldCiderMarketController] Missing %s.%s.", model:GetFullName(), RESTOCK_GUI_NAME))
		return nil
	end

	local nameLabel = getTextLabel(restockGui, NAME_LABEL_NAME)
	local timerLabel = getTextLabel(restockGui, TIMER_LABEL_NAME)
	if nameLabel == nil or timerLabel == nil then
		return nil
	end

	nameLabel.Text = "Cider Market"

	return {
		nameLabel = nameLabel,
		timerLabel = timerLabel,
	}
end

local function getSecondsUntilPriceChange(snapshot: MarketSnapshot): number
	return math.max(0, math.ceil(snapshot.nextPriceChangeAt - Workspace:GetServerTimeNow()))
end

local function render()
	local currentWidgets = widgets
	if currentWidgets == nil then
		return
	end

	local marketSnapshot = latestMarketSnapshot
	if marketSnapshot == nil then
		currentWidgets.timerLabel.Text = "$-- / cider | --:--"
		return
	end

	currentWidgets.timerLabel.Text = string.format(
		"$%d / cider | %s | %s",
		marketSnapshot.ciderSellPrice,
		MarketPriceRank.getCiderPriceRank(marketSnapshot.ciderSellPrice).displayName,
		formatSeconds(getSecondsUntilPriceChange(marketSnapshot))
	)
end

local WorldCiderMarketController = {}

function WorldCiderMarketController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	widgets = findWidgets()

	local marketUpdated, getMarketSnapshot = getMarketRemotes()
	latestMarketSnapshot = getMarketSnapshot:InvokeServer() :: MarketSnapshot
	render()

	marketUpdated.OnClientEvent:Connect(function(marketSnapshot: MarketSnapshot)
		latestMarketSnapshot = marketSnapshot
		render()
	end)

	task.spawn(function()
		while true do
			render()
			task.wait(1)
		end
	end)
end

return table.freeze(WorldCiderMarketController)

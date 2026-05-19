--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local plotsFolder = sharedFolder:WaitForChild("Plots") :: Folder

local PlotLocator = require(plotsFolder:WaitForChild("PlotLocator") :: ModuleScript)
local PlotOwnerBillboardView = require(script.Parent.PlotOwnerBillboardView)

type PlotOwnerBillboardViewInstance = PlotOwnerBillboardView.PlotOwnerBillboardView

type TrackedPlotConnections = {
	ownerUserIdChanged: RBXScriptConnection,
	ownerPlayerNameChanged: RBXScriptConnection,
	ancestryChanged: RBXScriptConnection,
}

local trackedViewsByPlot: { [Instance]: PlotOwnerBillboardViewInstance } = {}
local trackedConnectionsByPlot: { [Instance]: TrackedPlotConnections } = {}
local hasStarted = false

local function getWorkspacePlotsFolder(): Folder
	local folder = Workspace:WaitForChild(PlotLocator.PLOTS_FOLDER_NAME)
	assert(folder:IsA("Folder"), string.format("Workspace.%s must be a Folder", PlotLocator.PLOTS_FOLDER_NAME))
	return folder
end

local function disconnectTrackedPlot(plot: Instance)
	local trackedConnections = trackedConnectionsByPlot[plot]
	if trackedConnections ~= nil then
		trackedConnections.ownerUserIdChanged:Disconnect()
		trackedConnections.ownerPlayerNameChanged:Disconnect()
		trackedConnections.ancestryChanged:Disconnect()
		trackedConnectionsByPlot[plot] = nil
	end

	local trackedView = trackedViewsByPlot[plot]
	if trackedView ~= nil then
		trackedView:destroy()
		trackedViewsByPlot[plot] = nil
	end
end

local function trackPlot(plot: Instance)
	if trackedViewsByPlot[plot] ~= nil then
		return
	end

	local view = PlotOwnerBillboardView.new(plot)
	trackedViewsByPlot[plot] = view

	trackedConnectionsByPlot[plot] = {
		ownerUserIdChanged = plot:GetAttributeChangedSignal(PlotLocator.Attributes.ownerUserId):Connect(function()
			view:refresh()
		end),
		ownerPlayerNameChanged = plot:GetAttributeChangedSignal(PlotLocator.Attributes.ownerPlayerName):Connect(function()
			view:refresh()
		end),
		ancestryChanged = plot.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				disconnectTrackedPlot(plot)
			end
		end),
	}

	task.defer(function()
		local activeView = trackedViewsByPlot[plot]
		if activeView == view then
			activeView:refresh()
		end
	end)
end

local PlotOwnerBillboardController = {}

function PlotOwnerBillboardController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local workspacePlotsFolder = getWorkspacePlotsFolder()

	for _, plot in ipairs(PlotLocator.getAllPlots(workspacePlotsFolder)) do
		trackPlot(plot)
	end

	workspacePlotsFolder.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") or child:IsA("Model") then
			trackPlot(child)
		end
	end)

	workspacePlotsFolder.ChildRemoved:Connect(function(child)
		disconnectTrackedPlot(child)
	end)
end

return table.freeze(PlotOwnerBillboardController)

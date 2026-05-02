--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PLOTS_FOLDER_NAME = "Plots"
local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
local OWNER_PLAYER_NAME_ATTRIBUTE = "OwnerPlayerName"

local plotsFolder = Workspace:WaitForChild(PLOTS_FOLDER_NAME) :: Folder

local assignedPlotsByPlayer: { [Player]: BasePart } = {}
local hasStarted = false

local function getAllPlots(): { BasePart }
	local plots: { BasePart } = {}

	for _, child in ipairs(plotsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(plots, child)
		end
	end

	table.sort(plots, function(leftPlot, rightPlot)
		return leftPlot.Name < rightPlot.Name
	end)

	return plots
end

local function isPlotClaimed(plot: BasePart): boolean
	local ownerUserId = plot:GetAttribute(OWNER_USER_ID_ATTRIBUTE)
	return type(ownerUserId) == "number" and ownerUserId > 0
end

local function setPlotOwner(plot: BasePart, player: Player?)
	if player == nil then
		plot:SetAttribute(OWNER_USER_ID_ATTRIBUTE, nil)
		plot:SetAttribute(OWNER_PLAYER_NAME_ATTRIBUTE, nil)
		return
	end

	plot:SetAttribute(OWNER_USER_ID_ATTRIBUTE, player.UserId)
	plot:SetAttribute(OWNER_PLAYER_NAME_ATTRIBUTE, player.Name)
end

local function assignPlot(player: Player)
	if assignedPlotsByPlayer[player] ~= nil then
		return
	end

	for _, plot in ipairs(getAllPlots()) do
		if not isPlotClaimed(plot) then
			assignedPlotsByPlayer[player] = plot
			setPlotOwner(plot, player)
			return
		end
	end
end

local function releasePlot(player: Player)
	local plot = assignedPlotsByPlayer[player]
	if plot == nil then
		return
	end

	if plot.Parent ~= nil then
		setPlotOwner(plot, nil)
	end

	assignedPlotsByPlayer[player] = nil
end

local PlotService = {}

function PlotService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	Players.PlayerAdded:Connect(assignPlot)
	Players.PlayerRemoving:Connect(releasePlot)

	for _, player in ipairs(Players:GetPlayers()) do
		assignPlot(player)
	end
end

function PlotService.getAssignedPlot(player: Player): BasePart?
	return assignedPlotsByPlayer[player]
end

function PlotService.waitForAssignedPlot(player: Player, timeoutSeconds: number?): BasePart?
	local startedAt = os.clock()

	while player.Parent ~= nil do
		local plot = assignedPlotsByPlayer[player]
		if plot ~= nil then
			return plot
		end

		if timeoutSeconds ~= nil and os.clock() - startedAt >= timeoutSeconds then
			return nil
		end

		task.wait()
	end

	return nil
end

function PlotService.getAssignedPlotName(player: Player): string?
	local plot = assignedPlotsByPlayer[player]
	if plot == nil then
		return nil
	end

	return plot.Name
end

return table.freeze(PlotService)

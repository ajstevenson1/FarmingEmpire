--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local plotsCodeFolder = sharedFolder:WaitForChild("Plots") :: Folder

local PlotLocator = require(plotsCodeFolder:WaitForChild("PlotLocator") :: ModuleScript)

local PLOTS_FOLDER_NAME = PlotLocator.PLOTS_FOLDER_NAME
local MAX_SUPPORTED_PLOTS = PlotLocator.MAX_SUPPORTED_PLOTS
local OWNER_USER_ID_ATTRIBUTE = PlotLocator.Attributes.ownerUserId
local OWNER_PLAYER_NAME_ATTRIBUTE = PlotLocator.Attributes.ownerPlayerName
local SLOT_ATTRIBUTE = PlotLocator.Attributes.slot
local PLAYER_PLOT_SLOT_ATTRIBUTE = PlotLocator.PlayerAttributes.plotSlot
local PLAYER_ASSIGNED_PLOT_NAME_ATTRIBUTE = PlotLocator.PlayerAttributes.assignedPlotName
local SPAWN_OFFSET = CFrame.new(0, 3, 0)
local CHARACTER_ROOT_PART_NAME = "HumanoidRootPart"
local CHARACTER_ROOT_WAIT_SECONDS = 10

local plotsFolder = Workspace:WaitForChild(PLOTS_FOLDER_NAME) :: Folder

local assignedPlotsByPlayer: { [Player]: Instance } = {}
local characterAddedConnectionsByPlayer: { [Player]: RBXScriptConnection } = {}
local hasStarted = false

local function isSupportedSlot(slot: number?): boolean
	return slot ~= nil and slot >= 1 and slot <= MAX_SUPPORTED_PLOTS and slot == math.floor(slot)
end

local function getNextOpenSlot(usedSlots: { [number]: boolean }): number?
	for slot = 1, MAX_SUPPORTED_PLOTS do
		if usedSlots[slot] ~= true then
			return slot
		end
	end

	return nil
end

local function clearPlotOwner(plot: Instance)
	plot:SetAttribute(OWNER_USER_ID_ATTRIBUTE, nil)
	plot:SetAttribute(OWNER_PLAYER_NAME_ATTRIBUTE, nil)
end

local function setPlotOwner(plot: Instance, player: Player?)
	if player == nil then
		clearPlotOwner(plot)
		return
	end

	plot:SetAttribute(OWNER_USER_ID_ATTRIBUTE, player.UserId)
	plot:SetAttribute(OWNER_PLAYER_NAME_ATTRIBUTE, player.Name)
end

local function setupPlotSlots()
	local usedSlots: { [number]: boolean } = {}
	local managedPlotCount = 0

	for _, plot in ipairs(PlotLocator.getAllPlots(plotsFolder)) do
		if PlotLocator.getPlacementBase(plot) == nil then
			warn(string.format("[PlotService] Plot %s has no placement base and cannot be assigned.", plot:GetFullName()))
			continue
		end

		local rawSlot = PlotLocator.getSlot(plot)
		local slot: number? = nil
		if rawSlot ~= nil and isSupportedSlot(rawSlot) and usedSlots[rawSlot] ~= true then
			slot = rawSlot
		else
			slot = getNextOpenSlot(usedSlots)
		end

		if slot == nil then
			warn(string.format("[PlotService] Ignoring extra plot %s because only %d plots are supported.", plot:GetFullName(), MAX_SUPPORTED_PLOTS))
			clearPlotOwner(plot)
			continue
		end

		managedPlotCount += 1
		usedSlots[slot] = true
		plot:SetAttribute(SLOT_ATTRIBUTE, slot)
		clearPlotOwner(plot)
	end

	if managedPlotCount < MAX_SUPPORTED_PLOTS then
		warn(string.format("[PlotService] Expected %d plot slots, but only %d assignable plots were found.", MAX_SUPPORTED_PLOTS, managedPlotCount))
	end
end

local function clearPlayerPlotAttributes(player: Player)
	player:SetAttribute(PLAYER_PLOT_SLOT_ATTRIBUTE, nil)
	player:SetAttribute(PLAYER_ASSIGNED_PLOT_NAME_ATTRIBUTE, nil)
end

local function setPlayerPlotAttributes(player: Player, plot: Instance)
	local slot = PlotLocator.getSlot(plot)
	if slot ~= nil then
		player:SetAttribute(PLAYER_PLOT_SLOT_ATTRIBUTE, slot)
	end

	player:SetAttribute(PLAYER_ASSIGNED_PLOT_NAME_ATTRIBUTE, plot.Name)
end

local function getAssignedPlotForPlayer(player: Player): Instance?
	local assignedPlot = assignedPlotsByPlayer[player]
	if assignedPlot ~= nil and assignedPlot.Parent ~= nil then
		return assignedPlot
	end

	local locatedPlot = PlotLocator.getAssignedPlot(plotsFolder, player)
	if locatedPlot ~= nil then
		assignedPlotsByPlayer[player] = locatedPlot
		return locatedPlot
	end

	return nil
end

local function setRespawnLocation(player: Player, plot: Instance)
	local spawnPart = PlotLocator.getSpawnPart(plot)
	if spawnPart ~= nil and spawnPart:IsA("SpawnLocation") then
		player.RespawnLocation = spawnPart
	else
		player.RespawnLocation = nil
	end
end

local function teleportCharacterToPlotSpawn(player: Player, plot: Instance)
	local spawnPart = PlotLocator.getSpawnPart(plot)
	if spawnPart == nil then
		warn(string.format("[PlotService] Plot %s has no spawn part for %s.", plot:GetFullName(), player.Name))
		return
	end

	setRespawnLocation(player, plot)

	local character = player.Character
	if character == nil then
		return
	end

	local rootPart = character:FindFirstChild(CHARACTER_ROOT_PART_NAME)
	if rootPart == nil then
		rootPart = character:WaitForChild(CHARACTER_ROOT_PART_NAME, CHARACTER_ROOT_WAIT_SECONDS)
	end

	if rootPart == nil or not rootPart:IsA("BasePart") then
		warn(string.format("[PlotService] Could not find %s for %s before plot teleport.", CHARACTER_ROOT_PART_NAME, player.Name))
		return
	end

	character:PivotTo(spawnPart.CFrame * SPAWN_OFFSET)
end

local function assignPlot(player: Player)
	if getAssignedPlotForPlayer(player) ~= nil then
		return
	end

	local plot = PlotLocator.findFirstAvailablePlot(plotsFolder)
	if plot == nil then
		player:Kick("All farm plots are currently taken. Please try another server.")
		return
	end

	assignedPlotsByPlayer[player] = plot
	setPlotOwner(plot, player)
	setPlayerPlotAttributes(player, plot)
	teleportCharacterToPlotSpawn(player, plot)
end

local function releasePlot(player: Player)
	local plot = getAssignedPlotForPlayer(player)
	if plot ~= nil and plot.Parent ~= nil and PlotLocator.isOwnedBy(plot, player) then
		clearPlotOwner(plot)
	end

	player.RespawnLocation = nil
	clearPlayerPlotAttributes(player)
	assignedPlotsByPlayer[player] = nil

	local characterConnection = characterAddedConnectionsByPlayer[player]
	if characterConnection ~= nil then
		characterConnection:Disconnect()
		characterAddedConnectionsByPlayer[player] = nil
	end
end

local function connectPlayer(player: Player)
	characterAddedConnectionsByPlayer[player] = player.CharacterAdded:Connect(function()
		task.defer(function()
			local plot = getAssignedPlotForPlayer(player)
			if plot ~= nil then
				teleportCharacterToPlotSpawn(player, plot)
			end
		end)
	end)

	assignPlot(player)
end

local PlotService = {}

function PlotService.start()
	if hasStarted then
		return
	end

	hasStarted = true
	setupPlotSlots()

	Players.PlayerAdded:Connect(connectPlayer)
	Players.PlayerRemoving:Connect(releasePlot)

	for _, player in ipairs(Players:GetPlayers()) do
		connectPlayer(player)
	end
end

function PlotService.getAssignedPlot(player: Player): Instance?
	return getAssignedPlotForPlayer(player)
end

function PlotService.getAssignedPlotBase(player: Player): BasePart?
	local plot = getAssignedPlotForPlayer(player)
	if plot == nil then
		return nil
	end

	return PlotLocator.getPlacementBase(plot)
end

function PlotService.waitForAssignedPlot(player: Player, timeoutSeconds: number?): Instance?
	local startedAt = os.clock()

	while player.Parent ~= nil do
		local plot = getAssignedPlotForPlayer(player)
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

function PlotService.waitForAssignedPlotBase(player: Player, timeoutSeconds: number?): BasePart?
	local startedAt = os.clock()

	while player.Parent ~= nil do
		local plotBase = PlotService.getAssignedPlotBase(player)
		if plotBase ~= nil then
			return plotBase
		end

		if timeoutSeconds ~= nil and os.clock() - startedAt >= timeoutSeconds then
			return nil
		end

		task.wait()
	end

	return nil
end

function PlotService.getAssignedPlotName(player: Player): string?
	local plot = getAssignedPlotForPlayer(player)
	if plot == nil then
		return nil
	end

	return plot.Name
end

function PlotService.getAssignedSlot(player: Player): number?
	local plot = getAssignedPlotForPlayer(player)
	if plot == nil then
		return nil
	end

	return PlotLocator.getSlot(plot)
end

function PlotService.isAssignedPlot(player: Player, plot: Instance): boolean
	return getAssignedPlotForPlayer(player) == plot
end

function PlotService.isAssignedPlotBase(player: Player, plotBase: BasePart): boolean
	local assignedPlotBase = PlotService.getAssignedPlotBase(player)
	return assignedPlotBase == plotBase
end

return table.freeze(PlotService)

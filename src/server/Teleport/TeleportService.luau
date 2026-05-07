--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local plotsCodeFolder = sharedFolder:WaitForChild("Plots") :: Folder

local PlotLocator = require(plotsCodeFolder:WaitForChild("PlotLocator") :: ModuleScript)
local Remotes = require(script.Parent.Parent.Networking.Remotes)
local PlotService = require(script.Parent.Parent.Plots.PlotService)

type TeleportDestination = "Plot" | "Shop" | "Sell"

local TELEPORT_COOLDOWN_SECONDS = 0.25
local TELEPORT_OFFSET = CFrame.new(0, 3, 0)
local SHOP_TELEPORT_PART_NAME = "ShopTeleport"
local SELL_TELEPORT_PART_NAME = "SellTeleport"

local hasStarted = false
local lastTeleportRequestAtByPlayer: { [Player]: number } = {}

local function parseTeleportDestination(requestedDestination: unknown): TeleportDestination?
	if requestedDestination == "Plot" then
		return "Plot"
	end

	if requestedDestination == "Shop" then
		return "Shop"
	end

	if requestedDestination == "Sell" then
		return "Sell"
	end

	return nil
end

local function findWorkspaceBasePartByName(partName: string): BasePart?
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant.Name == partName and descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function getPlotDestinationPart(player: Player): BasePart?
	local plot = PlotService.getAssignedPlot(player)
	if plot == nil then
		warn(string.format("[TeleportService] %s requested plot teleport before receiving an assigned plot.", player.Name))
		return nil
	end

	local spawnPart = PlotLocator.getSpawnPart(plot)
	if spawnPart == nil then
		warn(string.format("[TeleportService] Assigned plot %s has no spawn part for %s.", plot:GetFullName(), player.Name))
		return nil
	end

	return spawnPart
end

local function getDestinationPart(player: Player, destination: TeleportDestination): BasePart?
	if destination == "Plot" then
		return getPlotDestinationPart(player)
	end

	if destination == "Shop" then
		local shopTeleportPart = findWorkspaceBasePartByName(SHOP_TELEPORT_PART_NAME)
		if shopTeleportPart == nil then
			warn(string.format("[TeleportService] Missing Workspace BasePart named %s.", SHOP_TELEPORT_PART_NAME))
		end

		return shopTeleportPart
	end

	local sellTeleportPart = findWorkspaceBasePartByName(SELL_TELEPORT_PART_NAME)
	if sellTeleportPart == nil then
		warn(string.format("[TeleportService] Missing Workspace BasePart named %s.", SELL_TELEPORT_PART_NAME))
	end

	return sellTeleportPart
end

local function isOnCooldown(player: Player, currentTime: number): boolean
	local lastRequestAt = lastTeleportRequestAtByPlayer[player]
	return lastRequestAt ~= nil and currentTime - lastRequestAt < TELEPORT_COOLDOWN_SECONDS
end

local function handleTeleportRequest(player: Player, requestedDestination: unknown)
	local destination = parseTeleportDestination(requestedDestination)
	if destination == nil then
		return
	end

	local currentTime = os.clock()
	if isOnCooldown(player, currentTime) then
		return
	end

	lastTeleportRequestAtByPlayer[player] = currentTime

	local destinationPart = getDestinationPart(player, destination)
	if destinationPart == nil then
		return
	end

	local character = player.Character
	if character == nil then
		return
	end

	character:PivotTo(destinationPart.CFrame * TELEPORT_OFFSET)
end

local TeleportService = {}

function TeleportService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	Remotes.getTeleportRemotes().requestTeleport.OnServerEvent:Connect(handleTeleportRequest)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastTeleportRequestAtByPlayer[player] = nil
	end)
end

return table.freeze(TeleportService)

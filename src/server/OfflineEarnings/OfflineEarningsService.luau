--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local formattingFolder = sharedFolder:WaitForChild("Formatting") :: Folder
local offlineEarningsFolder = sharedFolder:WaitForChild("OfflineEarnings") :: Folder
local plotsFolder = sharedFolder:WaitForChild("Plots") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local NumberFormatter = require(formattingFolder:WaitForChild("NumberFormatter") :: ModuleScript)
local OfflineCiderRateCalculator = require(offlineEarningsFolder:WaitForChild("OfflineCiderRateCalculator") :: ModuleScript)
local OfflineEarningsConfig = require(offlineEarningsFolder:WaitForChild("OfflineEarningsConfig") :: ModuleScript)
local PlotLocator = require(plotsFolder:WaitForChild("PlotLocator") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)
local PlotExpansionService = require(script.Parent.Parent.Plots.PlotExpansionService)
local PlotService = require(script.Parent.Parent.Plots.PlotService)
local ResourceService = require(script.Parent.Parent.Resources.ResourceService)

type OfflineRateBuilding = OfflineCiderRateCalculator.OfflineRateBuilding
type ResourceUpdateContext = ResourceTypes.ResourceUpdateContext

local CIDER_RESOURCE_ID = "Cider"
local CHARACTER_ROOT_NAME = "HumanoidRootPart"
local CLAIM_DEBOUNCE_SECONDS = 1
local OWNER_USER_ID_ATTRIBUTE = PlotLocator.Attributes.ownerUserId
local OFFLINE_EARNINGS_CLAIM_CONTEXT: ResourceUpdateContext = table.freeze({
	reason = "OfflineEarningsClaim",
})

local workspacePlotsFolder = Workspace:WaitForChild(PlotLocator.PLOTS_FOLDER_NAME) :: Folder
local nextAllowedClaimAtByPlayer: { [Player]: number } = {}
local hasStarted = false

local function sanitizeTimestamp(timestamp: number): number
	if timestamp ~= timestamp or timestamp == math.huge or timestamp == -math.huge or timestamp < 0 then
		return 0
	end

	return math.floor(timestamp)
end

local function getCurrentUnixTime(): number
	return os.time()
end

local function getOfflineSeconds(lastSeenAt: number, currentTime: number): number
	local elapsedSeconds = math.max(0, currentTime - sanitizeTimestamp(lastSeenAt))
	return math.min(elapsedSeconds, OfflineEarningsConfig.maxOfflineSeconds)
end

local function getTextLabel(root: Instance, name: string): TextLabel?
	local label = root:FindFirstChild(name, true)
	if label == nil then
		return nil
	end

	if not label:IsA("TextLabel") then
		warn(string.format("[OfflineEarningsService] %s must be a TextLabel.", label:GetFullName()))
		return nil
	end

	return label
end

local function getPlateGui(plate: Instance): Instance?
	local gui = plate:FindFirstChild(OfflineEarningsConfig.guiName, true)
	if gui == nil then
		warn(string.format("[OfflineEarningsService] Missing %s.%s.", plate:GetFullName(), OfflineEarningsConfig.guiName))
		return nil
	end

	return gui
end

local function findPlateModel(plot: Instance): Instance?
	local plate = plot:FindFirstChild(OfflineEarningsConfig.plateModelName)
	if plate == nil then
		warn(string.format(
			"[OfflineEarningsService] Missing %s.%s.",
			plot:GetFullName(),
			OfflineEarningsConfig.plateModelName
		))
	end

	return plate
end

local function findTouchPart(plot: Instance): BasePart?
	local plate = findPlateModel(plot)
	if plate == nil then
		return nil
	end

	local touchPart = plate:FindFirstChild(OfflineEarningsConfig.touchPartName)
	if touchPart == nil then
		warn(string.format("[OfflineEarningsService] Missing %s.%s.", plate:GetFullName(), OfflineEarningsConfig.touchPartName))
		return nil
	end

	if not touchPart:IsA("BasePart") then
		warn(string.format("[OfflineEarningsService] %s must be a BasePart.", touchPart:GetFullName()))
		return nil
	end

	return touchPart
end

local function getPlayerFromTouchedPart(touchedPart: BasePart): Player?
	local character = touchedPart:FindFirstAncestorOfClass("Model")
	if character == nil then
		return nil
	end

	local rootPart = character:FindFirstChild(CHARACTER_ROOT_NAME)
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function formatPendingCider(pendingCider: number): string
	if pendingCider <= 0 then
		return "Collected!"
	end

	return string.format("+%s Cider", NumberFormatter.formatAbbreviated(pendingCider, {
		decimalPlaces = 1,
		trimTrailingZeros = true,
	}))
end

local function updatePlotDisplay(plot: Instance)
	local plate = findPlateModel(plot)
	if plate == nil then
		return
	end

	local gui = getPlateGui(plate)
	if gui == nil then
		return
	end

	local nameLabel = getTextLabel(gui, OfflineEarningsConfig.nameLabelName)
	if nameLabel ~= nil then
		nameLabel.Text = OfflineEarningsConfig.displayNameText
	end

	local earningsLabel = getTextLabel(gui, OfflineEarningsConfig.earningsLabelName)
	if earningsLabel == nil then
		return
	end

	local ownerUserId = PlotLocator.getOwnerUserId(plot)
	if ownerUserId == nil then
		earningsLabel.Text = "Unclaimed"
		return
	end

	local ownerPlayer = Players:GetPlayerByUserId(ownerUserId)
	if ownerPlayer == nil then
		earningsLabel.Text = "Unclaimed"
		return
	end

	earningsLabel.Text = formatPendingCider(PlayerDataService.getPendingOfflineCider(ownerPlayer))
end

local function updatePlayerPlotDisplay(player: Player)
	local plot = PlotService.getAssignedPlot(player)
	if plot ~= nil then
		updatePlotDisplay(plot)
	end
end

local function getOfflineRateBuildings(player: Player): { OfflineRateBuilding }
	local offlineRateBuildings: { OfflineRateBuilding } = {}

	for _, placedBuilding in ipairs(PlayerDataService.getPlacedBuildings(player)) do
		table.insert(offlineRateBuildings, {
			buildingId = placedBuilding.buildingId,
			rateMultiplier = PlotExpansionService.getOfflineCiderRateMultiplierForPlacedBuilding(
				player,
				placedBuilding.buildingId,
				placedBuilding.gridX,
				placedBuilding.gridZ
			),
		})
	end

	return offlineRateBuildings
end

local function calculateCurrentCiderPerSecond(player: Player): number
	return OfflineCiderRateCalculator.calculateCiderPerSecond(getOfflineRateBuildings(player))
end

local function saveOfflineSnapshotAtTime(player: Player, currentTime: number)
	PlayerDataService.setOfflineCiderPerSecondSnapshot(player, calculateCurrentCiderPerSecond(player))
	PlayerDataService.setOfflineLastSeenAt(player, currentTime)
end

local function saveCurrentOfflineSnapshot(player: Player)
	saveOfflineSnapshotAtTime(player, getCurrentUnixTime())
end

local function getAwardCiderPerSecond(player: Player): number
	return calculateCurrentCiderPerSecond(player)
end

local function initializePlayer(player: Player)
	PlayerDataService.waitForData(player)

	local currentTime = getCurrentUnixTime()
	local offlineData = PlayerDataService.getOfflineData(player)
	if offlineData.lastSeenAt <= 0 then
		saveOfflineSnapshotAtTime(player, currentTime)
		updatePlayerPlotDisplay(player)
		return
	end

	local offlineSeconds = getOfflineSeconds(offlineData.lastSeenAt, currentTime)
	if offlineSeconds >= OfflineEarningsConfig.minOfflineSecondsToReward then
		local ciderPerSecond = getAwardCiderPerSecond(player)
		local earnedCider = OfflineCiderRateCalculator.calculateCiderForSeconds(ciderPerSecond, offlineSeconds)
		if earnedCider > 0 then
			PlayerDataService.addPendingOfflineCider(player, earnedCider)
		end
	end

	saveOfflineSnapshotAtTime(player, currentTime)
	updatePlayerPlotDisplay(player)
end

local function canClaim(player: Player): boolean
	local now = Workspace:GetServerTimeNow()
	local nextAllowedClaimAt = nextAllowedClaimAtByPlayer[player] or 0
	if now < nextAllowedClaimAt then
		return false
	end

	nextAllowedClaimAtByPlayer[player] = now + CLAIM_DEBOUNCE_SECONDS
	return true
end

local function claimPendingCider(player: Player)
	if not canClaim(player) then
		return
	end

	local pendingCider = PlayerDataService.claimPendingOfflineCider(player)
	if pendingCider <= 0 then
		updatePlayerPlotDisplay(player)
		return
	end

	ResourceService.addResourceWithContext(player, CIDER_RESOURCE_ID, pendingCider, OFFLINE_EARNINGS_CLAIM_CONTEXT)
	updatePlayerPlotDisplay(player)
end

local function connectPlot(plot: Instance)
	local touchPart = findTouchPart(plot)
	if touchPart == nil then
		updatePlotDisplay(plot)
		return
	end

	touchPart.Touched:Connect(function(touchedPart: BasePart)
		local player = getPlayerFromTouchedPart(touchedPart)
		if player == nil or not PlotService.isAssignedPlot(player, plot) then
			return
		end

		claimPendingCider(player)
	end)

	plot:GetAttributeChangedSignal(OWNER_USER_ID_ATTRIBUTE):Connect(function()
		updatePlotDisplay(plot)
	end)

	updatePlotDisplay(plot)
end

local function connectExistingPlots()
	for _, plot in ipairs(PlotLocator.getAllPlots(workspacePlotsFolder)) do
		connectPlot(plot)
	end
end

local function cleanupPlayer(player: Player)
	nextAllowedClaimAtByPlayer[player] = nil
end

local OfflineEarningsService = {}

function OfflineEarningsService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	connectExistingPlots()
	PlayerDataService.observeBeforeSave(saveCurrentOfflineSnapshot)
	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(cleanupPlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		initializePlayer(player)
	end
end

return table.freeze(OfflineEarningsService)

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local formattingFolder = sharedFolder:WaitForChild("Formatting") :: Folder
local plotsFolder = sharedFolder:WaitForChild("Plots") :: Folder
local templatesFolder = ReplicatedStorage:WaitForChild("Templates") :: Folder

local NumberFormatter = require(formattingFolder:WaitForChild("NumberFormatter") :: ModuleScript)
local PlotExpansionRules = require(plotsFolder:WaitForChild("PlotExpansionRules") :: ModuleScript)
local PlotExpansionTypes = require(plotsFolder:WaitForChild("PlotExpansionTypes") :: ModuleScript)
local PlotExpansionUtils = require(plotsFolder:WaitForChild("PlotExpansionUtils") :: ModuleScript)
local PlotLocator = require(plotsFolder:WaitForChild("PlotLocator") :: ModuleScript)
local PlotExpansionService = require(script.Parent.PlotExpansionService)
local PlotService = require(script.Parent.PlotService)

type PlotModifierId = PlotExpansionTypes.PlotModifierId
type PlotTileSnapshot = PlotExpansionTypes.PlotTileSnapshot
type LockedAreaBillboardWidgets = {
	rootGui: BillboardGui,
	costLabel: TextLabel,
	multiplierLabel: TextLabel,
}

local PROMPT_FOLDER_NAME = "PlotExpansionPrompts"
local PROMPT_PART_PREFIX = "TilePrompt"
local PROMPT_PART_SIZE = Vector3.new(4, 4, 4)
local PROMPT_HEIGHT_OFFSET = 3.25
local PROMPT_MAX_ACTIVATION_DISTANCE = 10
local OWNER_USER_ID_ATTRIBUTE = PlotLocator.Attributes.ownerUserId
local TILE_ROW_ATTRIBUTE = "PlotExpansionRow"
local TILE_COLUMN_ATTRIBUTE = "PlotExpansionColumn"
local LOCKED_AREA_TEMPLATE_NAME = "LockedArea"
local LOCKED_AREA_BILLBOARD_NAME = "LockedAreaBillboard"
local COST_LABEL_NAME = "Cost"
local MULTIPLIER_LABEL_NAME = "Multiplier"
local LOCKED_RICH_TEXT = '<font color="#FF2B2B">Locked</font>'

local workspacePlotsFolder = Workspace:WaitForChild(PlotLocator.PLOTS_FOLDER_NAME) :: Folder
local hasStarted = false

local function getOrCreatePromptFolder(plot: Instance): Folder
	local existingFolder = plot:FindFirstChild(PROMPT_FOLDER_NAME)
	if existingFolder ~= nil then
		assert(existingFolder:IsA("Folder"), string.format("%s must be a Folder", existingFolder:GetFullName()))
		return existingFolder
	end

	local folder = Instance.new("Folder")
	folder.Name = PROMPT_FOLDER_NAME
	folder.Parent = plot
	return folder
end

local function clearPlotPromptFolder(plot: Instance)
	local existingFolder = plot:FindFirstChild(PROMPT_FOLDER_NAME)
	if existingFolder ~= nil then
		existingFolder:Destroy()
	end
end

local function getPromptPartName(row: number, column: number): string
	return string.format("%s_%d_%d", PROMPT_PART_PREFIX, row, column)
end

local function getModifierMultiplierText(modifierId: PlotModifierId?): string?
	local multiplier = PlotExpansionRules.getProductionMultiplier(modifierId)
	if multiplier <= 1 then
		return nil
	end

	return string.format("%dx", multiplier)
end

local function getPromptObjectText(tileSnapshot: PlotTileSnapshot): string
	local modifierMultiplierText = getModifierMultiplierText(tileSnapshot.modifierId)
	if modifierMultiplierText ~= nil then
		return string.format("%s Production", modifierMultiplierText)
	end

	return string.format("Plot Tile %d-%d", tileSnapshot.row, tileSnapshot.column)
end

local function getFormattedPriceText(price: number): string
	return NumberFormatter.formatAbbreviated(price, {
		decimalPlaces = 1,
		trimTrailingZeros = true,
	})
end

local function getPromptActionText(tileSnapshot: PlotTileSnapshot): string
	return string.format("Unlock $%s", getFormattedPriceText(tileSnapshot.price))
end

local function getCostText(tileSnapshot: PlotTileSnapshot): string
	return string.format("%s ($%s)", LOCKED_RICH_TEXT, getFormattedPriceText(tileSnapshot.price))
end

local function createLockedAreaBillboardWidgets(promptPart: BasePart): LockedAreaBillboardWidgets
	local template = templatesFolder:WaitForChild(LOCKED_AREA_TEMPLATE_NAME)
	assert(
		template:IsA("BillboardGui"),
		string.format("Templates.%s must be a BillboardGui", LOCKED_AREA_TEMPLATE_NAME)
	)

	local rootGui = template:Clone() :: BillboardGui
	rootGui.Name = LOCKED_AREA_BILLBOARD_NAME
	rootGui.Adornee = promptPart
	rootGui.Parent = promptPart

	local costLabelInstance = rootGui:FindFirstChild(COST_LABEL_NAME, true)
	assert(
		costLabelInstance ~= nil and costLabelInstance:IsA("TextLabel"),
		string.format("Templates.%s must contain a TextLabel named %s", LOCKED_AREA_TEMPLATE_NAME, COST_LABEL_NAME)
	)

	local multiplierLabelInstance = rootGui:FindFirstChild(MULTIPLIER_LABEL_NAME, true)
	assert(
		multiplierLabelInstance ~= nil and multiplierLabelInstance:IsA("TextLabel"),
		string.format(
			"Templates.%s must contain a TextLabel named %s",
			LOCKED_AREA_TEMPLATE_NAME,
			MULTIPLIER_LABEL_NAME
		)
	)

	local costLabel = costLabelInstance :: TextLabel
	local multiplierLabel = multiplierLabelInstance :: TextLabel

	return {
		rootGui = rootGui,
		costLabel = costLabel,
		multiplierLabel = multiplierLabel,
	}
end

local function getOrCreateLockedAreaBillboardWidgets(promptPart: BasePart): LockedAreaBillboardWidgets
	local existingBillboard = promptPart:FindFirstChild(LOCKED_AREA_BILLBOARD_NAME)
	if existingBillboard ~= nil then
		if not existingBillboard:IsA("BillboardGui") then
			existingBillboard:Destroy()
		else
			local costLabelInstance = existingBillboard:FindFirstChild(COST_LABEL_NAME, true)
			local multiplierLabelInstance = existingBillboard:FindFirstChild(MULTIPLIER_LABEL_NAME, true)
			if costLabelInstance ~= nil
				and costLabelInstance:IsA("TextLabel")
				and multiplierLabelInstance ~= nil
				and multiplierLabelInstance:IsA("TextLabel")
			then
				local costLabel = costLabelInstance :: TextLabel
				local multiplierLabel = multiplierLabelInstance :: TextLabel

				return {
					rootGui = existingBillboard,
					costLabel = costLabel,
					multiplierLabel = multiplierLabel,
				}
			end

			existingBillboard:Destroy()
		end
	end

	return createLockedAreaBillboardWidgets(promptPart)
end

local function updateLockedAreaBillboard(promptPart: BasePart, tileSnapshot: PlotTileSnapshot)
	local billboardWidgets = getOrCreateLockedAreaBillboardWidgets(promptPart)
	local multiplierText = getModifierMultiplierText(tileSnapshot.modifierId)
	local hasMultiplier = multiplierText ~= nil

	billboardWidgets.rootGui.Enabled = not tileSnapshot.isUnlocked
	billboardWidgets.rootGui.Adornee = promptPart
	billboardWidgets.costLabel.Text = getCostText(tileSnapshot)
	billboardWidgets.multiplierLabel.Text = if hasMultiplier then multiplierText else ""
	billboardWidgets.multiplierLabel.Visible = hasMultiplier
end

local function getOrCreatePromptPart(
	plot: Instance,
	plotBase: BasePart,
	spawnPart: BasePart,
	tileSnapshot: PlotTileSnapshot
): BasePart?
	local promptFolder = getOrCreatePromptFolder(plot)
	local partName = getPromptPartName(tileSnapshot.row, tileSnapshot.column)
	local existingPart = promptFolder:FindFirstChild(partName)
	if existingPart ~= nil then
		if existingPart:IsA("BasePart") then
			return existingPart
		end

		existingPart:Destroy()
	end

	local centerCFrame = PlotExpansionUtils.getTileCenterCFrame(
		plotBase,
		spawnPart,
		tileSnapshot.row,
		tileSnapshot.column,
		PROMPT_HEIGHT_OFFSET
	)
	if centerCFrame == nil then
		return nil
	end

	local promptPart = Instance.new("Part")
	promptPart.Name = partName
	promptPart.Anchored = true
	promptPart.CanCollide = false
	promptPart.CanQuery = false
	promptPart.CanTouch = false
	promptPart.Transparency = 1
	promptPart.Size = PROMPT_PART_SIZE
	promptPart.CFrame = centerCFrame
	promptPart:SetAttribute(TILE_ROW_ATTRIBUTE, tileSnapshot.row)
	promptPart:SetAttribute(TILE_COLUMN_ATTRIBUTE, tileSnapshot.column)
	promptPart.Parent = promptFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = getPromptActionText(tileSnapshot)
	prompt.ObjectText = getPromptObjectText(tileSnapshot)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_MAX_ACTIVATION_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Parent = promptPart

	prompt.Triggered:Connect(function(player: Player)
		if not PlotService.isAssignedPlot(player, plot) then
			return
		end

		PlotExpansionService.tryPurchaseTile(player, tileSnapshot.row, tileSnapshot.column)
	end)

	return promptPart
end

local function updatePromptPart(
	plot: Instance,
	plotBase: BasePart,
	spawnPart: BasePart,
	tileSnapshot: PlotTileSnapshot
)
	local promptPart = getOrCreatePromptPart(plot, plotBase, spawnPart, tileSnapshot)
	if promptPart == nil then
		return
	end

	local prompt = promptPart:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt == nil then
		return
	end

	local centerCFrame = PlotExpansionUtils.getTileCenterCFrame(
		plotBase,
		spawnPart,
		tileSnapshot.row,
		tileSnapshot.column,
		PROMPT_HEIGHT_OFFSET
	)
	if centerCFrame ~= nil then
		promptPart.CFrame = centerCFrame
	end

	prompt.ActionText = getPromptActionText(tileSnapshot)
	prompt.ObjectText = getPromptObjectText(tileSnapshot)
	prompt.Enabled = not tileSnapshot.isUnlocked
	updateLockedAreaBillboard(promptPart, tileSnapshot)
end

local function refreshPlotPrompts(plot: Instance)
	local ownerUserId = PlotLocator.getOwnerUserId(plot)
	if ownerUserId == nil then
		clearPlotPromptFolder(plot)
		return
	end

	local ownerPlayer = Players:GetPlayerByUserId(ownerUserId)
	if ownerPlayer == nil then
		clearPlotPromptFolder(plot)
		return
	end

	local plotBase = PlotLocator.getPlacementBase(plot)
	local spawnPart = PlotLocator.getSpawnPart(plot)
	if plotBase == nil or spawnPart == nil then
		clearPlotPromptFolder(plot)
		return
	end

	local snapshot = PlotExpansionService.getSnapshot(ownerPlayer)
	for _, tileSnapshot in ipairs(snapshot.tiles) do
		updatePromptPart(plot, plotBase, spawnPart, tileSnapshot)
	end
end

local function refreshPlayerAssignedPlotPrompts(player: Player)
	local plot = PlotService.getAssignedPlot(player)
	if plot ~= nil then
		refreshPlotPrompts(plot)
	end
end

local function connectPlot(plot: Instance)
	plot:GetAttributeChangedSignal(OWNER_USER_ID_ATTRIBUTE):Connect(function()
		refreshPlotPrompts(plot)
	end)

	refreshPlotPrompts(plot)
end

local PlotExpansionPromptService = {}

function PlotExpansionPromptService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	PlotExpansionService.observeChanged(refreshPlayerAssignedPlotPrompts)

	for _, plot in ipairs(PlotLocator.getAllPlots(workspacePlotsFolder)) do
		connectPlot(plot)
	end
end

return table.freeze(PlotExpansionPromptService)

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
local PROMPT_HEIGHT_OFFSET = 3
local PROMPT_MAX_ACTIVATION_DISTANCE = 12
local OWNER_USER_ID_ATTRIBUTE = PlotLocator.Attributes.ownerUserId
local TILE_ROW_ATTRIBUTE = "PlotExpansionRow"
local TILE_COLUMN_ATTRIBUTE = "PlotExpansionColumn"
local LOCKED_AREA_TEMPLATE_NAME = "LockedArea"
local LOCKED_AREA_BILLBOARD_NAME = "LockedAreaBillboard"
local COST_LABEL_NAME = "Cost"
local MULTIPLIER_LABEL_NAME = "Multiplier"
local LOCKED_RICH_TEXT = '<font color="#FF2B2B">Locked</font>'
local BILLBOARD_SIZE = UDim2.fromOffset(260, 130)
local BILLBOARD_MAX_DISTANCE = 250
local BILLBOARD_STUDS_OFFSET = Vector3.new(0, 5, 0)
local COST_TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local MULTIPLIER_TEXT_COLOR = Color3.fromRGB(72, 214, 91)
local TEXT_STROKE_COLOR = Color3.fromRGB(0, 0, 0)
local TEXT_STROKE_TRANSPARENCY = 0
local TEXT_STROKE_THICKNESS = 2
local COST_LABEL_TOP_POSITION = UDim2.fromScale(0.5, 0.33)
local COST_LABEL_CENTER_POSITION = UDim2.fromScale(0.5, 0.4)
local MULTIPLIER_LABEL_POSITION = UDim2.fromScale(0.5, 0.58)
local LABEL_SIZE = UDim2.fromScale(0.98, 0.28)

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

local function ensureTextStroke(label: TextLabel): UIStroke
	local existingStroke = label:FindFirstChild("RuntimeStroke")
	if existingStroke ~= nil and existingStroke:IsA("UIStroke") then
		existingStroke.Color = TEXT_STROKE_COLOR
		existingStroke.Transparency = TEXT_STROKE_TRANSPARENCY
		existingStroke.Thickness = TEXT_STROKE_THICKNESS
		return existingStroke
	end

	if existingStroke ~= nil then
		existingStroke:Destroy()
	end

	local stroke = Instance.new("UIStroke")
	stroke.Name = "RuntimeStroke"
	stroke.Color = TEXT_STROKE_COLOR
	stroke.Transparency = TEXT_STROKE_TRANSPARENCY
	stroke.Thickness = TEXT_STROKE_THICKNESS
	stroke.Parent = label
	return stroke
end

local function styleBillboardLabel(label: TextLabel, textColor: Color3)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.TextScaled = true
	label.TextWrapped = false
	label.RichText = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = textColor
	label.TextStrokeTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Visible = true

	ensureTextStroke(label)
end

local function normalizeBillboardLabelParent(rootGui: BillboardGui, label: TextLabel)
	if label.Parent ~= rootGui then
		label.Parent = rootGui
	end

	label.Rotation = 0
	label.Size = LABEL_SIZE
end

local function hideTemplateBackgrounds(rootGui: BillboardGui)
	for _, descendant in ipairs(rootGui:GetDescendants()) do
		if descendant:IsA("Frame") then
			descendant.BackgroundTransparency = 1
			descendant.BorderSizePixel = 0
		elseif descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
			descendant.BackgroundTransparency = 1
			descendant.BorderSizePixel = 0
			descendant.ImageTransparency = 1
		elseif descendant:IsA("TextButton") then
			descendant.BackgroundTransparency = 1
			descendant.BorderSizePixel = 0
		elseif descendant:IsA("UIStroke") and descendant.Name ~= "RuntimeStroke" then
			descendant.Enabled = false
		end
	end
end

local function styleLockedAreaBillboard(rootGui: BillboardGui)
	rootGui.AlwaysOnTop = true
	rootGui.LightInfluence = 0
	rootGui.MaxDistance = BILLBOARD_MAX_DISTANCE
	rootGui.Size = BILLBOARD_SIZE
	rootGui.StudsOffset = BILLBOARD_STUDS_OFFSET
	rootGui.StudsOffsetWorldSpace = Vector3.zero

	hideTemplateBackgrounds(rootGui)
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
	styleLockedAreaBillboard(rootGui)

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
	styleBillboardLabel(costLabel, COST_TEXT_COLOR)
	normalizeBillboardLabelParent(rootGui, costLabel)

	local multiplierLabel = multiplierLabelInstance :: TextLabel
	styleBillboardLabel(multiplierLabel, MULTIPLIER_TEXT_COLOR)
	normalizeBillboardLabelParent(rootGui, multiplierLabel)

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
				styleLockedAreaBillboard(existingBillboard)

				local costLabel = costLabelInstance :: TextLabel
				styleBillboardLabel(costLabel, COST_TEXT_COLOR)
				normalizeBillboardLabelParent(existingBillboard, costLabel)

				local multiplierLabel = multiplierLabelInstance :: TextLabel
				styleBillboardLabel(multiplierLabel, MULTIPLIER_TEXT_COLOR)
				normalizeBillboardLabelParent(existingBillboard, multiplierLabel)

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
	billboardWidgets.costLabel.Position = if hasMultiplier then COST_LABEL_TOP_POSITION else COST_LABEL_CENTER_POSITION
	billboardWidgets.multiplierLabel.Text = if hasMultiplier then multiplierText else ""
	billboardWidgets.multiplierLabel.Position = MULTIPLIER_LABEL_POSITION
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

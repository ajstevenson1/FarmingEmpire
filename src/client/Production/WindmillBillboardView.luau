--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local windmillsFolder = sharedFolder:WaitForChild("Windmills") :: Folder
local templatesFolder = ReplicatedStorage:WaitForChild("Templates") :: Folder

local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local WindmillConfig = require(windmillsFolder:WaitForChild("WindmillConfig") :: ModuleScript)

type BuildingId = BuildingTypes.BuildingId

type WindmillBillboardWidgets = {
	rootGui: BillboardGui,
	nameLabel: TextLabel?,
	boostLabel: TextLabel?,
}

export type WindmillBillboardView = {
	_part: BasePart,
	_widgets: WindmillBillboardWidgets,
	refresh: (self: WindmillBillboardView) -> (),
	destroy: (self: WindmillBillboardView) -> (),
}

local TEMPLATE_NAME_BY_BUILDING_ID: { [BuildingId]: string } = {
	OfflineEarningsWindmill = "OfflineWindmill",
	CiderCashWindmill = "CashWindmill",
}

local NAME_LABEL_NAMES: { string } = { "Name", "NameLabel", "Title", "TitleLabel" }
local BOOST_LABEL_NAMES: { string } = { "Boost", "BoostLabel", "Multiplier", "MultiplierLabel", "Value", "ValueLabel" }

local WindmillBillboardView = {}
WindmillBillboardView.__index = WindmillBillboardView

local function getBuildingId(part: BasePart): BuildingId?
	local value = part:GetAttribute(BuildingAttributeNames.buildingId)
	if type(value) ~= "string" then
		return nil
	end

	if not WindmillConfig.isWindmillBuildingId(value) then
		return nil
	end

	return value :: BuildingId
end

local function findFirstTextLabel(root: Instance, labelNames: { string }): TextLabel?
	for _, labelName in ipairs(labelNames) do
		local label = root:FindFirstChild(labelName, true)
		if label ~= nil and label:IsA("TextLabel") then
			return label
		end
	end

	return nil
end

local function getTemplateName(buildingId: BuildingId): string
	local templateName = TEMPLATE_NAME_BY_BUILDING_ID[buildingId]
	assert(templateName ~= nil, string.format("No windmill billboard template configured for %s", buildingId))
	return templateName
end

local function createWidgets(part: BasePart): WindmillBillboardWidgets
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before creating windmill billboards")

	local buildingId = getBuildingId(part)
	assert(buildingId ~= nil, "Windmill billboard requires a windmill building id")

	local templateName = getTemplateName(buildingId)
	local template = templatesFolder:WaitForChild(templateName)
	assert(template:IsA("BillboardGui"), string.format("Templates.%s must be a BillboardGui", templateName))

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = template:Clone() :: BillboardGui
	rootGui.Name = string.format("%sBillboard", templateName)
	rootGui.Adornee = part
	rootGui.Parent = playerGui

	return {
		rootGui = rootGui,
		nameLabel = findFirstTextLabel(rootGui, NAME_LABEL_NAMES),
		boostLabel = findFirstTextLabel(rootGui, BOOST_LABEL_NAMES),
	}
end

local function getBoostText(buildingId: BuildingId): string
	local offlineBonus = WindmillConfig.getOfflineEarningsMultiplierBonus(buildingId)
	if offlineBonus > 0 then
		return string.format("+%d%% Offline", math.floor((offlineBonus * 100) + 0.5))
	end

	local cashBonus = WindmillConfig.getCiderSellCashMultiplierBonus(buildingId)
	if cashBonus > 0 then
		return string.format("+%d%% Cash", math.floor((cashBonus * 100) + 0.5))
	end

	return ""
end

function WindmillBillboardView.new(part: BasePart): WindmillBillboardView
	local self = setmetatable({
		_part = part,
		_widgets = createWidgets(part),
	}, WindmillBillboardView) :: WindmillBillboardView

	self:refresh()

	return self
end

function WindmillBillboardView:refresh()
	local buildingId = getBuildingId(self._part)
	if buildingId == nil then
		return
	end

	local definition = WindmillConfig.getDefinition(buildingId)
	if definition ~= nil and self._widgets.nameLabel ~= nil then
		self._widgets.nameLabel.Text = definition.displayName
	end

	if self._widgets.boostLabel ~= nil then
		self._widgets.boostLabel.Text = getBoostText(buildingId)
	end
end

function WindmillBillboardView:destroy()
	self._widgets.rootGui:Destroy()
end

return WindmillBillboardView

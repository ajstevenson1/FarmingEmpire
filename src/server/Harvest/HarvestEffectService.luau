--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder

local BuildingAttributeNames = require(buildingsFolder:WaitForChild("BuildingAttributeNames") :: ModuleScript)
local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local Remotes = require(script.Parent.Parent.Networking.Remotes)

type BuildingDefinition = BuildingTypes.BuildingDefinition
type BuildingId = BuildingTypes.BuildingId
type HarvestOutput = BuildingTypes.HarvestOutput

export type AppleHarvestEffectPayload = {
	buildingPart: BasePart,
	sourcePosition: Vector3,
	appleModelName: string,
	appleCount: number,
}

local APPLE_RESOURCE_ID = "Apple"
local SOURCE_HEIGHT_PADDING_STUDS = 1.5

local HarvestEffectService = {}

local function getStorageCap(buildingDefinition: BuildingDefinition): number
	local productionConfig = buildingDefinition.productionConfig
	if productionConfig.behaviorId == "GrowAndHarvest" or productionConfig.behaviorId == "TimedStorageProducer" then
		return productionConfig.storageCap
	end

	return 0
end

local function getBuildingDefinition(part: BasePart): BuildingDefinition?
	local buildingIdValue = part:GetAttribute(BuildingAttributeNames.buildingId)
	if type(buildingIdValue) ~= "string" or not BuildingCatalog.hasBuildingDefinition(buildingIdValue) then
		return nil
	end

	return BuildingCatalog.getBuildingDefinition(buildingIdValue :: BuildingId)
end

function HarvestEffectService.createAppleHarvestEffectPayload(
	part: BasePart,
	harvestOutput: HarvestOutput
): AppleHarvestEffectPayload?
	if harvestOutput.resourceId ~= APPLE_RESOURCE_ID then
		return nil
	end

	local buildingDefinition = getBuildingDefinition(part)
	if buildingDefinition == nil or buildingDefinition.harvestVisualConfig == nil then
		return nil
	end

	local storageCap = getStorageCap(buildingDefinition)
	if storageCap <= 0 then
		return nil
	end

	local visualConfig = buildingDefinition.harvestVisualConfig
	local appleCount = math.clamp(
		math.ceil((harvestOutput.amount / storageCap) * visualConfig.maxAppleEffectCount),
		1,
		visualConfig.maxAppleEffectCount
	)

	return {
		buildingPart = part,
		sourcePosition = part.Position + Vector3.yAxis * ((part.Size.Y * 0.5) + SOURCE_HEIGHT_PADDING_STUDS),
		appleModelName = visualConfig.appleModelName,
		appleCount = appleCount,
	}
end

function HarvestEffectService.fireAppleHarvestEffects(player: Player, payloads: { AppleHarvestEffectPayload })
	if #payloads == 0 then
		return
	end

	Remotes.getHarvestRemotes().harvestEffect:FireClient(player, payloads)
end

return table.freeze(HarvestEffectService)

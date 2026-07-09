--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local buildingsFolder = sharedFolder:WaitForChild("Buildings") :: Folder
local inventoryFolder = sharedFolder:WaitForChild("Inventory") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local BuildingCatalog = require(buildingsFolder:WaitForChild("BuildingCatalog") :: ModuleScript)
local BuildingTypes = require(buildingsFolder:WaitForChild("BuildingTypes") :: ModuleScript)
local InventoryTypes = require(inventoryFolder:WaitForChild("InventoryTypes") :: ModuleScript)
local ItemCatalog = require(inventoryFolder:WaitForChild("ItemCatalog") :: ModuleScript)
local ResourceCatalog = require(resourcesFolder:WaitForChild("ResourceCatalog") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)
local EconomyService = require(script.Parent.Parent.Economy.EconomyService)
local InventoryService = require(script.Parent.Parent.Inventory.InventoryService)
local ResourceService = require(script.Parent.Parent.Resources.ResourceService)

type BuildingDefinition = BuildingTypes.BuildingDefinition
type BuildingId = BuildingTypes.BuildingId
type ItemDefinition = InventoryTypes.ItemDefinition
type ItemId = InventoryTypes.ItemId
type ResourceDefinition = ResourceTypes.ResourceDefinition
type ResourceId = ResourceTypes.ResourceId

export type AdminGrantKind = "Cash" | "Resource" | "Building" | "AllItems"

export type AdminGrantRequest = {
	kind: AdminGrantKind,
	amount: number?,
	resourceId: ResourceId?,
	buildingId: BuildingId?,
	quantity: number?,
}

local function isPositiveInteger(value: unknown): boolean
	return type(value) == "number"
		and value == math.floor(value)
		and value > 0
		and value < math.huge
end

local function isResourceId(value: unknown): boolean
	if type(value) ~= "string" then
		return false
	end

	return ResourceCatalog.getAllResourceDefinitions()[value :: ResourceId] ~= nil
end

local function isBuildingId(value: unknown): boolean
	if type(value) ~= "string" then
		return false
	end

	return BuildingCatalog.hasBuildingDefinition(value)
end

local function getResourceDisplayName(resourceId: ResourceId): string
	local resourceDefinitions: { [ResourceId]: ResourceDefinition } = ResourceCatalog.getAllResourceDefinitions()
	local resourceDefinition = resourceDefinitions[resourceId]
	if resourceDefinition ~= nil then
		return resourceDefinition.displayName
	end

	return resourceId
end

local function getBuildingDisplayName(buildingId: BuildingId): string
	local buildingDefinitions: { [BuildingId]: BuildingDefinition } = BuildingCatalog.getAllBuildingDefinitions()
	local buildingDefinition = buildingDefinitions[buildingId]
	if buildingDefinition ~= nil then
		return buildingDefinition.displayName
	end

	return buildingId
end

local function getSortedItemDefinitions(): { ItemDefinition }
	local itemDefinitions: { ItemDefinition } = {}

	for _, itemDefinition in pairs(ItemCatalog.getAllItemDefinitions()) do
		table.insert(itemDefinitions, itemDefinition)
	end

	table.sort(itemDefinitions, function(leftItemDefinition: ItemDefinition, rightItemDefinition: ItemDefinition): boolean
		if leftItemDefinition.inventoryOrder == rightItemDefinition.inventoryOrder then
			return leftItemDefinition.displayName < rightItemDefinition.displayName
		end

		return leftItemDefinition.inventoryOrder < rightItemDefinition.inventoryOrder
	end)

	return itemDefinitions
end

local AdminGrantService = {}

function AdminGrantService.isGrantRequest(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end

	local grant = value :: { [string]: unknown }
	local kind = grant.kind

	if kind == "Cash" then
		return isPositiveInteger(grant.amount)
	elseif kind == "Resource" then
		return isResourceId(grant.resourceId) and isPositiveInteger(grant.amount)
	elseif kind == "Building" then
		return isBuildingId(grant.buildingId) and isPositiveInteger(grant.quantity)
	elseif kind == "AllItems" then
		return true
	end

	return false
end

function AdminGrantService.describeGrant(grant: AdminGrantRequest): string
	if not AdminGrantService.isGrantRequest(grant) then
		return "invalid grant"
	end

	if grant.kind == "Cash" then
		return string.format("$%d", grant.amount :: number)
	elseif grant.kind == "Resource" then
		return string.format("%d %s", grant.amount :: number, getResourceDisplayName(grant.resourceId :: ResourceId))
	elseif grant.kind == "Building" then
		return string.format("%dx %s", grant.quantity :: number, getBuildingDisplayName(grant.buildingId :: BuildingId))
	end

	return "one of every inventory item"
end

function AdminGrantService.grantCash(players: { Player }, amount: number): string
	for _, player in ipairs(players) do
		EconomyService.addCash(player, amount)
	end

	return string.format("Gave $%d to %d player(s).", amount, #players)
end

function AdminGrantService.grantResource(players: { Player }, resourceId: ResourceId, amount: number): string
	for _, player in ipairs(players) do
		ResourceService.addResource(player, resourceId, amount)
	end

	return string.format("Gave %d %s to %d player(s).", amount, getResourceDisplayName(resourceId), #players)
end

function AdminGrantService.grantBuilding(players: { Player }, buildingId: BuildingId, quantity: number): string
	for _, player in ipairs(players) do
		InventoryService.addItem(player, buildingId :: ItemId, quantity)
	end

	return string.format("Gave %dx %s to %d player(s).", quantity, buildingId, #players)
end

function AdminGrantService.grantAllItems(players: { Player }): string
	local itemDefinitions = getSortedItemDefinitions()
	local grantedCount = 0

	for _, player in ipairs(players) do
		for _, itemDefinition in ipairs(itemDefinitions) do
			if itemDefinition.maxStack == 1 and InventoryService.getItemQuantity(player, itemDefinition.id) > 0 then
				continue
			end

			InventoryService.addItem(player, itemDefinition.id, 1)
			grantedCount += 1
		end
	end

	return string.format(
		"Gave one of every inventory item (%d grant(s) across %d player(s)).",
		grantedCount,
		#players
	)
end

function AdminGrantService.applyGrantToPlayers(players: { Player }, grant: AdminGrantRequest): string
	if not AdminGrantService.isGrantRequest(grant) then
		return "Invalid grant request."
	end

	if grant.kind == "Cash" then
		return AdminGrantService.grantCash(players, grant.amount :: number)
	elseif grant.kind == "Resource" then
		return AdminGrantService.grantResource(players, grant.resourceId :: ResourceId, grant.amount :: number)
	elseif grant.kind == "Building" then
		return AdminGrantService.grantBuilding(players, grant.buildingId :: BuildingId, grant.quantity :: number)
	end

	return AdminGrantService.grantAllItems(players)
end

return table.freeze(AdminGrantService)

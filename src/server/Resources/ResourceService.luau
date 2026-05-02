--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local ResourceCatalog = require(resourcesFolder:WaitForChild("ResourceCatalog") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)
local Remotes = require(script.Parent.Parent.Networking.Remotes)

type ResourceId = ResourceTypes.ResourceId
type ResourceSnapshot = ResourceTypes.ResourceSnapshot

local hasStarted = false

local function cloneAmounts(amountsByResourceId: { [ResourceId]: number }): { [ResourceId]: number }
	local cloned: { [ResourceId]: number } = {}
	for resourceId in pairs(ResourceCatalog.getAllResourceDefinitions()) do
		cloned[resourceId] = amountsByResourceId[resourceId] or 0
	end

	return cloned
end

local function buildSnapshot(player: Player): ResourceSnapshot
	return {
		amountsByResourceId = cloneAmounts(PlayerDataService.getResourceAmounts(player)),
	}
end

local function pushResourceUpdate(player: Player)
	local resourceRemotes = Remotes.getResourceRemotes()
	resourceRemotes.resourceUpdated:FireClient(player, buildSnapshot(player))
end

local function initializePlayer(player: Player)
	PlayerDataService.waitForData(player)
	pushResourceUpdate(player)
end

local ResourceService = {}

function ResourceService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local resourceRemotes = Remotes.getResourceRemotes()
	resourceRemotes.getResourceSnapshot.OnServerInvoke = function(player: Player): ResourceSnapshot
		return buildSnapshot(player)
	end

	Players.PlayerAdded:Connect(initializePlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		initializePlayer(player)
	end
end

function ResourceService.getResourceAmount(player: Player, resourceId: ResourceId): number
	return PlayerDataService.getResourceAmount(player, resourceId)
end

function ResourceService.tryConsumeResource(player: Player, resourceId: ResourceId, amount: number): boolean
	if amount <= 0 then
		return false
	end

	local currentAmount = PlayerDataService.getResourceAmount(player, resourceId)
	if currentAmount < amount then
		return false
	end

	PlayerDataService.setResourceAmount(player, resourceId, currentAmount - amount)
	pushResourceUpdate(player)
	return true
end

function ResourceService.addResource(player: Player, resourceId: ResourceId, amount: number)
	if amount <= 0 then
		return
	end

	PlayerDataService.setResourceAmount(player, resourceId, PlayerDataService.getResourceAmount(player, resourceId) + amount)
	pushResourceUpdate(player)
end

return table.freeze(ResourceService)

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local ResourceCatalog = require(resourcesFolder:WaitForChild("ResourceCatalog") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)
local Remotes = require(script.Parent.Parent.Networking.Remotes)

type ResourceId = ResourceTypes.ResourceId
type ResourceSnapshot = ResourceTypes.ResourceSnapshot

type PlayerResourceState = {
	amountsByResourceId: { [ResourceId]: number },
}

local playerResources: { [Player]: PlayerResourceState } = {}
local hasStarted = false

local function createResourceState(): PlayerResourceState
	return {
		amountsByResourceId = {},
	}
end

local function getPlayerResourceState(player: Player): PlayerResourceState
	local existingState = playerResources[player]
	if existingState ~= nil then
		return existingState
	end

	local newState = createResourceState()
	playerResources[player] = newState
	return newState
end

local function cloneAmounts(amountsByResourceId: { [ResourceId]: number }): { [ResourceId]: number }
	local cloned: { [ResourceId]: number } = {}
	for resourceId in pairs(ResourceCatalog.getAllResourceDefinitions()) do
		cloned[resourceId] = amountsByResourceId[resourceId] or 0
	end

	return cloned
end

local function buildSnapshot(state: PlayerResourceState): ResourceSnapshot
	return {
		amountsByResourceId = cloneAmounts(state.amountsByResourceId),
	}
end

local function pushResourceUpdate(player: Player)
	local resourceRemotes = Remotes.getResourceRemotes()
	resourceRemotes.resourceUpdated:FireClient(player, buildSnapshot(getPlayerResourceState(player)))
end

local function initializePlayer(player: Player)
	playerResources[player] = createResourceState()
	pushResourceUpdate(player)
end

local function cleanupPlayer(player: Player)
	playerResources[player] = nil
end

local ResourceService = {}

function ResourceService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local resourceRemotes = Remotes.getResourceRemotes()
	resourceRemotes.getResourceSnapshot.OnServerInvoke = function(player: Player): ResourceSnapshot
		return buildSnapshot(getPlayerResourceState(player))
	end

	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(cleanupPlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		initializePlayer(player)
	end
end

function ResourceService.getResourceAmount(player: Player, resourceId: ResourceId): number
	local state = getPlayerResourceState(player)
	return state.amountsByResourceId[resourceId] or 0
end

function ResourceService.tryConsumeResource(player: Player, resourceId: ResourceId, amount: number): boolean
	if amount <= 0 then
		return false
	end

	local state = getPlayerResourceState(player)
	local currentAmount = state.amountsByResourceId[resourceId] or 0
	if currentAmount < amount then
		return false
	end

	local nextAmount = currentAmount - amount
	if nextAmount > 0 then
		state.amountsByResourceId[resourceId] = nextAmount
	else
		state.amountsByResourceId[resourceId] = nil
	end

	pushResourceUpdate(player)
	return true
end

function ResourceService.addResource(player: Player, resourceId: ResourceId, amount: number)
	if amount <= 0 then
		return
	end

	local state = getPlayerResourceState(player)
	state.amountsByResourceId[resourceId] = (state.amountsByResourceId[resourceId] or 0) + amount
	pushResourceUpdate(player)
end

return table.freeze(ResourceService)

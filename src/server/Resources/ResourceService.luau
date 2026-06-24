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
type ResourceUpdateContext = ResourceTypes.ResourceUpdateContext
type ResourceAddedListener = (Player, ResourceId, number) -> ()

local hasStarted = false
local resourceAddedListeners: { ResourceAddedListener } = {}
local pendingUpdateContextsByPlayer: { [Player]: ResourceUpdateContext? } = {}
local updateScheduledByPlayer: { [Player]: boolean } = {}

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

local function fireResourceUpdate(player: Player, context: ResourceUpdateContext?)
	local resourceRemotes = Remotes.getResourceRemotes()
	resourceRemotes.resourceUpdated:FireClient(player, buildSnapshot(player), context)
end

local function mergeUpdateContext(
	previousContext: ResourceUpdateContext?,
	nextContext: ResourceUpdateContext?
): ResourceUpdateContext?
	if previousContext == nil then
		return nextContext
	end

	if nextContext == nil then
		return previousContext
	end

	if previousContext.reason == nextContext.reason then
		return previousContext
	end

	return nil
end

local function pushResourceUpdate(player: Player, context: ResourceUpdateContext?)
	pendingUpdateContextsByPlayer[player] = mergeUpdateContext(pendingUpdateContextsByPlayer[player], context)
	if updateScheduledByPlayer[player] == true then
		return
	end

	updateScheduledByPlayer[player] = true
	task.defer(function()
		updateScheduledByPlayer[player] = nil
		local pendingContext = pendingUpdateContextsByPlayer[player]
		pendingUpdateContextsByPlayer[player] = nil

		if player.Parent == Players then
			fireResourceUpdate(player, pendingContext)
		end
	end)
end

local function notifyResourceAdded(player: Player, resourceId: ResourceId, amount: number)
	for _, listener in ipairs(resourceAddedListeners) do
		local success, result = pcall(function()
			listener(player, resourceId, amount)
		end)

		if not success then
			warn(string.format("Resource-added listener failed for %s: %s", player.Name, tostring(result)))
		end
	end
end

local function initializePlayer(player: Player)
	PlayerDataService.waitForData(player)
	pushResourceUpdate(player, nil)
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
	pushResourceUpdate(player, nil)
	return true
end

function ResourceService.addResourceWithContext(
	player: Player,
	resourceId: ResourceId,
	amount: number,
	context: ResourceUpdateContext?
)
	if amount <= 0 then
		return
	end

	PlayerDataService.setResourceAmount(player, resourceId, PlayerDataService.getResourceAmount(player, resourceId) + amount)
	pushResourceUpdate(player, context)
	notifyResourceAdded(player, resourceId, amount)
end

function ResourceService.addResource(player: Player, resourceId: ResourceId, amount: number)
	ResourceService.addResourceWithContext(player, resourceId, amount, nil)
end

function ResourceService.addResourcesWithContext(
	player: Player,
	amountsByResourceId: { [ResourceId]: number },
	context: ResourceUpdateContext?
)
	local didChange = false
	for resourceId, amount in pairs(amountsByResourceId) do
		if amount <= 0 then
			continue
		end

		PlayerDataService.setResourceAmount(
			player,
			resourceId,
			PlayerDataService.getResourceAmount(player, resourceId) + amount
		)
		notifyResourceAdded(player, resourceId, amount)
		didChange = true
	end

	if didChange then
		pushResourceUpdate(player, context)
	end
end

function ResourceService.addResources(player: Player, amountsByResourceId: { [ResourceId]: number })
	ResourceService.addResourcesWithContext(player, amountsByResourceId, nil)
end

function ResourceService.observeResourceAdded(listener: ResourceAddedListener)
	table.insert(resourceAddedListeners, listener)
end

return table.freeze(ResourceService)

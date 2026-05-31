--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local monetizationFolder = sharedFolder:WaitForChild("Monetization") :: Folder

local GamePassConfig = require(monetizationFolder:WaitForChild("GamePassConfig") :: ModuleScript)

type OwnershipByGamePassId = { [number]: boolean }

local ownershipByPlayer: { [Player]: OwnershipByGamePassId } = {}
local hasStarted = false

local function getPlayerOwnership(player: Player): OwnershipByGamePassId
	local ownership = ownershipByPlayer[player]
	if ownership ~= nil then
		return ownership
	end

	local created: OwnershipByGamePassId = {}
	ownershipByPlayer[player] = created
	return created
end

local function fetchOwnership(player: Player, gamePassId: number): boolean?
	local success, ownsPass = pcall(function(): boolean
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
	end)

	if not success then
		warn(string.format(
			"[GamePassOwnershipService] Failed to check game pass %d for %s: %s",
			gamePassId,
			player.Name,
			tostring(ownsPass)
		))
		return nil
	end

	return ownsPass
end

local function refreshOwnership(player: Player, gamePassId: number): boolean
	local ownsPass = fetchOwnership(player, gamePassId)
	if ownsPass == nil then
		return false
	end

	getPlayerOwnership(player)[gamePassId] = ownsPass
	return ownsPass
end

local function refreshAllOwnership(player: Player)
	local ownership = getPlayerOwnership(player)
	for _, definition in pairs(GamePassConfig.getAllDefinitions()) do
		local ownsPass = fetchOwnership(player, definition.gamePassId)
		if ownsPass ~= nil then
			ownership[definition.gamePassId] = ownsPass
		end
	end
end

local function handlePlayerAdded(player: Player)
	task.spawn(function()
		refreshAllOwnership(player)
	end)
end

local GamePassOwnershipService = {}

function GamePassOwnershipService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	Players.PlayerAdded:Connect(handlePlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		ownershipByPlayer[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
		if not wasPurchased then
			return
		end

		getPlayerOwnership(player)[gamePassId] = true
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		handlePlayerAdded(player)
	end
end

function GamePassOwnershipService.playerOwnsGamePass(player: Player, gamePassId: number): boolean
	local ownership = getPlayerOwnership(player)
	local cachedOwnership = ownership[gamePassId]
	if cachedOwnership ~= nil then
		return cachedOwnership
	end

	return refreshOwnership(player, gamePassId)
end

return table.freeze(GamePassOwnershipService)

--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

export type StationId = string

type StationDefinition = {
	touchPart: BasePart,
	exitDistanceStuds: number,
}

type PlayerStationState = {
	requiresExit: boolean,
}

local EXIT_PADDING_STUDS = 8
local MIN_EXIT_DISTANCE_STUDS = 12

local stationsById: { [StationId]: StationDefinition } = {}
local stateByPlayer: { [Player]: { [StationId]: PlayerStationState } } = {}
local hasStarted = false

local ReopenGuard = {}

local function getDefaultExitDistance(touchPart: BasePart): number
	return math.max(MIN_EXIT_DISTANCE_STUDS, math.max(touchPart.Size.X, touchPart.Size.Z) * 0.5 + EXIT_PADDING_STUDS)
end

local function getPlayerStationStates(player: Player): { [StationId]: PlayerStationState }
	local playerState = stateByPlayer[player]
	if playerState == nil then
		playerState = {}
		stateByPlayer[player] = playerState
	end

	return playerState
end

local function getStationState(player: Player, stationId: StationId): PlayerStationState
	local playerState = getPlayerStationStates(player)
	local stationState = playerState[stationId]
	if stationState == nil then
		stationState = {
			requiresExit = false,
		}
		playerState[stationId] = stationState
	end

	return stationState
end

local function getHumanoidRootPart(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart ~= nil and rootPart:IsA("BasePart") then
		return rootPart
	end

	return nil
end

local function isPlayerInsideStation(player: Player, station: StationDefinition): boolean
	local rootPart = getHumanoidRootPart(player)
	if rootPart == nil then
		return false
	end

	return (rootPart.Position - station.touchPart.Position).Magnitude <= station.exitDistanceStuds
end

local function updateLocks()
	for player, playerState in pairs(stateByPlayer) do
		if player.Parent ~= Players then
			stateByPlayer[player] = nil
			continue
		end

		for stationId, stationState in pairs(playerState) do
			if not stationState.requiresExit then
				continue
			end

			local station = stationsById[stationId]
			if station == nil or not isPlayerInsideStation(player, station) then
				stationState.requiresExit = false
			end
		end
	end
end

function ReopenGuard.registerStation(stationId: StationId, touchPart: BasePart, exitDistanceStuds: number?)
	stationsById[stationId] = {
		touchPart = touchPart,
		exitDistanceStuds = exitDistanceStuds or getDefaultExitDistance(touchPart),
	}
end

function ReopenGuard.canOpen(player: Player, stationId: StationId): boolean
	local stationState = getStationState(player, stationId)
	return not stationState.requiresExit
end

function ReopenGuard.markOpened(player: Player, stationId: StationId)
	getStationState(player, stationId).requiresExit = false
end

function ReopenGuard.markClosed(player: Player, stationId: StationId)
	if stationsById[stationId] == nil then
		return
	end

	getStationState(player, stationId).requiresExit = true
end

function ReopenGuard.start()
	if hasStarted then
		return
	end

	hasStarted = true
	RunService.Heartbeat:Connect(updateLocks)

	Players.PlayerRemoving:Connect(function(player: Player)
		stateByPlayer[player] = nil
	end)
end

return table.freeze(ReopenGuard)

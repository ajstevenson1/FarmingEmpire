--!strict

local PathfindingService = game:GetService("PathfindingService")
local sharedFolder = game:GetService("ReplicatedStorage"):WaitForChild("Shared") :: Folder
local harvestFolder = sharedFolder:WaitForChild("Harvest") :: Folder

local AutoHarvestConfig = require(harvestFolder:WaitForChild("AutoHarvestConfig") :: ModuleScript)

type NavigationWaypoint = {
	position: Vector3,
	action: Enum.PathWaypointAction,
}

export type AutoHarvestNavigator = {
	moveToTarget: (targetPart: BasePart) -> boolean,
	stopMovement: () -> (),
}

local AutoHarvestNavigator = {}
local movementCancelToken = 0
local WAYPOINT_SPACING_STUDS = 8
local DIRECT_MOVE_DISTANCE_STUDS = 28
local WAYPOINT_REACHED_DISTANCE_STUDS = 3
local MOVE_TO_REFRESH_SECONDS = 0.75
local MOVE_TIMEOUT_PADDING_SECONDS = 2

local function getHumanoidAndRootPart(): (Humanoid?, BasePart?)
	local Players = game:GetService("Players")
	local localPlayer = Players.LocalPlayer
	if localPlayer == nil or localPlayer.Character == nil then
		return nil, nil
	end

	local character = localPlayer.Character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return humanoid, nil
	end

	return humanoid, rootPart
end

local function isCloseEnough(rootPart: BasePart, targetPart: BasePart): boolean
	return (rootPart.Position - targetPart.Position).Magnitude <= AutoHarvestConfig.approachDistanceStuds
end

local function getPathWaypoints(rootPart: BasePart, targetPart: BasePart): { NavigationWaypoint }
	if (rootPart.Position - targetPart.Position).Magnitude <= DIRECT_MOVE_DISTANCE_STUDS then
		return {
			{
				position = targetPart.Position,
				action = Enum.PathWaypointAction.Walk,
			},
		}
	end

	local path = PathfindingService:CreatePath({
		AgentCanJump = true,
		WaypointSpacing = WAYPOINT_SPACING_STUDS,
	})

	local computedSuccessfully = pcall(function()
		path:ComputeAsync(rootPart.Position, targetPart.Position)
	end)

	if not computedSuccessfully or path.Status ~= Enum.PathStatus.Success then
		return {
			{
				position = targetPart.Position,
				action = Enum.PathWaypointAction.Walk,
			},
		}
	end

	local waypoints: { NavigationWaypoint } = {}
	for _, waypoint in ipairs(path:GetWaypoints()) do
		table.insert(waypoints, {
			position = waypoint.Position,
			action = waypoint.Action,
		})
	end

	if #waypoints == 0 then
		return {
			{
				position = targetPart.Position,
				action = Enum.PathWaypointAction.Walk,
			},
		}
	end

	return waypoints
end

local function followWaypoints(
	humanoid: Humanoid,
	rootPart: BasePart,
	targetPart: BasePart,
	waypoints: { NavigationWaypoint },
	cancelToken: number
): boolean
	local waypointIndex = 1
	local lastMoveToTime = 0
	local estimatedTimeoutSeconds = math.max(
		AutoHarvestConfig.moveTimeoutSeconds,
		(rootPart.Position - targetPart.Position).Magnitude / math.max(humanoid.WalkSpeed, 1) + MOVE_TIMEOUT_PADDING_SECONDS
	)
	local finishesAt = os.clock() + estimatedTimeoutSeconds

	while os.clock() < finishesAt do
		if movementCancelToken ~= cancelToken then
			humanoid:Move(Vector3.zero)
			return false
		end

		if targetPart.Parent == nil then
			humanoid:Move(Vector3.zero)
			return false
		end

		if isCloseEnough(rootPart, targetPart) then
			humanoid:Move(Vector3.zero)
			return true
		end

		local waypoint = waypoints[math.clamp(waypointIndex, 1, #waypoints)]
		local waypointOffset = waypoint.position - rootPart.Position
		local planarWaypointOffset = Vector3.new(waypointOffset.X, 0, waypointOffset.Z)
		if planarWaypointOffset.Magnitude <= WAYPOINT_REACHED_DISTANCE_STUDS and waypointIndex < #waypoints then
			waypointIndex += 1
			waypoint = waypoints[waypointIndex]
			lastMoveToTime = 0
		end

		local now = os.clock()
		if now - lastMoveToTime >= MOVE_TO_REFRESH_SECONDS then
			if waypoint.action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end

			humanoid:MoveTo(waypoint.position)
			lastMoveToTime = now
		end

		task.wait(0.05)
	end

	humanoid:Move(Vector3.zero)
	return isCloseEnough(rootPart, targetPart)
end

function AutoHarvestNavigator.moveToTarget(targetPart: BasePart): boolean
	local cancelToken = movementCancelToken
	local humanoid, rootPart = getHumanoidAndRootPart()
	if humanoid == nil or rootPart == nil or targetPart.Parent == nil then
		return false
	end

	if isCloseEnough(rootPart, targetPart) then
		return true
	end

	return followWaypoints(humanoid, rootPart, targetPart, getPathWaypoints(rootPart, targetPart), cancelToken)
end

function AutoHarvestNavigator.stopMovement()
	movementCancelToken += 1
	local humanoid, rootPart = getHumanoidAndRootPart()
	if humanoid == nil or rootPart == nil then
		return
	end

	humanoid:Move(Vector3.zero)
	humanoid:MoveTo(rootPart.Position)
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
end

return table.freeze(AutoHarvestNavigator)

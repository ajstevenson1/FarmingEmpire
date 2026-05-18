--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

type PlotServiceApi = {
	getAssignedPlotBase: (player: Player) -> BasePart?,
}

local PlotService = require(script.Parent.Parent.Plots.PlotService) :: PlotServiceApi

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local charactersCodeFolder = sharedFolder:WaitForChild("Characters") :: Folder

type FallRecoveryConfigData = {
	recoveryTriggerY: number,
	minimumHeightAboveDestroyHeightStuds: number,
	teleportHeightAbovePlotCenterStuds: number,
}

local FallRecoveryConfig = require(charactersCodeFolder:WaitForChild("FallRecoveryConfig") :: ModuleScript) :: FallRecoveryConfigData

local CHARACTER_ROOT_PART_NAME = "HumanoidRootPart"

local hasStarted = false
local heartbeatConnection: RBXScriptConnection? = nil

local function getRecoveryTriggerY(): number
	local safeRecoveryY = Workspace.FallenPartsDestroyHeight + FallRecoveryConfig.minimumHeightAboveDestroyHeightStuds
	return math.max(FallRecoveryConfig.recoveryTriggerY, safeRecoveryY)
end

local function getLivingRootPart(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end

	local rootPart = character:FindFirstChild(CHARACTER_ROOT_PART_NAME)
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil
	end

	return rootPart
end

local function applyCharacterVelocity(character: Model, velocity: Vector3)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = velocity
		end
	end
end

local function recoverPlayer(player: Player, rootPart: BasePart)
	local plotBase = PlotService.getAssignedPlotBase(player)
	if plotBase == nil then
		return
	end

	local character = player.Character
	if character == nil then
		return
	end

	local recoveryPosition = plotBase.Position + Vector3.new(0, FallRecoveryConfig.teleportHeightAbovePlotCenterStuds, 0)
	local fallVelocity = rootPart.AssemblyLinearVelocity

	character:PivotTo(CFrame.new(recoveryPosition))
	applyCharacterVelocity(character, fallVelocity)
end

local function checkPlayer(player: Player)
	local rootPart = getLivingRootPart(player)
	if rootPart == nil or rootPart.Position.Y > getRecoveryTriggerY() then
		return
	end

	recoverPlayer(player, rootPart)
end

local function checkPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		checkPlayer(player)
	end
end

local FallRecoveryService = {}

function FallRecoveryService.start()
	if hasStarted then
		return
	end

	hasStarted = true
	if heartbeatConnection ~= nil then
		heartbeatConnection:Disconnect()
	end

	heartbeatConnection = RunService.Heartbeat:Connect(checkPlayers)
end

return table.freeze(FallRecoveryService)

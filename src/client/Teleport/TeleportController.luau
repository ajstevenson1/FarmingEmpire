--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before starting teleport controller")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder

local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)

type TeleportDestination = "Plot" | "Shop" | "Sell"

local PLAYER_GUI_NAME = "PlayerGui"
local ROOT_GUI_NAME = "GUI"
local HUD_NAME = "HUD"
local TOP_NAME = "Top"
local BUTTONS_NAME = "Buttons"

local hasStarted = false

local function getRequestTeleportRemote(): RemoteEvent
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local teleportFolder = rootFolder:WaitForChild(RemoteNames.teleportFolderName) :: Folder
	return teleportFolder:WaitForChild(RemoteNames.requestTeleportEventName) :: RemoteEvent
end

local function getButtonsContainer(): Instance
	local playerGui = localPlayer:WaitForChild(PLAYER_GUI_NAME) :: PlayerGui
	local rootGui = playerGui:WaitForChild(ROOT_GUI_NAME)
	local hud = rootGui:WaitForChild(HUD_NAME)
	local top = hud:WaitForChild(TOP_NAME)
	return top:WaitForChild(BUTTONS_NAME)
end

local function getTeleportButton(buttonsContainer: Instance, buttonName: string): GuiButton
	local button = buttonsContainer:WaitForChild(buttonName)
	assert(button:IsA("GuiButton"), string.format("%s must be an ImageButton or TextButton", button:GetFullName()))
	return button
end

local function bindTeleportButton(button: GuiButton, requestTeleportRemote: RemoteEvent, destination: TeleportDestination)
	button.Activated:Connect(function()
		requestTeleportRemote:FireServer(destination)
	end)
end

local TeleportController = {}

function TeleportController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local requestTeleportRemote = getRequestTeleportRemote()
	local buttonsContainer = getButtonsContainer()

	bindTeleportButton(getTeleportButton(buttonsContainer, "PlotTeleport"), requestTeleportRemote, "Plot")
	bindTeleportButton(getTeleportButton(buttonsContainer, "ShopTeleport"), requestTeleportRemote, "Shop")
	bindTeleportButton(getTeleportButton(buttonsContainer, "SellTeleport"), requestTeleportRemote, "Sell")
end

return table.freeze(TeleportController)

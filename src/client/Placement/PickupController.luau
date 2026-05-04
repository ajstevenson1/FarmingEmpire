--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before starting pickup")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder

local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local PickupSelectionViewModule = require(script.Parent.PickupSelectionView)

type PickupSelectionView = PickupSelectionViewModule.PickupSelectionView

type Widgets = {
	rootGui: ScreenGui,
	button: TextButton,
}

local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
local MAX_PICKUP_DISTANCE_STUDS = 40

local hasStarted = false
local isPickupModeEnabled = false
local widgets: Widgets? = nil
local selectionView: PickupSelectionView? = nil
local currentPickupTarget: BasePart? = nil

local function getRequestPickupRemote(): RemoteEvent
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local placementRemotesFolder = rootFolder:WaitForChild(RemoteNames.placementFolderName) :: Folder
	return placementRemotesFolder:WaitForChild(RemoteNames.requestPickupEventName) :: RemoteEvent
end

local function getPlacedObjectsFolder(): Folder?
	local placedObjectsFolder = Workspace:FindFirstChild(PLACED_OBJECTS_FOLDER_NAME)
	if placedObjectsFolder == nil or not placedObjectsFolder:IsA("Folder") then
		return nil
	end

	return placedObjectsFolder
end

local function getPickupRaycastResult(): RaycastResult?
	local camera = Workspace.CurrentCamera
	local placedObjectsFolder = getPlacedObjectsFolder()
	if camera == nil or placedObjectsFolder == nil then
		return nil
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	local screenRay = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { placedObjectsFolder }
	raycastParams.IgnoreWater = true

	return Workspace:Raycast(screenRay.Origin, screenRay.Direction * 1000, raycastParams)
end

local function getPlacedPartFromInstance(instance: Instance): BasePart?
	local placedObjectsFolder = getPlacedObjectsFolder()
	if placedObjectsFolder == nil then
		return nil
	end

	local current: Instance? = instance
	while current ~= nil and current ~= placedObjectsFolder do
		if current:IsA("BasePart") and current.Parent == placedObjectsFolder then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function getCharacterRootPart(): BasePart?
	local character = localPlayer.Character
	if character == nil then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil
	end

	return rootPart
end

local function isCloseEnoughToPickup(placedPart: BasePart): boolean
	local rootPart = getCharacterRootPart()
	if rootPart == nil then
		return false
	end

	return (rootPart.Position - placedPart.Position).Magnitude <= MAX_PICKUP_DISTANCE_STUDS
end

local function getCurrentPickupTarget(): BasePart?
	local raycastResult = getPickupRaycastResult()
	if raycastResult == nil then
		return nil
	end

	local placedPart = getPlacedPartFromInstance(raycastResult.Instance)
	if placedPart == nil then
		return nil
	end

	if placedPart:GetAttribute(OWNER_USER_ID_ATTRIBUTE) ~= localPlayer.UserId then
		return nil
	end

	if not isCloseEnoughToPickup(placedPart) then
		return nil
	end

	return placedPart
end

local function clearPickupTarget()
	currentPickupTarget = nil

	local currentSelectionView = selectionView
	if currentSelectionView ~= nil then
		currentSelectionView:hide()
	end
end

local function updatePickupSelection()
	local currentSelectionView = selectionView
	if currentSelectionView == nil then
		return
	end

	if not isPickupModeEnabled or UserInputService:GetFocusedTextBox() ~= nil then
		clearPickupTarget()
		return
	end

	local pickupTarget = getCurrentPickupTarget()
	if pickupTarget == nil then
		clearPickupTarget()
		return
	end

	currentPickupTarget = pickupTarget
	currentSelectionView:show(pickupTarget)
end

local function renderButton(button: TextButton)
	button.Text = if isPickupModeEnabled then "Pickup: On" else "Pickup"
	button.BackgroundColor3 = if isPickupModeEnabled then Color3.fromRGB(58, 137, 91) else Color3.fromRGB(43, 39, 31)
	button.TextColor3 = Color3.fromRGB(255, 247, 236)
end

local function createWidgets(): Widgets
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	local rootGui = Instance.new("ScreenGui")
	rootGui.Name = "PickupTestGui"
	rootGui.IgnoreGuiInset = true
	rootGui.ResetOnSpawn = false
	rootGui.Parent = playerGui

	local button = Instance.new("TextButton")
	button.Name = "PickupButton"
	button.AnchorPoint = Vector2.new(0, 1)
	button.Position = UDim2.new(0, 18, 1, -126)
	button.Size = UDim2.fromOffset(112, 36)
	button.BackgroundColor3 = Color3.fromRGB(43, 39, 31)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = "Pickup"
	button.TextSize = 15
	button.AutoButtonColor = true
	button.Parent = rootGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(137, 111, 66)
	stroke.Thickness = 1
	stroke.Transparency = 0.1
	stroke.Parent = button

	renderButton(button)

	return {
		rootGui = rootGui,
		button = button,
	}
end

local PickupController = {}

function PickupController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local pickupWidgets = createWidgets()
	widgets = pickupWidgets
	selectionView = PickupSelectionViewModule.new()
	local requestPickupRemote = getRequestPickupRemote()

	pickupWidgets.button.Activated:Connect(function()
		isPickupModeEnabled = not isPickupModeEnabled
		if not isPickupModeEnabled then
			clearPickupTarget()
		end

		renderButton(pickupWidgets.button)
	end)

	RunService.RenderStepped:Connect(updatePickupSelection)

	UserInputService.InputBegan:Connect(function(inputObject: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if not isPickupModeEnabled then
			return
		end

		if UserInputService:GetFocusedTextBox() ~= nil then
			return
		end

		if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		local pickupTarget = currentPickupTarget
		if pickupTarget == nil then
			return
		end

		requestPickupRemote:FireServer(pickupTarget)
		clearPickupTarget()
	end)
end

function PickupController.isPickupModeEnabled(): boolean
	return isPickupModeEnabled
end

function PickupController.destroy()
	local pickupWidgets = widgets
	if pickupWidgets == nil then
		return
	end

	pickupWidgets.rootGui:Destroy()
	clearPickupTarget()

	local currentSelectionView = selectionView
	if currentSelectionView ~= nil then
		currentSelectionView:destroy()
	end

	selectionView = nil
	widgets = nil
	hasStarted = false
	isPickupModeEnabled = false
end

return table.freeze(PickupController)

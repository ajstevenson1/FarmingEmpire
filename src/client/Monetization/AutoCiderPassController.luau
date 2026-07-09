--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before starting AutoCiderPassController")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local monetizationFolder = sharedFolder:WaitForChild("Monetization") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder

local GamePassConfig = require(monetizationFolder:WaitForChild("GamePassConfig") :: ModuleScript)
local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)

type GamePassDefinition = GamePassConfig.GamePassDefinition
type GuiButtonLike = TextButton | ImageButton
type OwnershipChangedCallback = (boolean) -> ()
type EnabledChangedCallback = (boolean) -> ()

local ROOT_GUI_NAME = "GUI"
local HUD_NAME = "HUD"
local RIGHT_CONTAINER_NAME = "Right"
local BUTTON_NAME = "AutoCiderPass"
local ACTIVE_STROKE_COLOR = Color3.fromRGB(255, 255, 255)
local INACTIVE_STROKE_COLOR = Color3.fromRGB(0, 0, 0)

local hasStarted = false
local ownsAutoCiderPass = false
local isAutoCiderEnabled = false
local ownershipChangedCallbacks: { OwnershipChangedCallback } = {}
local enabledChangedCallbacks: { EnabledChangedCallback } = {}
local button: GuiButtonLike? = nil
local buttonStroke: UIStroke? = nil
local setAutoCiderEnabledRemote: RemoteEvent? = nil

local function getDefinition(): GamePassDefinition
	return GamePassConfig.getAutoCiderDefinition()
end

local function getButton(): GuiButtonLike
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild(ROOT_GUI_NAME)
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")

	local hud = rootGui:WaitForChild(HUD_NAME)
	assert(hud:IsA("GuiObject"), "PlayerGui.GUI.HUD must be a GuiObject")

	local rightContainer = hud:WaitForChild(RIGHT_CONTAINER_NAME)
	assert(rightContainer:IsA("GuiObject"), "PlayerGui.GUI.HUD.Right must be a GuiObject")

	local foundButton = rightContainer:WaitForChild(BUTTON_NAME)
	assert(
		foundButton:IsA("TextButton") or foundButton:IsA("ImageButton"),
		"PlayerGui.GUI.HUD.Right.AutoCiderPass must be a GuiButton"
	)

	return foundButton :: GuiButtonLike
end

local function findStroke(targetButton: GuiButtonLike): UIStroke
	local designFrame = targetButton:FindFirstChild("Design")
	if designFrame ~= nil then
		assert(designFrame:IsA("GuiObject"), "GUI.HUD.Right.AutoCiderPass.Design must be a GuiObject")

		local designStroke = designFrame:FindFirstChild("Stroke")
		assert(designStroke ~= nil, "GUI.HUD.Right.AutoCiderPass.Design must contain a Stroke child")
		assert(designStroke:IsA("UIStroke"), "GUI.HUD.Right.AutoCiderPass.Design.Stroke must be a UIStroke")
		return designStroke
	end

	local directStroke = targetButton:FindFirstChildWhichIsA("UIStroke")
	assert(directStroke ~= nil, "GUI.HUD.Right.AutoCiderPass must contain a UIStroke")
	return directStroke
end

local function getSetAutoCiderEnabledRemote(): RemoteEvent
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName) :: Folder
	local monetizationRemotesFolder = rootFolder:WaitForChild(RemoteNames.monetizationFolderName) :: Folder
	local remote = monetizationRemotesFolder:WaitForChild(RemoteNames.setAutoCiderEnabledEventName)
	assert(remote:IsA("RemoteEvent"), "Monetization.SetAutoCiderEnabled must be a RemoteEvent")
	return remote
end

local function renderButton()
	local stroke = buttonStroke
	if stroke == nil then
		return
	end

	stroke.Color = if ownsAutoCiderPass and isAutoCiderEnabled then ACTIVE_STROKE_COLOR else INACTIVE_STROKE_COLOR
end

local function notifyOwnershipChanged()
	for _, callback in ipairs(ownershipChangedCallbacks) do
		callback(ownsAutoCiderPass)
	end
end

local function notifyEnabledChanged()
	local isEnabled = ownsAutoCiderPass and isAutoCiderEnabled
	for _, callback in ipairs(enabledChangedCallbacks) do
		callback(isEnabled)
	end
end

local function setOwnership(nextOwnsAutoCiderPass: boolean)
	if ownsAutoCiderPass == nextOwnsAutoCiderPass then
		renderButton()
		return
	end

	ownsAutoCiderPass = nextOwnsAutoCiderPass
	if not ownsAutoCiderPass then
		isAutoCiderEnabled = false
	end

	renderButton()
	notifyOwnershipChanged()
	notifyEnabledChanged()
end

local function setEnabled(nextIsAutoCiderEnabled: boolean)
	if not ownsAutoCiderPass then
		if isAutoCiderEnabled then
			isAutoCiderEnabled = false
			notifyEnabledChanged()
		end
		renderButton()
		return
	end

	if isAutoCiderEnabled == nextIsAutoCiderEnabled then
		renderButton()
		return
	end

	isAutoCiderEnabled = nextIsAutoCiderEnabled
	renderButton()
	notifyEnabledChanged()

	local remote = setAutoCiderEnabledRemote
	if remote ~= nil then
		remote:FireServer(isAutoCiderEnabled)
	end
end

local function refreshOwnership()
	task.spawn(function()
		local definition = getDefinition()
		local success, ownsPass = pcall(function(): boolean
			return MarketplaceService:UserOwnsGamePassAsync(localPlayer.UserId, definition.gamePassId)
		end)

		if not success then
			warn(string.format("[AutoCiderPassController] Failed to check Auto Juice ownership: %s", tostring(ownsPass)))
			return
		end

		setOwnership(ownsPass)
	end)
end

local AutoCiderPassController = {}

function AutoCiderPassController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local createdButton = getButton()
	button = createdButton
	buttonStroke = findStroke(createdButton)
	setAutoCiderEnabledRemote = getSetAutoCiderEnabledRemote()
	renderButton()
	refreshOwnership()

	createdButton.Activated:Connect(function()
		if ownsAutoCiderPass then
			setEnabled(not isAutoCiderEnabled)
			return
		end

		local definition = getDefinition()
		MarketplaceService:PromptGamePassPurchase(localPlayer, definition.gamePassId)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
		local definition = getDefinition()
		if player == localPlayer and gamePassId == definition.gamePassId and wasPurchased then
			setOwnership(true)
		end
	end)
end

function AutoCiderPassController.ownsAutoCiderPass(): boolean
	return ownsAutoCiderPass
end

function AutoCiderPassController.isAutoCiderEnabled(): boolean
	return ownsAutoCiderPass and isAutoCiderEnabled
end

function AutoCiderPassController.observeOwnershipChanged(callback: OwnershipChangedCallback)
	table.insert(ownershipChangedCallbacks, callback)
end

function AutoCiderPassController.observeEnabledChanged(callback: EnabledChangedCallback)
	table.insert(enabledChangedCallbacks, callback)
end

return table.freeze(AutoCiderPassController)

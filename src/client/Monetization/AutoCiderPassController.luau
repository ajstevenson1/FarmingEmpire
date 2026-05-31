--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before starting AutoCiderPassController")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local monetizationFolder = sharedFolder:WaitForChild("Monetization") :: Folder

local GamePassConfig = require(monetizationFolder:WaitForChild("GamePassConfig") :: ModuleScript)

type GamePassDefinition = GamePassConfig.GamePassDefinition
type GuiButtonLike = TextButton | ImageButton
type OwnershipChangedCallback = (boolean) -> ()

local ROOT_GUI_NAME = "GUI"
local HUD_NAME = "HUD"
local RIGHT_CONTAINER_NAME = "Right"
local BUTTON_NAME = "AutoCiderPass"
local OWNED_TEXT = "Owned"

local hasStarted = false
local ownsAutoCiderPass = false
local ownershipChangedCallbacks: { OwnershipChangedCallback } = {}
local button: GuiButtonLike? = nil

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

local function setButtonText(targetButton: GuiButtonLike, text: string)
	local textLabel = targetButton:FindFirstChild("Text", true)
	if textLabel ~= nil and textLabel:IsA("TextLabel") then
		textLabel.Text = text
	end
end

local function renderButton()
	local targetButton = button
	if targetButton == nil then
		return
	end

	local definition = getDefinition()
	setButtonText(targetButton, if ownsAutoCiderPass then OWNED_TEXT else definition.displayName)
end

local function notifyOwnershipChanged()
	for _, callback in ipairs(ownershipChangedCallbacks) do
		callback(ownsAutoCiderPass)
	end
end

local function setOwnership(nextOwnsAutoCiderPass: boolean)
	if ownsAutoCiderPass == nextOwnsAutoCiderPass then
		renderButton()
		return
	end

	ownsAutoCiderPass = nextOwnsAutoCiderPass
	renderButton()
	notifyOwnershipChanged()
end

local function refreshOwnership()
	task.spawn(function()
		local definition = getDefinition()
		local success, ownsPass = pcall(function(): boolean
			return MarketplaceService:UserOwnsGamePassAsync(localPlayer.UserId, definition.gamePassId)
		end)

		if not success then
			warn(string.format("[AutoCiderPassController] Failed to check Auto Cider ownership: %s", tostring(ownsPass)))
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
	renderButton()
	refreshOwnership()

	createdButton.Activated:Connect(function()
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

function AutoCiderPassController.observeOwnershipChanged(callback: OwnershipChangedCallback)
	table.insert(ownershipChangedCallbacks, callback)
end

return table.freeze(AutoCiderPassController)

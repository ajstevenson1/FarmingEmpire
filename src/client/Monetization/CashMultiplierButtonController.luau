--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local monetizationFolder = sharedFolder:WaitForChild("Monetization") :: Folder

local GamePassConfig = require(monetizationFolder:WaitForChild("GamePassConfig") :: ModuleScript)

type GamePassDefinition = GamePassConfig.GamePassDefinition
type GuiButtonLike = TextButton | ImageButton

local ROOT_GUI_NAME = "GUI"
local HUD_NAME = "HUD"
local RIGHT_CONTAINER_NAME = "Right"
local BUTTON_NAME = "2x Cash"
local OWNED_SUFFIX_TEXT = "Owned"

local hasStarted = false
local nextPurchaseDefinition: GamePassDefinition? = nil
local promptDefinition: GamePassDefinition? = nil

local function getButton(): GuiButtonLike
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before starting CashMultiplierButtonController")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild(ROOT_GUI_NAME)
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")

	local hud = rootGui:WaitForChild(HUD_NAME)
	assert(hud:IsA("GuiObject"), "PlayerGui.GUI.HUD must be a GuiObject")

	local rightContainer = hud:WaitForChild(RIGHT_CONTAINER_NAME)
	assert(rightContainer:IsA("GuiObject"), "PlayerGui.GUI.HUD.Right must be a GuiObject")

	local button = rightContainer:WaitForChild(BUTTON_NAME)
	assert(button:IsA("TextButton") or button:IsA("ImageButton"), "PlayerGui.GUI.HUD.Right.2x Cash must be a GuiButton")

	return button :: GuiButtonLike
end

local function setButtonText(button: GuiButtonLike, text: string)
	local textLabel = button:FindFirstChild("Text", true)
	if textLabel ~= nil and textLabel:IsA("TextLabel") then
		textLabel.Text = text
	end
end

local function getOwnedCashMultiplierGamePassIds(): { [number]: boolean }
	local localPlayer = Players.LocalPlayer
	local ownedGamePassIds: { [number]: boolean } = {}
	if localPlayer == nil then
		return ownedGamePassIds
	end

	for _, definition in ipairs(GamePassConfig.getCashMultiplierDefinitions()) do
		local success, ownsPass = pcall(function(): boolean
			return MarketplaceService:UserOwnsGamePassAsync(localPlayer.UserId, definition.gamePassId)
		end)

		if success and ownsPass then
			ownedGamePassIds[definition.gamePassId] = true
		end
	end

	return ownedGamePassIds
end

local function getNextPurchaseDefinition(ownedGamePassIds: { [number]: boolean }): GamePassDefinition?
	local definitions = GamePassConfig.getCashMultiplierDefinitions()
	local highestOwnedIndex = 0
	for index, definition in ipairs(definitions) do
		if ownedGamePassIds[definition.gamePassId] ~= true then
			continue
		end

		highestOwnedIndex = index
	end

	return definitions[highestOwnedIndex + 1]
end

local function renderButton(button: GuiButtonLike, purchaseDefinition: GamePassDefinition?)
	nextPurchaseDefinition = purchaseDefinition

	if purchaseDefinition == nil then
		local definitions = GamePassConfig.getCashMultiplierDefinitions()
		local highestDefinition = definitions[#definitions]
		promptDefinition = highestDefinition
		setButtonText(button, if highestDefinition == nil then OWNED_SUFFIX_TEXT else `{highestDefinition.displayName} {OWNED_SUFFIX_TEXT}`)
		return
	end

	promptDefinition = purchaseDefinition
	setButtonText(button, purchaseDefinition.displayName)
end

local function refreshButton(button: GuiButtonLike)
	task.spawn(function()
		renderButton(button, getNextPurchaseDefinition(getOwnedCashMultiplierGamePassIds()))
	end)
end

local CashMultiplierButtonController = {}

function CashMultiplierButtonController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local button = getButton()
	refreshButton(button)

	button.Activated:Connect(function()
		local localPlayer = Players.LocalPlayer
		local purchaseDefinition = promptDefinition or nextPurchaseDefinition
		if localPlayer == nil or purchaseDefinition == nil then
			return
		end

		MarketplaceService:PromptGamePassPurchase(localPlayer, purchaseDefinition.gamePassId)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
		local localPlayer = Players.LocalPlayer
		if localPlayer == nil or player ~= localPlayer or not wasPurchased then
			return
		end

		for _, definition in ipairs(GamePassConfig.getCashMultiplierDefinitions()) do
			if definition.gamePassId == gamePassId then
				refreshButton(button)
				return
			end
		end
	end)
end

return table.freeze(CashMultiplierButtonController)

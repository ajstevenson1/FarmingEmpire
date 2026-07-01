--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local formattingFolder = sharedFolder:WaitForChild("Formatting") :: Folder
local monetizationFolder = sharedFolder:WaitForChild("Monetization") :: Folder

local GamePassConfig = require(monetizationFolder:WaitForChild("GamePassConfig") :: ModuleScript)
local NumberFormatter = require(formattingFolder:WaitForChild("NumberFormatter") :: ModuleScript)
local SpecialOfferConfig = require(monetizationFolder:WaitForChild("SpecialOfferConfig") :: ModuleScript)
local HudNotificationController = require(script.Parent.Parent.Notifications.HudNotificationController)

type GamePassDefinition = GamePassConfig.GamePassDefinition
type GuiButtonLike = TextButton | ImageButton

local ROOT_GUI_NAME = "GUI"
local HUD_NAME = "HUD"
local RIGHT_CONTAINER_NAME = "Right"
local ROBUX_ICON = string.char(0xEE, 0x80, 0x82)
local PRICE_UNAVAILABLE_TEXT = "Only " .. ROBUX_ICON .. "--"
local PURCHASE_COMPLETE_TEXT = "Special Offer claimed! Glass Tree and Tempest Mill added to your inventory."

local hasStarted = false
local ownsSpecialOffer = false

local function getLocalPlayer(): Player
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before starting SpecialOfferButtonController")
	return localPlayer
end

local function getButton(buttonName: string): GuiButtonLike
	local playerGui = getLocalPlayer():WaitForChild("PlayerGui") :: PlayerGui
	local rootGui = playerGui:WaitForChild(ROOT_GUI_NAME)
	assert(rootGui:IsA("ScreenGui"), "PlayerGui.GUI must be a ScreenGui")

	local hud = rootGui:WaitForChild(HUD_NAME)
	assert(hud:IsA("GuiObject"), "PlayerGui.GUI.HUD must be a GuiObject")

	local rightContainer = hud:WaitForChild(RIGHT_CONTAINER_NAME)
	assert(rightContainer:IsA("GuiObject"), "PlayerGui.GUI.HUD.Right must be a GuiObject")

	local button = rightContainer:WaitForChild(buttonName)
	assert(button:IsA("TextButton") or button:IsA("ImageButton"), "PlayerGui.GUI.HUD.Right.SpecialOffer must be a GuiButton")

	return button :: GuiButtonLike
end

local function getCostLabel(button: GuiButtonLike, costLabelName: string): TextLabel
	local costLabel = button:FindFirstChild(costLabelName, true)
	assert(costLabel ~= nil, "PlayerGui.GUI.HUD.Right.SpecialOffer must contain a Cost label")
	assert(costLabel:IsA("TextLabel"), "PlayerGui.GUI.HUD.Right.SpecialOffer.Cost must be a TextLabel")
	return costLabel :: TextLabel
end

local function formatRobuxPrice(priceInRobux: number): string
	return "Only " .. ROBUX_ICON .. NumberFormatter.formatFull(math.max(0, math.floor(priceInRobux)))
end

local function renderButton(button: GuiButtonLike)
	button.Visible = not ownsSpecialOffer
	button.Active = not ownsSpecialOffer
end

local function updateCostText(costLabel: TextLabel, gamePassDefinition: GamePassDefinition)
	costLabel.Text = PRICE_UNAVAILABLE_TEXT

	task.spawn(function()
		local success, productInfo = pcall(function(): unknown
			return MarketplaceService:GetProductInfo(gamePassDefinition.gamePassId, Enum.InfoType.GamePass)
		end)

		if not success or type(productInfo) ~= "table" then
			costLabel.Text = PRICE_UNAVAILABLE_TEXT
			return
		end

		local productInfoValues = productInfo :: { [string]: unknown }
		local priceInRobux = productInfoValues.PriceInRobux
		costLabel.Text = if type(priceInRobux) == "number" then formatRobuxPrice(priceInRobux) else PRICE_UNAVAILABLE_TEXT
	end)
end

local function refreshOwnership(button: GuiButtonLike, gamePassDefinition: GamePassDefinition)
	task.spawn(function()
		local localPlayer = getLocalPlayer()
		local success, ownsPass = pcall(function(): boolean
			return MarketplaceService:UserOwnsGamePassAsync(localPlayer.UserId, gamePassDefinition.gamePassId)
		end)

		if not success then
			warn(string.format("[SpecialOfferButtonController] Failed to check Special Offer ownership: %s", tostring(ownsPass)))
			renderButton(button)
			return
		end

		ownsSpecialOffer = ownsPass
		renderButton(button)
	end)
end

local SpecialOfferButtonController = {}

function SpecialOfferButtonController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local offerDefinition = SpecialOfferConfig.getDefinition()
	local gamePassDefinition = GamePassConfig.getSpecialOfferDefinition()
	local button = getButton(offerDefinition.buttonName)
	local costLabel = getCostLabel(button, offerDefinition.costLabelName)

	updateCostText(costLabel, gamePassDefinition)
	refreshOwnership(button, gamePassDefinition)

	button.Activated:Connect(function()
		if ownsSpecialOffer then
			return
		end

		MarketplaceService:PromptGamePassPurchase(getLocalPlayer(), gamePassDefinition.gamePassId)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
		local localPlayer = getLocalPlayer()
		if player ~= localPlayer or gamePassId ~= gamePassDefinition.gamePassId then
			return
		end

		if wasPurchased then
			ownsSpecialOffer = true
			renderButton(button)
			HudNotificationController.showToast(PURCHASE_COMPLETE_TEXT, "Reward")
			return
		end

		refreshOwnership(button, gamePassDefinition)
	end)
end

return table.freeze(SpecialOfferButtonController)

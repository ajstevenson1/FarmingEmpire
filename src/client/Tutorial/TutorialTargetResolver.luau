--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before using TutorialTargetResolver")

local OWNER_USER_ID_ATTRIBUTE = "OwnerUserId"
local ITEM_ID_ATTRIBUTE = "ItemId"
local PLACED_OBJECTS_FOLDER_NAME = "PlacedObjects"
local SHOP_TOUCH_PART_NAME = "Touch"
local SELL_STAND_MODEL_NAME = "CiderSell"

local TutorialTargetResolver = {}

local function getRootGui(): ScreenGui?
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if playerGui == nil then
		return nil
	end

	local rootGui = playerGui:FindFirstChild("GUI")
	if rootGui ~= nil and rootGui:IsA("ScreenGui") then
		return rootGui
	end

	return nil
end

local function findDescendantByName(parent: Instance, name: string): Instance?
	for _, descendant in ipairs(parent:GetDescendants()) do
		if descendant.Name == name then
			return descendant
		end
	end

	return nil
end

local function getButtonsContainer(rootGui: ScreenGui): Instance?
	local hud = rootGui:FindFirstChild("HUD")
	local top = if hud ~= nil then hud:FindFirstChild("Top") else nil
	return if top ~= nil then top:FindFirstChild("Buttons") else nil
end

local function getTeleportButton(rootGui: ScreenGui, buttonName: string): GuiObject?
	local buttonsContainer = getButtonsContainer(rootGui)
	if buttonsContainer == nil then
		return nil
	end

	local button = buttonsContainer:FindFirstChild(buttonName)
	if button ~= nil and button:IsA("GuiObject") then
		return button
	end

	return nil
end

local function getShopBuyButton(rootGui: ScreenGui, shopFrameName: string, productId: string): GuiObject?
	local frames = rootGui:FindFirstChild("Frames")
	if frames == nil then
		return nil
	end

	local shopFrame = frames:FindFirstChild(shopFrameName)
	if shopFrame == nil then
		return nil
	end

	local productRow = shopFrame:FindFirstChild(productId, true)
	if productRow == nil then
		return nil
	end

	local buyButton = findDescendantByName(productRow, "BuyButton")
	if buyButton ~= nil and buyButton:IsA("GuiObject") then
		return buyButton
	end

	return nil
end

local function getFrameButton(rootGui: ScreenGui, frameName: string, buttonName: string): GuiObject?
	local frames = rootGui:FindFirstChild("Frames")
	if frames == nil then
		return nil
	end

	local frame = frames:FindFirstChild(frameName)
	if frame == nil then
		return nil
	end

	local button = frame:FindFirstChild(buttonName, true)
	if button ~= nil and button:IsA("GuiObject") then
		return button
	end

	return nil
end

local function getHotbarItemButton(rootGui: ScreenGui, itemDisplayName: string): GuiObject?
	local hud = rootGui:FindFirstChild("HUD")
	local inventoryHud = if hud ~= nil then hud:FindFirstChild("Inventory") else nil
	local hotbar = if inventoryHud ~= nil then inventoryHud:FindFirstChild("hotBar") else nil
	if hotbar == nil then
		return nil
	end

	for _, child in ipairs(hotbar:GetChildren()) do
		if not child:IsA("GuiObject") or string.sub(child.Name, 1, 4) ~= "Slot" then
			continue
		end

		local toolName = child:FindFirstChild("toolName", true)
		if toolName ~= nil and toolName:IsA("TextLabel") and toolName.Text == itemDisplayName then
			return child
		end
	end

	return nil
end

function TutorialTargetResolver.getGuiTarget(targetName: string): GuiObject?
	local rootGui = getRootGui()
	if rootGui == nil then
		return nil
	end

	if targetName == "ShopTeleportButton" then
		return getTeleportButton(rootGui, "ShopTeleport")
	elseif targetName == "PlotTeleportButton" then
		return getTeleportButton(rootGui, "PlotTeleport")
	elseif targetName == "SellTeleportButton" then
		return getTeleportButton(rootGui, "SellTeleport")
	elseif targetName == "OakTreeBuyButton" then
		return getShopBuyButton(rootGui, "TreesShop", "OakTree")
	elseif targetName == "CiderMillBuyButton" then
		return getShopBuyButton(rootGui, "MillsShop", "CiderMill")
	elseif targetName == "CiderSellButton" then
		return getFrameButton(rootGui, "Sell", "SellButton")
	elseif targetName == "OakTreeHotbar" then
		return getHotbarItemButton(rootGui, "Oak Apple Tree")
	elseif targetName == "ScytheHotbar" then
		return getHotbarItemButton(rootGui, "Scythe")
	end

	return nil
end

local function getShopTarget(shopModelName: string): BasePart?
	local shopModel = Workspace:FindFirstChild(shopModelName)
	if shopModel == nil then
		return nil
	end

	local touchPart = shopModel:FindFirstChild(SHOP_TOUCH_PART_NAME, true)
	if touchPart ~= nil and touchPart:IsA("BasePart") then
		return touchPart
	end

	if shopModel:IsA("Model") then
		local primaryPart = shopModel.PrimaryPart
		if primaryPart ~= nil then
			return primaryPart
		end
	end

	for _, descendant in ipairs(shopModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

function TutorialTargetResolver.getPlacedBuildingTarget(beamTargetName: string): BasePart?
	local itemId: string?
	if beamTargetName == "OakTree" then
		itemId = "OakTree"
	elseif beamTargetName == "CiderMill" then
		itemId = "CiderMill"
	elseif beamTargetName == "TreesShop" then
		return getShopTarget("TreesShop")
	elseif beamTargetName == "MillsShop" then
		return getShopTarget("MillsShop")
	elseif beamTargetName == "SellStand" then
		return getShopTarget(SELL_STAND_MODEL_NAME)
	else
		return nil
	end

	local placedObjectsFolder = Workspace:FindFirstChild(PLACED_OBJECTS_FOLDER_NAME)
	if placedObjectsFolder == nil then
		return nil
	end

	for _, child in ipairs(placedObjectsFolder:GetChildren()) do
		if child:IsA("BasePart")
			and child:GetAttribute(OWNER_USER_ID_ATTRIBUTE) == localPlayer.UserId
			and child:GetAttribute(ITEM_ID_ATTRIBUTE) == itemId
		then
			return child
		end
	end

	return nil
end

return table.freeze(TutorialTargetResolver)

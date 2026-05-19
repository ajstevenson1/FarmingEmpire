--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local plotsFolder = sharedFolder:WaitForChild("Plots") :: Folder
local templatesFolder = ReplicatedStorage:WaitForChild("Templates") :: Folder

local PlotLocator = require(plotsFolder:WaitForChild("PlotLocator") :: ModuleScript)

type GuiAdornee = Attachment | BasePart

type PlotOwnerWidgets = {
	rootGui: BillboardGui,
	avatarImage: ImageLabel,
	playerNameLabel: TextLabel,
	ownerLabel: TextLabel?,
}

export type PlotOwnerBillboardView = {
	_plot: Instance,
	_widgets: PlotOwnerWidgets,
	_destroyed: boolean,
	_renderSerial: number,
	refresh: (self: PlotOwnerBillboardView) -> (),
	destroy: (self: PlotOwnerBillboardView) -> (),
}

local TEMPLATE_NAME = "PlotOwnerBillboard"
local AVATAR_NAME = "Avatar"
local PLAYER_NAME_LABEL_NAME = "PlayerName"
local OWNER_LABEL_NAME = "OwnerLabel"
local OWNER_USER_ID_ATTRIBUTE = PlotLocator.Attributes.ownerUserId
local OWNER_PLAYER_NAME_ATTRIBUTE = PlotLocator.Attributes.ownerPlayerName
local ANCHOR_NAME = "OwnerBillboardAnchor"
local FALLBACK_STUDS_OFFSET = Vector3.new(0, 5, 0)
local OWNER_LABEL_TEXT = "OWNER"
local UNCLAIMED_LABEL_TEXT = "UNCLAIMED"
local BILLBOARD_SIZE = UDim2.fromOffset(320, 185)
local BILLBOARD_MAX_DISTANCE = 150
local OWNER_LABEL_TEXT_COLOR = Color3.fromRGB(190, 255, 190)
local OWNER_LABEL_TEXT_TRANSPARENCY = 0.05
local PLAYER_NAME_TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local PLAYER_NAME_TEXT_STROKE_COLOR = Color3.fromRGB(0, 0, 0)
local PLAYER_NAME_TEXT_STROKE_TRANSPARENCY = 0.2
local PLAYER_NAME_TEXT_STROKE_THICKNESS = 2

local thumbnailImagesByUserId: { [number]: string } = {}

local PlotOwnerBillboardView = {}
PlotOwnerBillboardView.__index = PlotOwnerBillboardView

local function getOwnerUserId(plot: Instance): number?
	local ownerUserId = plot:GetAttribute(OWNER_USER_ID_ATTRIBUTE)
	if type(ownerUserId) == "number" then
		return ownerUserId
	end

	return nil
end

local function getOwnerPlayerName(plot: Instance): string
	local playerName = plot:GetAttribute(OWNER_PLAYER_NAME_ATTRIBUTE)
	if type(playerName) == "string" and playerName ~= "" then
		return playerName
	end

	return "Unknown Player"
end

local function getOwnerDisplayNameAndUsername(ownerUserId: number, fallbackName: string): (string, string)
	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == ownerUserId then
			local username = if player.Name ~= "" then player.Name else fallbackName
			local displayName = if player.DisplayName ~= "" then player.DisplayName else username
			return displayName, username
		end
	end

	return fallbackName, fallbackName
end

local function ensureCorner(parent: Instance, name: string, cornerRadius: UDim): UICorner
	local existingCorner = parent:FindFirstChild(name)
	if existingCorner ~= nil and existingCorner:IsA("UICorner") then
		existingCorner.CornerRadius = cornerRadius
		return existingCorner
	end

	local corner = Instance.new("UICorner")
	corner.Name = name
	corner.CornerRadius = cornerRadius
	corner.Parent = parent
	return corner
end

local function ensureStroke(parent: Instance, name: string, color: Color3, transparency: number, thickness: number): UIStroke
	local existingStroke = parent:FindFirstChild(name)
	if existingStroke ~= nil and existingStroke:IsA("UIStroke") then
		existingStroke.Color = color
		existingStroke.Transparency = transparency
		existingStroke.Thickness = thickness
		return existingStroke
	end

	local stroke = Instance.new("UIStroke")
	stroke.Name = name
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness
	stroke.Parent = parent
	return stroke
end

local function styleRootGui(rootGui: BillboardGui)
	rootGui.Size = BILLBOARD_SIZE
	rootGui.MaxDistance = BILLBOARD_MAX_DISTANCE
	rootGui.AlwaysOnTop = true
	rootGui.LightInfluence = 0
end

local function styleAvatarImage(avatarImage: ImageLabel)
	avatarImage.BackgroundTransparency = 1
	avatarImage.BorderSizePixel = 0
	avatarImage.Visible = true
	avatarImage.Size = UDim2.fromOffset(96, 96)
	avatarImage.Position = UDim2.new(0.5, -48, 0, 32)
	avatarImage.ScaleType = Enum.ScaleType.Fit

	ensureCorner(avatarImage, "RuntimeCorner", UDim.new(1, 0))
end

local function stylePlayerNameLabel(playerNameLabel: TextLabel)
	playerNameLabel.BackgroundTransparency = 1
	playerNameLabel.BorderSizePixel = 0
	playerNameLabel.Visible = true
	playerNameLabel.Size = UDim2.new(1, -32, 0, 40)
	playerNameLabel.Position = UDim2.new(0, 16, 0, 136)
	playerNameLabel.Font = Enum.Font.GothamBold
	playerNameLabel.TextColor3 = PLAYER_NAME_TEXT_COLOR
	playerNameLabel.TextScaled = true
	playerNameLabel.TextWrapped = false

	ensureStroke(
		playerNameLabel,
		"RuntimeStroke",
		PLAYER_NAME_TEXT_STROKE_COLOR,
		PLAYER_NAME_TEXT_STROKE_TRANSPARENCY,
		PLAYER_NAME_TEXT_STROKE_THICKNESS
	)
end

local function styleOwnerLabel(ownerLabel: TextLabel)
	ownerLabel.BackgroundTransparency = 1
	ownerLabel.BorderSizePixel = 0
	ownerLabel.Visible = true
	ownerLabel.Size = UDim2.new(1, -28, 0, 24)
	ownerLabel.Position = UDim2.new(0, 14, 0, 9)
	ownerLabel.Font = Enum.Font.GothamMedium
	ownerLabel.TextColor3 = OWNER_LABEL_TEXT_COLOR
	ownerLabel.TextTransparency = OWNER_LABEL_TEXT_TRANSPARENCY
	ownerLabel.TextScaled = true
	ownerLabel.TextWrapped = false
end

local function getThumbnailImage(userId: number): string
	local cachedImage = thumbnailImagesByUserId[userId]
	if cachedImage ~= nil then
		return cachedImage
	end

	local success, imageOrError = pcall(function(): string
		local content, _isReady = Players:GetUserThumbnailAsync(
			userId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size100x100
		)

		return content
	end)

	if success then
		local image = imageOrError :: string
		thumbnailImagesByUserId[userId] = image
		return image
	end

	warn(string.format("[PlotOwnerBillboardView] Failed to load thumbnail for userId %d: %s", userId, tostring(imageOrError)))
	return ""
end

local function getAdornee(plot: Instance): GuiAdornee?
	local anchor = plot:FindFirstChild(ANCHOR_NAME, true)
	if anchor ~= nil and anchor:IsA("Attachment") then
		return anchor
	end

	return PlotLocator.getPlacementBase(plot)
end

local function createWidgets(plot: Instance): PlotOwnerWidgets
	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "LocalPlayer must exist before creating plot owner billboards")

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local template = templatesFolder:WaitForChild(TEMPLATE_NAME)
	assert(template:IsA("BillboardGui"), string.format("Templates.%s must be a BillboardGui", TEMPLATE_NAME))

	local rootGui = template:Clone() :: BillboardGui
	rootGui.Name = "PlotOwnerBillboard"
	rootGui.Parent = playerGui
	styleRootGui(rootGui)

	local avatarInstance = rootGui:FindFirstChild(AVATAR_NAME, true)
	assert(
		avatarInstance ~= nil and avatarInstance:IsA("ImageLabel"),
		string.format("Templates.%s must contain an ImageLabel named %s", TEMPLATE_NAME, AVATAR_NAME)
	)

	local playerNameInstance = rootGui:FindFirstChild(PLAYER_NAME_LABEL_NAME, true)
	assert(
		playerNameInstance ~= nil and playerNameInstance:IsA("TextLabel"),
		string.format("Templates.%s must contain a TextLabel named %s", TEMPLATE_NAME, PLAYER_NAME_LABEL_NAME)
	)
	stylePlayerNameLabel(playerNameInstance :: TextLabel)
	styleAvatarImage(avatarInstance :: ImageLabel)

	local ownerLabelInstance = rootGui:FindFirstChild(OWNER_LABEL_NAME, true)
	local ownerLabel = if ownerLabelInstance ~= nil and ownerLabelInstance:IsA("TextLabel")
		then ownerLabelInstance :: TextLabel
		else nil
	if ownerLabel ~= nil then
		styleOwnerLabel(ownerLabel)
	end

	local adornee = getAdornee(plot)
	if adornee == nil then
		warn(string.format("[PlotOwnerBillboardView] Plot %s has no placement base or owner anchor.", plot:GetFullName()))
	else
		rootGui.Adornee = adornee
	end

	if adornee ~= nil and adornee:IsA("Attachment") then
		rootGui.StudsOffsetWorldSpace = Vector3.zero
	else
		rootGui.StudsOffsetWorldSpace = FALLBACK_STUDS_OFFSET
	end

	return {
		rootGui = rootGui,
		avatarImage = avatarInstance :: ImageLabel,
		playerNameLabel = playerNameInstance :: TextLabel,
		ownerLabel = ownerLabel,
	}
end

function PlotOwnerBillboardView.new(plot: Instance): PlotOwnerBillboardView
	local self = setmetatable({
		_plot = plot,
		_widgets = createWidgets(plot),
		_destroyed = false,
		_renderSerial = 0,
	}, PlotOwnerBillboardView) :: PlotOwnerBillboardView

	self:refresh()

	return self
end

function PlotOwnerBillboardView:refresh()
	if self._destroyed then
		return
	end

	local adornee = getAdornee(self._plot)
	if adornee ~= nil then
		self._widgets.rootGui.Adornee = adornee
		self._widgets.rootGui.StudsOffsetWorldSpace = if adornee:IsA("Attachment") then Vector3.zero else FALLBACK_STUDS_OFFSET
	end

	local ownerUserId = getOwnerUserId(self._plot)
	if ownerUserId == nil then
		self._renderSerial += 1
		self._widgets.rootGui.Enabled = false
		self._widgets.avatarImage.Image = ""
		self._widgets.playerNameLabel.Text = ""
		if self._widgets.ownerLabel ~= nil then
			self._widgets.ownerLabel.Text = UNCLAIMED_LABEL_TEXT
		end
		return
	end

	local fallbackName = getOwnerPlayerName(self._plot)
	local displayName, username = getOwnerDisplayNameAndUsername(ownerUserId, fallbackName)
	local playerName = if displayName ~= "" then displayName else username

	self._widgets.rootGui.Enabled = true
	self._widgets.avatarImage.Visible = true
	self._widgets.playerNameLabel.Text = playerName
	self._widgets.playerNameLabel.Visible = true
	if self._widgets.ownerLabel ~= nil then
		self._widgets.ownerLabel.Text = OWNER_LABEL_TEXT
		self._widgets.ownerLabel.Visible = true
	end

	local cachedThumbnail = thumbnailImagesByUserId[ownerUserId]
	if cachedThumbnail ~= nil then
		self._widgets.avatarImage.Image = cachedThumbnail
		return
	end

	self._widgets.avatarImage.Image = ""
	self._renderSerial += 1
	local renderSerial = self._renderSerial

	task.spawn(function()
		local thumbnailImage = getThumbnailImage(ownerUserId)
		if self._destroyed then
			return
		end

		if self._renderSerial ~= renderSerial then
			return
		end

		local currentOwnerUserId = getOwnerUserId(self._plot)
		if currentOwnerUserId ~= ownerUserId then
			return
		end

		self._widgets.avatarImage.Image = thumbnailImage
	end)
end

function PlotOwnerBillboardView:destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._widgets.rootGui:Destroy()
end

return table.freeze(PlotOwnerBillboardView)

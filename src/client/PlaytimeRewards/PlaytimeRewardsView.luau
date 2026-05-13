--!strict

local PlaytimeRewardsView = {}

local ROOT_NAME = "GeneratedPlaytimeRewards"
local REWARDS_LIST_NAME = "RewardsList"
local TILE_COUNT = 7

local function addCorner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function addStroke(parent: GuiObject, color: Color3, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = parent
end

local function addPadding(parent: GuiObject, paddingOffset: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, paddingOffset)
	padding.PaddingBottom = UDim.new(0, paddingOffset)
	padding.PaddingLeft = UDim.new(0, paddingOffset)
	padding.PaddingRight = UDim.new(0, paddingOffset)
	padding.Parent = parent
end

local function createLabel(parent: Instance, name: string, textSize: number, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = font
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = false
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = 22
	label.Parent = parent
	return label
end

local function hideExistingPlaceholderChildren(frame: Frame)
	for _, child in ipairs(frame:GetChildren()) do
		if child.Name ~= ROOT_NAME and child:IsA("GuiObject") then
			child.Visible = false
		end
	end
end

local function createHeader(root: Frame)
	local titleLabel = createLabel(root, "TitleLabel", 34, Enum.Font.GothamBlack)
	titleLabel.Size = UDim2.new(1, 0, 0, 52)
	titleLabel.Text = "Rewards are coming"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextStrokeColor3 = Color3.fromRGB(20, 20, 24)
	titleLabel.TextStrokeTransparency = 0.15

	local playtimeLabel = createLabel(root, "PlaytimeLabel", 22, Enum.Font.GothamBold)
	playtimeLabel.Position = UDim2.new(0, 0, 0, 54)
	playtimeLabel.Size = UDim2.new(1, 0, 0, 32)
	playtimeLabel.Text = "Playtime: 00:00"
	playtimeLabel.TextColor3 = Color3.fromRGB(207, 255, 169)

	local statusLabel = createLabel(root, "StatusLabel", 18, Enum.Font.GothamMedium)
	statusLabel.Position = UDim2.new(0, 0, 0, 88)
	statusLabel.Size = UDim2.new(1, 0, 0, 28)

	local nextClaimLabel = createLabel(root, "NextClaimLabel", 16, Enum.Font.GothamMedium)
	nextClaimLabel.Position = UDim2.new(0, 0, 0, 116)
	nextClaimLabel.Size = UDim2.new(1, 0, 0, 24)
	nextClaimLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
end

local function createRewardRow(parent: Instance, rewardIndex: number)
	local row = Instance.new("Frame")
	row.Name = string.format("Reward%d", rewardIndex)
	row.BackgroundColor3 = Color3.fromRGB(42, 45, 48)
	row.BackgroundTransparency = 0
	row.LayoutOrder = rewardIndex
	row.Size = UDim2.new(1, 0, 0, 54)
	row.ZIndex = 21
	row.Parent = parent
	addCorner(row, 6)
	addStroke(row, Color3.fromRGB(20, 20, 24), 2)
	addPadding(row, 8)

	local titleLabel = createLabel(row, "TitleLabel", 16, Enum.Font.GothamBold)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.Size = UDim2.new(0.22, 0, 1, 0)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left

	local rewardLabel = createLabel(row, "RewardLabel", 16, Enum.Font.GothamMedium)
	rewardLabel.Position = UDim2.new(0.22, 0, 0, 0)
	rewardLabel.Size = UDim2.new(0.43, 0, 1, 0)
	rewardLabel.TextXAlignment = Enum.TextXAlignment.Left

	local stateLabel = createLabel(row, "StateLabel", 15, Enum.Font.GothamBlack)
	stateLabel.Position = UDim2.new(0.65, 0, 0, 0)
	stateLabel.Size = UDim2.new(0.35, 0, 1, 0)
	stateLabel.TextXAlignment = Enum.TextXAlignment.Right
end

local function createRewardsList(root: Frame)
	local rewardsList = Instance.new("Frame")
	rewardsList.Name = REWARDS_LIST_NAME
	rewardsList.BackgroundTransparency = 1
	rewardsList.Position = UDim2.new(0, 28, 0, 154)
	rewardsList.Size = UDim2.new(1, -56, 1, -226)
	rewardsList.ZIndex = 21
	rewardsList.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = rewardsList

	for rewardIndex = 1, TILE_COUNT do
		createRewardRow(rewardsList, rewardIndex)
	end
end

local function createClaimButton(root: Frame)
	local button = Instance.new("TextButton")
	button.Name = "ClaimButton"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -18)
	button.Size = UDim2.fromOffset(220, 42)
	button.BackgroundColor3 = Color3.fromRGB(80, 196, 58)
	button.Font = Enum.Font.GothamBlack
	button.Text = "Claim"
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 22
	button.ZIndex = 22
	button.Parent = root
	addCorner(button, 8)
	addStroke(button, Color3.fromRGB(20, 20, 24), 2)
end

local function createRoot(frame: Frame): Frame
	hideExistingPlaceholderChildren(frame)

	frame.BackgroundColor3 = Color3.fromRGB(18, 22, 26)
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true

	local root = Instance.new("Frame")
	root.Name = ROOT_NAME
	root.BackgroundColor3 = Color3.fromRGB(18, 22, 26)
	root.BackgroundTransparency = 0
	root.BorderSizePixel = 0
	root.Position = UDim2.fromScale(0, 0)
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 20
	root.Parent = frame
	addCorner(root, 8)
	addStroke(root, Color3.fromRGB(20, 20, 24), 4)
	addPadding(root, 12)

	createHeader(root)
	createRewardsList(root)
	createClaimButton(root)

	return root
end

function PlaytimeRewardsView.ensure(frame: Frame): Frame
	hideExistingPlaceholderChildren(frame)

	local existingRoot = frame:FindFirstChild(ROOT_NAME)
	if existingRoot ~= nil and existingRoot:IsA("Frame") then
		existingRoot.Visible = true
		return existingRoot
	end

	return createRoot(frame)
end

return table.freeze(PlaytimeRewardsView)

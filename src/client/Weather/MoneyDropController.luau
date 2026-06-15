--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local networkingFolder = sharedFolder:WaitForChild("Networking") :: Folder
local weatherSharedFolder = sharedFolder:WaitForChild("Weather") :: Folder

local RemoteNames = require(networkingFolder:WaitForChild("RemoteNames") :: ModuleScript)
local WeatherTypes = require(weatherSharedFolder:WaitForChild("WeatherTypes") :: ModuleScript)

type MoneyDropSpawnPayload = WeatherTypes.MoneyDropSpawnPayload

type LocalMoneyDrop = {
	id: string,
	model: Model,
	expiresAt: number,
	collectionRadiusStuds: number,
	requestedPickup: boolean,
	label: TextLabel,
	touchConnections: { RBXScriptConnection },
	updateConnection: RBXScriptConnection?,
	pivotValue: CFrameValue?,
	fallHighlight: Highlight?,
}

local LOCAL_DROPS_FOLDER_NAME = "LocalMoneyDrops"
local WEATHER_ASSETS_FOLDER_NAME = "Weather"
local WEATHER_PART_NAME = "WeatherPart"
local RAYCAST_DISTANCE_STUDS = 1000
local FALL_HIGHLIGHT_FILL_COLOR = Color3.fromRGB(255, 226, 84)
local FALL_HIGHLIGHT_OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)

local hasStarted = false
local activeDrops: { [string]: LocalMoneyDrop } = {}
local requestMoneyDropPickupRemote: RemoteEvent? = nil

local function getWeatherRemotes(): (RemoteEvent, RemoteEvent, RemoteEvent)
	local rootFolder = ReplicatedStorage:WaitForChild(RemoteNames.rootFolderName)
	assert(rootFolder:IsA("Folder"), "ReplicatedStorage.GameRemotes must be a Folder")

	local weatherRemoteFolder = rootFolder:WaitForChild(RemoteNames.weatherFolderName)
	assert(weatherRemoteFolder:IsA("Folder"), "GameRemotes.Weather must be a Folder")

	local moneyDropSpawned = weatherRemoteFolder:WaitForChild(RemoteNames.moneyDropSpawnedEventName)
	assert(moneyDropSpawned:IsA("RemoteEvent"), "GameRemotes.Weather.MoneyDropSpawned must be a RemoteEvent")

	local requestMoneyDropPickup = weatherRemoteFolder:WaitForChild(RemoteNames.requestMoneyDropPickupEventName)
	assert(requestMoneyDropPickup:IsA("RemoteEvent"), "GameRemotes.Weather.RequestMoneyDropPickup must be a RemoteEvent")

	local moneyDropResolved = weatherRemoteFolder:WaitForChild(RemoteNames.moneyDropResolvedEventName)
	assert(moneyDropResolved:IsA("RemoteEvent"), "GameRemotes.Weather.MoneyDropResolved must be a RemoteEvent")

	return moneyDropSpawned, requestMoneyDropPickup, moneyDropResolved
end

local function getWeatherAssetsFolder(): Folder
	local folder = ReplicatedStorage:WaitForChild(WEATHER_ASSETS_FOLDER_NAME)
	assert(folder:IsA("Folder"), "ReplicatedStorage.Weather must be a Folder")
	return folder
end

local function getOrCreateLocalDropsFolder(): Folder
	local existing = Workspace:FindFirstChild(LOCAL_DROPS_FOLDER_NAME)
	if existing ~= nil then
		assert(existing:IsA("Folder"), string.format("Workspace.%s must be a Folder", LOCAL_DROPS_FOLDER_NAME))
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = LOCAL_DROPS_FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

local function isMoneyDropSpawnPayload(value: unknown): boolean
	if typeof(value) ~= "table" then
		return false
	end

	local payload = value :: { [string]: unknown }
	return typeof(payload.id) == "string"
		and typeof(payload.tierId) == "string"
		and typeof(payload.modelName) == "string"
		and typeof(payload.rewardCash) == "number"
		and typeof(payload.spawnPosition) == "Vector3"
		and typeof(payload.expiresAt) == "number"
		and typeof(payload.lifetimeSeconds) == "number"
		and typeof(payload.fallSeconds) == "number"
		and typeof(payload.collectionRadiusStuds) == "number"
end

local function findFirstBasePart(root: Instance): BasePart?
	if root:IsA("BasePart") then
		return root
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function prepareDropModel(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = true
		end
	end
end

local function createBillboard(adornee: BasePart): TextLabel
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "MoneyDropTimer"
	billboardGui.Adornee = adornee
	billboardGui.AlwaysOnTop = true
	billboardGui.LightInfluence = 0
	billboardGui.MaxDistance = 450
	billboardGui.Size = UDim2.fromOffset(96, 40)
	billboardGui.StudsOffset = Vector3.new(0, 3, 0)
	billboardGui.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Name = "Countdown"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 234, 85)
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(35, 22, 5)
	label.TextStrokeTransparency = 0.12
	label.Parent = billboardGui

	return label
end

local function getHumanoidRootPart(): BasePart?
	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		return nil
	end

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

local function getLandingPosition(model: Model, spawnPosition: Vector3): Vector3
	local localPlayer = Players.LocalPlayer
	local localDropsFolder = getOrCreateLocalDropsFolder()
	local weatherPart = Workspace:FindFirstChild(WEATHER_PART_NAME)

	local excludedInstances: { Instance } = { localDropsFolder }
	if localPlayer ~= nil and localPlayer.Character ~= nil then
		table.insert(excludedInstances, localPlayer.Character)
	end
	if weatherPart ~= nil then
		table.insert(excludedInstances, weatherPart)
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = excludedInstances

	local result = Workspace:Raycast(spawnPosition, Vector3.new(0, -RAYCAST_DISTANCE_STUDS, 0), raycastParams)
	local _, size = model:GetBoundingBox()
	if result == nil then
		return spawnPosition - Vector3.new(0, 80 - (size.Y * 0.5), 0)
	end

	return result.Position + Vector3.new(0, size.Y * 0.5, 0)
end

local function formatSeconds(expiresAt: number): string
	local remainingSeconds = math.max(0, math.ceil(expiresAt - Workspace:GetServerTimeNow()))
	return string.format("%ds", remainingSeconds)
end

local function requestPickup(drop: LocalMoneyDrop)
	if drop.requestedPickup then
		return
	end

	if Workspace:GetServerTimeNow() >= drop.expiresAt then
		return
	end

	local remote = requestMoneyDropPickupRemote
	if remote == nil then
		return
	end

	drop.requestedPickup = true
	remote:FireServer(drop.id)
end

local function getModelPosition(model: Model): Vector3
	return model:GetPivot().Position
end

local function cleanupDrop(dropId: string)
	local drop = activeDrops[dropId]
	if drop == nil then
		return
	end

	activeDrops[dropId] = nil

	if drop.updateConnection ~= nil then
		drop.updateConnection:Disconnect()
	end

	for _, connection in ipairs(drop.touchConnections) do
		connection:Disconnect()
	end

	if drop.pivotValue ~= nil then
		drop.pivotValue:Destroy()
	end

	if drop.fallHighlight ~= nil then
		drop.fallHighlight:Destroy()
	end

	drop.model:Destroy()
end

local function startDropUpdater(drop: LocalMoneyDrop)
	drop.updateConnection = RunService.Heartbeat:Connect(function()
		local currentTime = Workspace:GetServerTimeNow()
		drop.label.Text = formatSeconds(drop.expiresAt)

		if currentTime >= drop.expiresAt then
			cleanupDrop(drop.id)
			return
		end

		local rootPart = getHumanoidRootPart()
		if rootPart == nil then
			return
		end

		if (rootPart.Position - getModelPosition(drop.model)).Magnitude <= drop.collectionRadiusStuds then
			requestPickup(drop)
		end
	end)
end

local function bindTouchPickup(drop: LocalMoneyDrop)
	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		return
	end

	for _, descendant in ipairs(drop.model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local connection = descendant.Touched:Connect(function(otherPart: BasePart)
				local character = localPlayer.Character
				if character ~= nil and otherPart:IsDescendantOf(character) then
					requestPickup(drop)
				end
			end)
			table.insert(drop.touchConnections, connection)
		end
	end
end

local function createFallHighlight(model: Model): Highlight
	local highlight = Instance.new("Highlight")
	highlight.Name = "FallHighlight"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = FALL_HIGHLIGHT_FILL_COLOR
	highlight.FillTransparency = 0.45
	highlight.OutlineColor = FALL_HIGHLIGHT_OUTLINE_COLOR
	highlight.OutlineTransparency = 0
	highlight.Parent = model

	return highlight
end

local function animateDrop(model: Model, spawnPosition: Vector3, landingPosition: Vector3, fallSeconds: number, highlight: Highlight): CFrameValue
	local startCFrame = CFrame.new(spawnPosition)
	local landingCFrame = CFrame.new(landingPosition)
	model:PivotTo(startCFrame)

	local pivotValue = Instance.new("CFrameValue")
	pivotValue.Value = startCFrame
	pivotValue.Changed:Connect(function(value: CFrame)
		model:PivotTo(value)
	end)

	local tween = TweenService:Create(
		pivotValue,
		TweenInfo.new(math.max(0.1, fallSeconds), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Value = landingCFrame }
	)
	tween:Play()
	tween.Completed:Connect(function()
		if highlight.Parent ~= nil then
			highlight:Destroy()
		end
	end)

	return pivotValue
end

local function spawnLocalDrop(receivedPayload: unknown)
	if not isMoneyDropSpawnPayload(receivedPayload) then
		return
	end

	local payload = receivedPayload :: MoneyDropSpawnPayload
	if activeDrops[payload.id] ~= nil then
		return
	end

	local modelTemplate = getWeatherAssetsFolder():FindFirstChild(payload.modelName)
	if modelTemplate == nil or not modelTemplate:IsA("Model") then
		warn(string.format("ReplicatedStorage.Weather.%s must be a Model for Money weather.", payload.modelName))
		return
	end

	local model = modelTemplate:Clone()
	model.Name = string.format("MoneyDrop_%s", payload.id)
	model.Parent = getOrCreateLocalDropsFolder()
	prepareDropModel(model)

	local adornee = findFirstBasePart(model)
	if adornee == nil then
		model:Destroy()
		warn(string.format("ReplicatedStorage.Weather.%s needs at least one BasePart.", payload.modelName))
		return
	end

	local landingPosition = getLandingPosition(model, payload.spawnPosition)
	local label = createBillboard(adornee)
	label.Text = formatSeconds(payload.expiresAt)
	local fallHighlight = createFallHighlight(model)

	local drop: LocalMoneyDrop = {
		id = payload.id,
		model = model,
		expiresAt = payload.expiresAt,
		collectionRadiusStuds = payload.collectionRadiusStuds,
		requestedPickup = false,
		label = label,
		touchConnections = {},
		updateConnection = nil,
		pivotValue = animateDrop(model, payload.spawnPosition, landingPosition, payload.fallSeconds, fallHighlight),
		fallHighlight = fallHighlight,
	}

	activeDrops[payload.id] = drop
	bindTouchPickup(drop)
	startDropUpdater(drop)
end

local function handleDropResolved(receivedDropId: unknown, _reason: unknown, _rewardCash: unknown)
	if typeof(receivedDropId) ~= "string" then
		return
	end

	cleanupDrop(receivedDropId)
end

local MoneyDropController = {}

function MoneyDropController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local spawnedRemote, pickupRemote, resolvedRemote = getWeatherRemotes()
	requestMoneyDropPickupRemote = pickupRemote

	spawnedRemote.OnClientEvent:Connect(spawnLocalDrop)
	resolvedRemote.OnClientEvent:Connect(handleDropResolved)
end

return table.freeze(MoneyDropController)

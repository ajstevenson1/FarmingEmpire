--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Remotes = require(script.Parent.Parent.Networking.Remotes)

local CIDER_SELL_MODEL_NAME = "CiderSell"
local TOUCH_PART_NAME = "Touch"
local TOUCH_OPEN_DEBOUNCE_SECONDS = 1

local hasStarted = false
local nextAllowedOpenAtByPlayer: { [Player]: number } = {}

local function getCurrentTime(): number
	return os.clock()
end

local function findCiderSellTouchPart(): BasePart?
	local model = Workspace:FindFirstChild(CIDER_SELL_MODEL_NAME)
	if model == nil then
		warn(string.format("[CiderSellService] Missing Workspace.%s.", CIDER_SELL_MODEL_NAME))
		return nil
	end

	local touchPart = model:FindFirstChild(TOUCH_PART_NAME)
	if touchPart == nil then
		warn(string.format("[CiderSellService] Missing %s.%s.", model:GetFullName(), TOUCH_PART_NAME))
		return nil
	end

	if not touchPart:IsA("BasePart") then
		warn(string.format("[CiderSellService] %s must be a BasePart.", touchPart:GetFullName()))
		return nil
	end

	return touchPart
end

local function findPlayerFromTouchedPart(touchedPart: BasePart): Player?
	local current: Instance? = touchedPart
	while current ~= nil and current ~= Workspace do
		if current:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(current)
			if player ~= nil then
				return player
			end
		end

		current = current.Parent
	end

	return nil
end

local function canOpenForPlayer(player: Player): boolean
	local currentTime = getCurrentTime()
	local nextAllowedOpenAt = nextAllowedOpenAtByPlayer[player] or 0
	if currentTime < nextAllowedOpenAt then
		return false
	end

	nextAllowedOpenAtByPlayer[player] = currentTime + TOUCH_OPEN_DEBOUNCE_SECONDS
	return true
end

local function openCiderMarketForPlayer(player: Player)
	if not canOpenForPlayer(player) then
		return
	end

	Remotes.getMarketRemotes().ciderMarketOpened:FireClient(player)
end

local CiderSellService = {}

function CiderSellService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local touchPart = findCiderSellTouchPart()
	if touchPart ~= nil then
		touchPart.Touched:Connect(function(touchedPart: BasePart)
			local player = findPlayerFromTouchedPart(touchedPart)
			if player == nil then
				return
			end

			openCiderMarketForPlayer(player)
		end)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		nextAllowedOpenAtByPlayer[player] = nil
	end)
end

return table.freeze(CiderSellService)

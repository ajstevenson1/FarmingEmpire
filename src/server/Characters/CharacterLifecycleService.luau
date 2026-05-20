--!strict

local Players = game:GetService("Players")

local hasStarted = false

local function loadInitialCharacter(player: Player)
	if player.Character ~= nil then
		return
	end

	player:LoadCharacter()
end

local CharacterLifecycleService = {}

function CharacterLifecycleService.start()
	if hasStarted then
		return
	end

	hasStarted = true
	Players.CharacterAutoLoads = false

	Players.PlayerAdded:Connect(loadInitialCharacter)

	for _, player in ipairs(Players:GetPlayers()) do
		loadInitialCharacter(player)
	end
end

return table.freeze(CharacterLifecycleService)

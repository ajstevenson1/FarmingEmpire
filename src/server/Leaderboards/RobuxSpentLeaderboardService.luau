--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local leaderboardsFolder = sharedFolder:WaitForChild("Leaderboards") :: Folder

local RobuxSpentLeaderboardConfig = require(leaderboardsFolder:WaitForChild("RobuxSpentLeaderboardConfig") :: ModuleScript)
local AccumulatingLeaderboardServiceFactory = require(script.Parent.AccumulatingLeaderboardServiceFactory)

local service = AccumulatingLeaderboardServiceFactory.create(
	RobuxSpentLeaderboardConfig,
	"RobuxSpentLeaderboard",
	"R$",
	"No Robux records yet"
)

local hasStarted = false
local RobuxSpentLeaderboardService = {}

function RobuxSpentLeaderboardService.start()
	if hasStarted then
		return
	end

	hasStarted = true
	service:start()
end

function RobuxSpentLeaderboardService.recordRobuxSpent(player: Player, amount: number)
	service:recordAmount(player, amount)
end

return table.freeze(RobuxSpentLeaderboardService)

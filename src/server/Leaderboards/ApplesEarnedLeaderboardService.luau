--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local leaderboardsFolder = sharedFolder:WaitForChild("Leaderboards") :: Folder
local resourcesFolder = sharedFolder:WaitForChild("Resources") :: Folder

local ApplesEarnedLeaderboardConfig = require(leaderboardsFolder:WaitForChild("ApplesEarnedLeaderboardConfig") :: ModuleScript)
local ResourceTypes = require(resourcesFolder:WaitForChild("ResourceTypes") :: ModuleScript)
local AccumulatingLeaderboardServiceFactory = require(script.Parent.AccumulatingLeaderboardServiceFactory)
local ResourceService = require(script.Parent.Parent.Resources.ResourceService)

type ResourceId = ResourceTypes.ResourceId

local service = AccumulatingLeaderboardServiceFactory.create(
	ApplesEarnedLeaderboardConfig,
	"ApplesEarnedLeaderboard",
	"",
	"No apple records yet"
)

local hasStarted = false
local ApplesEarnedLeaderboardService = {}

function ApplesEarnedLeaderboardService.start()
	if hasStarted then
		return
	end

	hasStarted = true
	service:start()

	ResourceService.observeResourceAdded(function(player: Player, resourceId: ResourceId, amount: number)
		if resourceId == "Apple" then
			service:recordAmount(player, amount)
		end
	end)
end

return table.freeze(ApplesEarnedLeaderboardService)

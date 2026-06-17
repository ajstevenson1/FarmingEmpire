--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local loadingFolder = sharedFolder:WaitForChild("Loading") :: Folder
local LoadingScreenRunner = require(loadingFolder:WaitForChild("LoadingScreenRunner") :: ModuleScript)

local LoadingScreenController = {}

function LoadingScreenController.start()
	task.spawn(function()
		LoadingScreenRunner.start({
			removeDefaultLoadingScreen = false,
		})
	end)
end

return table.freeze(LoadingScreenController)

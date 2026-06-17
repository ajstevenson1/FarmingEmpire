--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local loadingFolder = sharedFolder:WaitForChild("Loading") :: Folder
local LoadingScreenRunner = require(loadingFolder:WaitForChild("LoadingScreenRunner") :: ModuleScript)

LoadingScreenRunner.start({
	removeDefaultLoadingScreen = true,
})

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
assert(localPlayer ~= nil, "LocalPlayer must exist before starting CmdrClientController")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local adminFolder = sharedFolder:WaitForChild("Admin") :: Folder

local AdminConfig = require(adminFolder:WaitForChild("AdminConfig") :: ModuleScript)

local hasStarted = false

local CmdrClientController = {}

function CmdrClientController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local CmdrClient = require(ReplicatedStorage:WaitForChild("CmdrClient") :: ModuleScript)
	CmdrClient.Registry:RegisterHook("BeforeRun", function(context)
		if not AdminConfig.isAdminUserId(context.Executor.UserId) then
			return "You don't have permission to run this command."
		end

		return nil
	end)

	if AdminConfig.isAdminUserId(localPlayer.UserId) then
		CmdrClient:SetActivationKeys({ Enum.KeyCode.F2 })
		CmdrClient:SetEnabled(true)
	else
		CmdrClient:SetActivationKeys({})
		CmdrClient:SetEnabled(false)
	end
end

return table.freeze(CmdrClientController)

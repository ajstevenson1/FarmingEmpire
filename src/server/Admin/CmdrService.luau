--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local adminFolder = sharedFolder:WaitForChild("Admin") :: Folder

local AdminConfig = require(adminFolder:WaitForChild("AdminConfig") :: ModuleScript)
local Cmdr = require(script.Parent.Parent.Vendor.Cmdr)

local hasStarted = false

local CmdrService = {}

function CmdrService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	Cmdr.Registry:RegisterHook("BeforeRun", function(context)
		if not AdminConfig.isAdminUserId(context.Executor.UserId) then
			return "You don't have permission to run this command."
		end

		return nil
	end)

	Cmdr:RegisterDefaultCommands()
	Cmdr:RegisterTypesIn(script.Parent.CmdrTypes)
	Cmdr:RegisterCommandsIn(script.Parent.CmdrCommands)
end

return table.freeze(CmdrService)

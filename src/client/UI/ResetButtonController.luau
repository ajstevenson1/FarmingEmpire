--!strict

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local RETRY_DELAY_SECONDS = 0.25
local MAX_SET_CORE_ATTEMPTS = 40

local hasStarted = false

local function applyResetButtonDisabled(): boolean
	for _attempt = 1, MAX_SET_CORE_ATTEMPTS do
		local success = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if success then
			return true
		end

		task.wait(RETRY_DELAY_SECONDS)
	end

	return false
end

local ResetButtonController = {}

function ResetButtonController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local localPlayer = Players.LocalPlayer
	task.spawn(function()
		if not applyResetButtonDisabled() then
			warn("[ResetButtonController] Failed to disable the reset button.")
		end
	end)

	localPlayer.CharacterAdded:Connect(function()
		task.spawn(applyResetButtonDisabled)
	end)
end

return table.freeze(ResetButtonController)

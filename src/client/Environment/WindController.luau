--!strict

local WindLineView = require(script.Parent.WindLineView)

local hasStarted = false
local windLineView: WindLineView.WindLineView? = nil

local WindController = {}

function WindController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local view = WindLineView.new()
	windLineView = view
	view:start()
end

return table.freeze(WindController)

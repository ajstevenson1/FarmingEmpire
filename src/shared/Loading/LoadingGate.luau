--!strict

export type LoadingGate = {
	isCleared: () -> boolean,
	tryBeginLoading: () -> boolean,
	markCleared: () -> (),
	waitUntilCleared: (timeoutSeconds: number?) -> boolean,
}

local cleared = false
local loadingStarted = false

local LoadingGate = {} :: LoadingGate

function LoadingGate.isCleared(): boolean
	return cleared
end

function LoadingGate.tryBeginLoading(): boolean
	if cleared or loadingStarted then
		return false
	end

	loadingStarted = true
	return true
end

function LoadingGate.markCleared()
	cleared = true
end

function LoadingGate.waitUntilCleared(timeoutSeconds: number?): boolean
	if cleared then
		return true
	end

	local startedAt = os.clock()
	while not cleared do
		if timeoutSeconds ~= nil and os.clock() - startedAt >= timeoutSeconds then
			return false
		end

		task.wait()
	end

	return true
end

return table.freeze(LoadingGate)

--!strict

local TweenService = game:GetService("TweenService")

export type FrameId = string
export type FrameGroupId = string

export type FrameRegistration = {
	id: FrameId,
	frame: GuiObject,
	group: FrameGroupId?,
	defaultOpen: boolean?,
	openPosition: UDim2?,
	closedPosition: UDim2?,
	tweenInfo: TweenInfo?,
	hideWhenClosed: boolean?,
}

type FrameObserver = (frameId: FrameId) -> ()
type FrameStateObserver = (isOpen: boolean) -> ()

type RegisteredFrameState = {
	id: FrameId,
	frame: GuiObject,
	group: FrameGroupId?,
	openPosition: UDim2,
	closedPosition: UDim2,
	tweenInfo: TweenInfo,
	hideWhenClosed: boolean,
	isOpen: boolean,
	activeTween: Tween?,
	tweenCompletedConnection: RBXScriptConnection?,
	destroyingConnection: RBXScriptConnection?,
}

export type FrameManager = {
	registerFrame: (registration: FrameRegistration) -> (),
	unregisterFrame: (frameId: FrameId) -> (),
	open: (frameId: FrameId) -> (),
	close: (frameId: FrameId) -> (),
	toggle: (frameId: FrameId) -> (),
	closeAll: (group: FrameGroupId?) -> (),
	isOpen: (frameId: FrameId) -> boolean,
	isTransitioning: (frameId: FrameId?) -> boolean,
	getOpenFrame: (group: FrameGroupId) -> FrameId?,
	getFrameIdForInstance: (instance: Instance) -> FrameId?,
	observeFrameOpened: (callback: FrameObserver) -> (),
	observeFrameClosed: (callback: FrameObserver) -> (),
	observeFrameState: (frameId: FrameId, callback: FrameStateObserver) -> (),
}

local DEFAULT_TWEEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local framesById: { [FrameId]: RegisteredFrameState } = {}
local openFrameIdsByGroup: { [FrameGroupId]: FrameId } = {}
local frameOpenedObservers: { FrameObserver } = {}
local frameClosedObservers: { FrameObserver } = {}
local frameStateObserversById: { [FrameId]: { FrameStateObserver } } = {}

local function publishFrameState(frameId: FrameId, isOpen: boolean)
	local frameStateObservers = frameStateObserversById[frameId]
	if frameStateObservers == nil then
		return
	end

	for _, observer in ipairs(frameStateObservers) do
		task.spawn(observer, isOpen)
	end
end

local function publishFrameOpened(frameId: FrameId)
	for _, observer in ipairs(frameOpenedObservers) do
		task.spawn(observer, frameId)
	end

	publishFrameState(frameId, true)
end

local function publishFrameClosed(frameId: FrameId)
	for _, observer in ipairs(frameClosedObservers) do
		task.spawn(observer, frameId)
	end

	publishFrameState(frameId, false)
end

local function clearActiveTween(frameState: RegisteredFrameState)
	local tweenCompletedConnection = frameState.tweenCompletedConnection
	if tweenCompletedConnection ~= nil then
		tweenCompletedConnection:Disconnect()
		frameState.tweenCompletedConnection = nil
	end

	frameState.activeTween = nil
end

local function cancelActiveTween(frameState: RegisteredFrameState)
	local activeTween = frameState.activeTween
	if activeTween ~= nil then
		activeTween:Cancel()
	end

	clearActiveTween(frameState)
end

local function playTransition(frameState: RegisteredFrameState, targetPosition: UDim2, shouldBeVisibleAfterTransition: boolean)
	cancelActiveTween(frameState)

	frameState.frame.Visible = true
	local tween = TweenService:Create(frameState.frame, frameState.tweenInfo, {
		Position = targetPosition,
	})

	frameState.activeTween = tween
	frameState.tweenCompletedConnection = tween.Completed:Connect(function()
		clearActiveTween(frameState)
		if not shouldBeVisibleAfterTransition and frameState.hideWhenClosed then
			frameState.frame.Visible = false
		end
	end)

	tween:Play()
end

local function getFrameStateOrError(frameId: FrameId): RegisteredFrameState
	local frameState = framesById[frameId]
	assert(frameState ~= nil, string.format("FrameManager frame %q is not registered", frameId))
	return frameState
end

local function setGroupOpenFrame(group: FrameGroupId?, frameId: FrameId?)
	if group == nil then
		return
	end

	if frameId == nil then
		openFrameIdsByGroup[group] = nil
		return
	end

	openFrameIdsByGroup[group] = frameId
end

local FrameManager = {} :: FrameManager

function FrameManager.registerFrame(registration: FrameRegistration)
	assert(framesById[registration.id] == nil, string.format("FrameManager frame %q is already registered", registration.id))

	if registration.defaultOpen == true and registration.group ~= nil then
		local openFrameId = openFrameIdsByGroup[registration.group]
		if openFrameId ~= nil and openFrameId ~= registration.id then
			FrameManager.close(openFrameId)
		end
	end

	local openPosition = registration.openPosition or registration.frame.Position
	local closedPosition = registration.closedPosition or openPosition
	local hideWhenClosed = if registration.hideWhenClosed == nil then true else registration.hideWhenClosed
	local isOpen = registration.defaultOpen == true
	local frameState: RegisteredFrameState = {
		id = registration.id,
		frame = registration.frame,
		group = registration.group,
		openPosition = openPosition,
		closedPosition = closedPosition,
		tweenInfo = registration.tweenInfo or DEFAULT_TWEEN_INFO,
		hideWhenClosed = hideWhenClosed,
		isOpen = isOpen,
		activeTween = nil,
		tweenCompletedConnection = nil,
		destroyingConnection = nil,
	}

	registration.frame.Position = if isOpen then openPosition else closedPosition
	registration.frame.Visible = if isOpen then true else not hideWhenClosed
	framesById[registration.id] = frameState

	if isOpen and registration.group ~= nil then
		setGroupOpenFrame(registration.group, registration.id)
	end

	frameState.destroyingConnection = registration.frame.Destroying:Connect(function()
		FrameManager.unregisterFrame(registration.id)
	end)
end

function FrameManager.unregisterFrame(frameId: FrameId)
	local frameState = framesById[frameId]
	if frameState == nil then
		return
	end

	cancelActiveTween(frameState)

	local destroyingConnection = frameState.destroyingConnection
	if destroyingConnection ~= nil then
		destroyingConnection:Disconnect()
		frameState.destroyingConnection = nil
	end

	if frameState.group ~= nil and openFrameIdsByGroup[frameState.group] == frameId then
		openFrameIdsByGroup[frameState.group] = nil
	end

	framesById[frameId] = nil
	frameStateObserversById[frameId] = nil
end

function FrameManager.open(frameId: FrameId)
	local frameState = getFrameStateOrError(frameId)
	if frameState.isOpen then
		return
	end

	local group = frameState.group
	if group ~= nil then
		local openFrameId = openFrameIdsByGroup[group]
		if openFrameId ~= nil and openFrameId ~= frameId then
			FrameManager.close(openFrameId)
		end
	end

	frameState.isOpen = true
	setGroupOpenFrame(group, frameId)
	playTransition(frameState, frameState.openPosition, true)
	publishFrameOpened(frameId)
end

function FrameManager.close(frameId: FrameId)
	local frameState = getFrameStateOrError(frameId)
	if not frameState.isOpen then
		return
	end

	frameState.isOpen = false
	if frameState.group ~= nil and openFrameIdsByGroup[frameState.group] == frameId then
		openFrameIdsByGroup[frameState.group] = nil
	end

	playTransition(frameState, frameState.closedPosition, false)
	publishFrameClosed(frameId)
end

function FrameManager.toggle(frameId: FrameId)
	if FrameManager.isOpen(frameId) then
		FrameManager.close(frameId)
	else
		FrameManager.open(frameId)
	end
end

function FrameManager.closeAll(group: FrameGroupId?)
	if group ~= nil then
		local openFrameId = openFrameIdsByGroup[group]
		if openFrameId ~= nil then
			FrameManager.close(openFrameId)
		end
		return
	end

	for frameId, frameState in pairs(framesById) do
		if frameState.isOpen then
			FrameManager.close(frameId)
		end
	end
end

function FrameManager.isOpen(frameId: FrameId): boolean
	return getFrameStateOrError(frameId).isOpen
end

function FrameManager.isTransitioning(frameId: FrameId?): boolean
	if frameId ~= nil then
		return getFrameStateOrError(frameId).activeTween ~= nil
	end

	for _, frameState in pairs(framesById) do
		if frameState.activeTween ~= nil then
			return true
		end
	end

	return false
end

function FrameManager.getOpenFrame(group: FrameGroupId): FrameId?
	return openFrameIdsByGroup[group]
end

function FrameManager.getFrameIdForInstance(instance: Instance): FrameId?
	local current: Instance? = instance
	while current ~= nil do
		for frameId, frameState in pairs(framesById) do
			if frameState.frame == current then
				return frameId
			end
		end

		current = current.Parent
	end

	return nil
end

function FrameManager.observeFrameOpened(callback: FrameObserver)
	table.insert(frameOpenedObservers, callback)
end

function FrameManager.observeFrameClosed(callback: FrameObserver)
	table.insert(frameClosedObservers, callback)
end

function FrameManager.observeFrameState(frameId: FrameId, callback: FrameStateObserver)
	if frameStateObserversById[frameId] == nil then
		frameStateObserversById[frameId] = { callback }
	else
		table.insert(frameStateObserversById[frameId], callback)
	end

	callback(FrameManager.isOpen(frameId))
end

return table.freeze(FrameManager)

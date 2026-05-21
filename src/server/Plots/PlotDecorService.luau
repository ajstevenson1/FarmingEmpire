--!strict

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local plotsFolder = sharedFolder:WaitForChild("Plots") :: Folder

local PlotExpansionConfig = require(plotsFolder:WaitForChild("PlotExpansionConfig") :: ModuleScript)
local PlotExpansionTypes = require(plotsFolder:WaitForChild("PlotExpansionTypes") :: ModuleScript)
local PlotExpansionUtils = require(plotsFolder:WaitForChild("PlotExpansionUtils") :: ModuleScript)
local PlotLocator = require(plotsFolder:WaitForChild("PlotLocator") :: ModuleScript)
local PlotExpansionService = require(script.Parent.PlotExpansionService)
local PlotService = require(script.Parent.PlotService)

type PlotExpansionSnapshot = PlotExpansionTypes.PlotExpansionSnapshot
type PlotTileSnapshot = PlotExpansionTypes.PlotTileSnapshot
type DecorKind = "Tree" | "Rock"

type PlotDecorRecord = {
	plot: Instance,
	tileKey: string,
	kind: DecorKind,
	template: Instance,
	liveInstance: Instance?,
	originalParent: Instance,
	originalName: string,
	isClearing: boolean,
}

local DECOR_FOLDER_NAME = "Decor"
local VFX_FOLDER_NAME = "VFX"
local DUST_EMITTER_NAME = "Dust"
local TREE_TAG = "Tree"
local ROCK_TAG = "Rock"
local OWNER_USER_ID_ATTRIBUTE = PlotLocator.Attributes.ownerUserId
local DUST_PART_NAME = "PlotUnlockDust"
local UNLOCK_SOUND_ID = "rbxassetid://135565294412723"
local UNLOCK_SOUND_VOLUME = 0.8
local DUST_PART_HEIGHT_STUDS = 0.2
local DUST_HEIGHT_OFFSET_STUDS = 0.15
local DUST_DURATION_SECONDS = 3
local TREE_FALL_SECONDS = 3
local TREE_FALL_ANGLE_DEGREES = 88
local ROCK_CLEAR_SECONDS = 3
local ROCK_SHAKE_SECONDS = 1.35
local ROCK_SHAKE_DISTANCE_STUDS = 0.18
local ROCK_SHAKE_ROTATION_DEGREES = 4
local ROCK_SINK_DEPTH_STUDS = 5

local workspacePlotsFolder = Workspace:WaitForChild(PlotLocator.PLOTS_FOLDER_NAME) :: Folder
local dustEmitterTemplate = ReplicatedStorage:WaitForChild(VFX_FOLDER_NAME):WaitForChild(DUST_EMITTER_NAME) :: ParticleEmitter
local rng = Random.new()
local hasStarted = false
local recordsByPlot: { [Instance]: { PlotDecorRecord } } = {}
local previousUnlockedTilesByPlayer: { [Player]: { [string]: boolean } } = {}

local function getUnlockedLookup(snapshot: PlotExpansionSnapshot): { [string]: boolean }
	local unlockedLookup: { [string]: boolean } = {}
	for _, tileSnapshot: PlotTileSnapshot in ipairs(snapshot.tiles) do
		if tileSnapshot.isUnlocked then
			unlockedLookup[PlotExpansionUtils.getTileKey(tileSnapshot.row, tileSnapshot.column)] = true
		end
	end

	return unlockedLookup
end

local function getDecorKind(instance: Instance): DecorKind?
	if CollectionService:HasTag(instance, TREE_TAG) then
		return "Tree"
	end

	if CollectionService:HasTag(instance, ROCK_TAG) then
		return "Rock"
	end

	return nil
end

local function getDecorPosition(instance: Instance): Vector3?
	if instance:IsA("Model") then
		local boundingBoxCFrame = instance:GetBoundingBox()
		return boundingBoxCFrame.Position
	end

	if instance:IsA("BasePart") then
		return instance.Position
	end

	return nil
end

local function getDecorParts(instance: Instance): { BasePart }
	local parts: { BasePart } = {}
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
		return parts
	end

	if not instance:IsA("Model") then
		return parts
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function prepareDecorForAnimation(instance: Instance): { BasePart }
	local parts = getDecorParts(instance)
	for _, part in ipairs(parts) do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
	end

	return parts
end

local function getDecorBoundingBox(instance: Instance): (CFrame?, Vector3?)
	if instance:IsA("Model") then
		local boundingBoxCFrame, boundingBoxSize = instance:GetBoundingBox()
		return boundingBoxCFrame, boundingBoxSize
	end

	if instance:IsA("BasePart") then
		return instance.CFrame, instance.Size
	end

	return nil, nil
end

local function capturePartCFrames(parts: { BasePart }): { [BasePart]: CFrame }
	local cFrames: { [BasePart]: CFrame } = {}
	for _, part in ipairs(parts) do
		cFrames[part] = part.CFrame
	end

	return cFrames
end

local function applyTransformToParts(parts: { BasePart }, originalCFrames: { [BasePart]: CFrame }, transform: CFrame)
	for _, part in ipairs(parts) do
		if part.Parent ~= nil then
			local originalCFrame = originalCFrames[part]
			if originalCFrame ~= nil then
				part.CFrame = transform * originalCFrame
			end
		end
	end
end

local function getTileKeyForDecor(plotBase: BasePart, spawnPart: BasePart, decor: Instance): string?
	local decorPosition = getDecorPosition(decor)
	if decorPosition == nil then
		return nil
	end

	local localPosition = plotBase.CFrame:PointToObjectSpace(decorPosition)
	local tileCoordinate = PlotExpansionUtils.getTileCoordinateForGridPosition(
		plotBase,
		spawnPart,
		localPosition.X,
		localPosition.Z
	)
	if tileCoordinate == nil then
		return nil
	end

	return PlotExpansionUtils.getTileKey(tileCoordinate.row, tileCoordinate.column)
end

local function addDecorRecord(
	records: { PlotDecorRecord },
	seenDecor: { [Instance]: boolean },
	plot: Instance,
	plotBase: BasePart,
	spawnPart: BasePart,
	decor: Instance
)
	if seenDecor[decor] == true then
		return
	end

	local kind = getDecorKind(decor)
	if kind == nil then
		return
	end

	local tileKey = getTileKeyForDecor(plotBase, spawnPart, decor)
	if tileKey == nil then
		return
	end

	seenDecor[decor] = true
	table.insert(records, {
		plot = plot,
		tileKey = tileKey,
		kind = kind,
		template = decor:Clone(),
		liveInstance = decor,
		originalParent = decor.Parent :: Instance,
		originalName = decor.Name,
		isClearing = false,
	})
end

local function buildPlotDecorRecords(plot: Instance): { PlotDecorRecord }
	local decorFolder = plot:FindFirstChild(DECOR_FOLDER_NAME)
	if decorFolder == nil then
		return {}
	end

	local plotBase = PlotLocator.getPlacementBase(plot)
	local spawnPart = PlotLocator.getSpawnPart(plot)
	if plotBase == nil or spawnPart == nil then
		return {}
	end

	local records: { PlotDecorRecord } = {}
	local seenDecor: { [Instance]: boolean } = {}
	for _, child in ipairs(decorFolder:GetChildren()) do
		addDecorRecord(records, seenDecor, plot, plotBase, spawnPart, child)
	end

	for _, decor in ipairs(CollectionService:GetTagged(TREE_TAG)) do
		if decor:IsDescendantOf(decorFolder) then
			addDecorRecord(records, seenDecor, plot, plotBase, spawnPart, decor)
		end
	end

	for _, decor in ipairs(CollectionService:GetTagged(ROCK_TAG)) do
		if decor:IsDescendantOf(decorFolder) then
			addDecorRecord(records, seenDecor, plot, plotBase, spawnPart, decor)
		end
	end

	return records
end

local function ensureDecorLive(record: PlotDecorRecord)
	local liveInstance = record.liveInstance
	if record.isClearing then
		if liveInstance ~= nil and liveInstance.Parent ~= nil then
			liveInstance:Destroy()
		end

		record.liveInstance = nil
		record.isClearing = false
		liveInstance = nil
	end

	if liveInstance ~= nil and liveInstance.Parent ~= nil then
		return
	end

	local clone = record.template:Clone()
	clone.Name = record.originalName
	clone.Parent = record.originalParent
	record.liveInstance = clone
	record.isClearing = false
end

local function removeDecorImmediately(record: PlotDecorRecord)
	local liveInstance = record.liveInstance
	if liveInstance ~= nil and liveInstance.Parent ~= nil then
		liveInstance:Destroy()
	end

	record.liveInstance = nil
	record.isClearing = false
end

local function removeAnimatedDecor(record: PlotDecorRecord, animatedInstance: Instance)
	if animatedInstance.Parent ~= nil then
		animatedInstance:Destroy()
	end

	if record.liveInstance == animatedInstance then
		record.liveInstance = nil
		record.isClearing = false
	end
end

local function playDustEffect(plot: Instance, tileKey: string)
	local plotBase = PlotLocator.getPlacementBase(plot)
	local spawnPart = PlotLocator.getSpawnPart(plot)
	if plotBase == nil or spawnPart == nil then
		return
	end

	local rowText, columnText = string.match(tileKey, "^(%d+):(%d+)$")
	local row = if rowText == nil then nil else tonumber(rowText)
	local column = if columnText == nil then nil else tonumber(columnText)
	if row == nil or column == nil then
		return
	end

	local centerCFrame = PlotExpansionUtils.getTileCenterCFrame(
		plotBase,
		spawnPart,
		row,
		column,
		DUST_HEIGHT_OFFSET_STUDS
	)
	if centerCFrame == nil then
		return
	end

	local dustPart = Instance.new("Part")
	dustPart.Name = DUST_PART_NAME
	dustPart.Anchored = true
	dustPart.CanCollide = false
	dustPart.CanQuery = false
	dustPart.CanTouch = false
	dustPart.Transparency = 1
	dustPart.Size = Vector3.new(
		PlotExpansionConfig.getTileSizeStuds(),
		DUST_PART_HEIGHT_STUDS,
		PlotExpansionConfig.getTileSizeStuds()
	)
	dustPart.CFrame = centerCFrame
	dustPart.Parent = plot

	local dustEmitter = dustEmitterTemplate:Clone()
	dustEmitter.Enabled = true
	dustEmitter.Parent = dustPart

	local unlockSound = Instance.new("Sound")
	unlockSound.Name = "PlotUnlockSound"
	unlockSound.SoundId = UNLOCK_SOUND_ID
	unlockSound.Volume = UNLOCK_SOUND_VOLUME
	unlockSound.Parent = dustPart
	unlockSound:Play()

	Debris:AddItem(dustPart, DUST_DURATION_SECONDS)
end

local function clearTree(record: PlotDecorRecord, liveInstance: Instance)
	local boundingBoxCFrame, boundingBoxSize = getDecorBoundingBox(liveInstance)
	if boundingBoxCFrame == nil or boundingBoxSize == nil then
		removeDecorImmediately(record)
		return
	end

	local parts = prepareDecorForAnimation(liveInstance)
	if #parts == 0 then
		removeDecorImmediately(record)
		return
	end

	local originalCFrames = capturePartCFrames(parts)
	local fallDirection = if rng:NextInteger(0, 1) == 0 then boundingBoxCFrame.RightVector else boundingBoxCFrame.LookVector
	if rng:NextInteger(0, 1) == 0 then
		fallDirection = -fallDirection
	end

	local upDirection = boundingBoxCFrame.UpVector
	local hingeAxis = upDirection:Cross(fallDirection)
	if hingeAxis.Magnitude <= 0.001 then
		hingeAxis = Vector3.xAxis
	else
		hingeAxis = hingeAxis.Unit
	end

	local halfFallExtent = math.abs(fallDirection:Dot(boundingBoxCFrame.RightVector)) * boundingBoxSize.X * 0.5
		+ math.abs(fallDirection:Dot(boundingBoxCFrame.LookVector)) * boundingBoxSize.Z * 0.5
	local hingePoint = boundingBoxCFrame.Position - (upDirection * boundingBoxSize.Y * 0.5) - (fallDirection * halfFallExtent)
	local progressValue = Instance.new("NumberValue")
	progressValue.Value = 0

	local connection = progressValue:GetPropertyChangedSignal("Value"):Connect(function()
		if liveInstance.Parent == nil then
			return
		end

		local angle = math.rad(TREE_FALL_ANGLE_DEGREES) * progressValue.Value
		local rotation = CFrame.fromAxisAngle(hingeAxis, angle)
		local transform = CFrame.new(hingePoint) * rotation * CFrame.new(-hingePoint)
		applyTransformToParts(parts, originalCFrames, transform)
	end)

	local tween = TweenService:Create(
		progressValue,
		TweenInfo.new(TREE_FALL_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{
			Value = 1,
		}
	)
	tween.Completed:Connect(function()
		connection:Disconnect()
		progressValue:Destroy()
		removeAnimatedDecor(record, liveInstance)
	end)
	tween:Play()
end

local function clearRock(record: PlotDecorRecord, liveInstance: Instance)
	local boundingBoxCFrame, _boundingBoxSize = getDecorBoundingBox(liveInstance)
	if boundingBoxCFrame == nil then
		removeDecorImmediately(record)
		return
	end

	local parts = prepareDecorForAnimation(liveInstance)
	if #parts == 0 then
		removeDecorImmediately(record)
		return
	end

	local originalCFrames = capturePartCFrames(parts)
	local center = boundingBoxCFrame.Position
	local rightVector = boundingBoxCFrame.RightVector
	local lookVector = boundingBoxCFrame.LookVector
	local shakeEndProgress = ROCK_SHAKE_SECONDS / ROCK_CLEAR_SECONDS
	local progressValue = Instance.new("NumberValue")
	progressValue.Value = 0

	local connection = progressValue:GetPropertyChangedSignal("Value"):Connect(function()
		if liveInstance.Parent == nil then
			return
		end

		local progress = progressValue.Value
		local shakeProgress = math.clamp(progress / shakeEndProgress, 0, 1)
		local sinkProgress = math.clamp((progress - shakeEndProgress) / (1 - shakeEndProgress), 0, 1)
		local easedSinkProgress = sinkProgress * sinkProgress * (3 - (2 * sinkProgress))
		local shakeFade = 1 - shakeProgress
		local shakeAngle = math.sin(shakeProgress * math.pi * 10) * ROCK_SHAKE_ROTATION_DEGREES * shakeFade
		local shakeOffset = (
			rightVector * math.sin(shakeProgress * math.pi * 12)
			+ lookVector * math.sin(shakeProgress * math.pi * 9)
		) * ROCK_SHAKE_DISTANCE_STUDS * shakeFade
		local sinkOffset = Vector3.new(0, -ROCK_SINK_DEPTH_STUDS * easedSinkProgress, 0)
		local rotation = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(shakeAngle))
		local transform = CFrame.new(sinkOffset + shakeOffset)
			* CFrame.new(center)
			* rotation
			* CFrame.new(-center)
		applyTransformToParts(parts, originalCFrames, transform)
	end)

	local tween = TweenService:Create(
		progressValue,
		TweenInfo.new(ROCK_CLEAR_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
		{
			Value = 1,
		}
	)
	tween.Completed:Connect(function()
		connection:Disconnect()
		progressValue:Destroy()
		removeAnimatedDecor(record, liveInstance)
	end)
	tween:Play()
end

local function clearDecorWithAnimation(record: PlotDecorRecord)
	if record.isClearing then
		return
	end

	local liveInstance = record.liveInstance
	if liveInstance == nil or liveInstance.Parent == nil then
		record.liveInstance = nil
		record.isClearing = false
		return
	end

	record.isClearing = true
	if record.kind == "Tree" then
		clearTree(record, liveInstance)
	else
		clearRock(record, liveInstance)
	end
end

local function syncPlotDecor(plot: Instance, unlockedLookup: { [string]: boolean }, animateNewUnlocks: { [string]: boolean }?)
	local records = recordsByPlot[plot]
	if records == nil then
		return
	end

	if animateNewUnlocks ~= nil then
		for tileKey in pairs(animateNewUnlocks) do
			playDustEffect(plot, tileKey)
		end
	end

	for _, record in ipairs(records) do
		if unlockedLookup[record.tileKey] == true then
			if animateNewUnlocks ~= nil and animateNewUnlocks[record.tileKey] == true then
				clearDecorWithAnimation(record)
			else
				removeDecorImmediately(record)
			end
		else
			ensureDecorLive(record)
		end
	end
end

local function syncPlotForOwner(plot: Instance)
	local ownerUserId = PlotLocator.getOwnerUserId(plot)
	if ownerUserId == nil then
		syncPlotDecor(plot, {}, nil)
		return
	end

	local ownerPlayer = Players:GetPlayerByUserId(ownerUserId)
	if ownerPlayer == nil then
		syncPlotDecor(plot, {}, nil)
		return
	end

	local snapshot = PlotExpansionService.getSnapshot(ownerPlayer)
	local unlockedLookup = getUnlockedLookup(snapshot)
	previousUnlockedTilesByPlayer[ownerPlayer] = unlockedLookup
	syncPlotDecor(plot, unlockedLookup, nil)
end

local function handlePlotExpansionChanged(player: Player)
	local plot = PlotService.getAssignedPlot(player)
	if plot == nil then
		return
	end

	local snapshot = PlotExpansionService.getSnapshot(player)
	local unlockedLookup = getUnlockedLookup(snapshot)
	local previousUnlockedLookup = previousUnlockedTilesByPlayer[player]
	previousUnlockedTilesByPlayer[player] = unlockedLookup

	if previousUnlockedLookup == nil then
		syncPlotDecor(plot, unlockedLookup, nil)
		return
	end

	local newlyUnlockedTiles: { [string]: boolean } = {}
	for tileKey in pairs(unlockedLookup) do
		if previousUnlockedLookup[tileKey] ~= true then
			newlyUnlockedTiles[tileKey] = true
		end
	end

	syncPlotDecor(plot, unlockedLookup, newlyUnlockedTiles)
end

local function connectPlot(plot: Instance)
	recordsByPlot[plot] = buildPlotDecorRecords(plot)

	plot:GetAttributeChangedSignal(OWNER_USER_ID_ATTRIBUTE):Connect(function()
		task.defer(function()
			syncPlotForOwner(plot)
		end)
	end)

	syncPlotForOwner(plot)
end

local PlotDecorService = {}

function PlotDecorService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	for _, plot in ipairs(PlotLocator.getAllPlots(workspacePlotsFolder)) do
		connectPlot(plot)
	end

	PlotExpansionService.observeChanged(handlePlotExpansionChanged)

	Players.PlayerRemoving:Connect(function(player: Player)
		previousUnlockedTilesByPlayer[player] = nil
	end)
end

return table.freeze(PlotDecorService)

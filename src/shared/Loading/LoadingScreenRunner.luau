--!strict

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LoadingGate = require(script.Parent.LoadingGate)
local LoadingScreenConfig = require(script.Parent.LoadingScreenConfig)
local LoadingScreenView = require(script.Parent.LoadingScreenView)

type AssetProgress = {
	loadedCount: number,
	totalCount: number,
}

type ContentIdSet = { [string]: boolean }

export type LoadingScreenRunnerOptions = {
	removeDefaultLoadingScreen: boolean?,
}

local LoadingScreenRunner = {}

local function addContentId(contentIds: { string }, seenContentIds: ContentIdSet, contentId: string)
	if contentId == "" or seenContentIds[contentId] == true then
		return
	end

	seenContentIds[contentId] = true
	table.insert(contentIds, contentId)
end

local function collectAssetInstances(roots: { Instance }): { Instance }
	local assetInstances: { Instance } = {}
	for _, root in ipairs(roots) do
		table.insert(assetInstances, root)
		for _, descendant in ipairs(root:GetDescendants()) do
			table.insert(assetInstances, descendant)
		end
	end

	return assetInstances
end

local function collectPreloadContentIds(playerGui: PlayerGui): { string }
	local contentIds: { string } = {}
	local seenContentIds: ContentIdSet = {}
	local roots: { Instance } = {
		ReplicatedStorage,
		Workspace,
		playerGui,
	}

	addContentId(contentIds, seenContentIds, LoadingScreenConfig.AssetImageId)

	for _, instance in ipairs(collectAssetInstances(roots)) do
		if instance:IsA("Decal") then
			addContentId(contentIds, seenContentIds, (instance :: Decal).Texture)
		elseif instance:IsA("Texture") then
			addContentId(contentIds, seenContentIds, (instance :: Texture).Texture)
		elseif instance:IsA("ImageLabel") then
			addContentId(contentIds, seenContentIds, (instance :: ImageLabel).Image)
		elseif instance:IsA("ImageButton") then
			addContentId(contentIds, seenContentIds, (instance :: ImageButton).Image)
		elseif instance:IsA("MeshPart") then
			local meshPart = instance :: MeshPart
			addContentId(contentIds, seenContentIds, meshPart.MeshId)
			addContentId(contentIds, seenContentIds, meshPart.TextureID)
		elseif instance:IsA("SpecialMesh") then
			local specialMesh = instance :: SpecialMesh
			addContentId(contentIds, seenContentIds, specialMesh.MeshId)
			addContentId(contentIds, seenContentIds, specialMesh.TextureId)
		elseif instance:IsA("Sound") then
			addContentId(contentIds, seenContentIds, (instance :: Sound).SoundId)
		elseif instance:IsA("Animation") then
			addContentId(contentIds, seenContentIds, (instance :: Animation).AnimationId)
		elseif instance:IsA("ParticleEmitter") then
			addContentId(contentIds, seenContentIds, (instance :: ParticleEmitter).Texture)
		elseif instance:IsA("Trail") then
			addContentId(contentIds, seenContentIds, (instance :: Trail).Texture)
		elseif instance:IsA("Beam") then
			addContentId(contentIds, seenContentIds, (instance :: Beam).Texture)
		elseif instance:IsA("VideoFrame") then
			addContentId(contentIds, seenContentIds, (instance :: VideoFrame).Video)
		elseif instance:IsA("SurfaceAppearance") then
			local surfaceAppearance = instance :: SurfaceAppearance
			addContentId(contentIds, seenContentIds, surfaceAppearance.ColorMap)
			addContentId(contentIds, seenContentIds, surfaceAppearance.MetalnessMap)
			addContentId(contentIds, seenContentIds, surfaceAppearance.NormalMap)
			addContentId(contentIds, seenContentIds, surfaceAppearance.RoughnessMap)
		elseif instance:IsA("Sky") then
			local sky = instance :: Sky
			addContentId(contentIds, seenContentIds, sky.SkyboxBk)
			addContentId(contentIds, seenContentIds, sky.SkyboxDn)
			addContentId(contentIds, seenContentIds, sky.SkyboxFt)
			addContentId(contentIds, seenContentIds, sky.SkyboxLf)
			addContentId(contentIds, seenContentIds, sky.SkyboxRt)
			addContentId(contentIds, seenContentIds, sky.SkyboxUp)
		elseif instance:IsA("Shirt") then
			addContentId(contentIds, seenContentIds, (instance :: Shirt).ShirtTemplate)
		elseif instance:IsA("Pants") then
			addContentId(contentIds, seenContentIds, (instance :: Pants).PantsTemplate)
		elseif instance:IsA("ShirtGraphic") then
			addContentId(contentIds, seenContentIds, (instance :: ShirtGraphic).Graphic)
		end
	end

	return contentIds
end

local function getPreloadRatio(progress: AssetProgress): number
	if progress.totalCount <= 0 then
		return 1
	end

	return math.clamp(progress.loadedCount / progress.totalCount, 0, 1)
end

local function isQueueMostlyClear(): boolean
	return ContentProvider.RequestQueueSize <= LoadingScreenConfig.QueueClearThreshold
end

local function isEnoughLoaded(progress: AssetProgress, preloadFinished: boolean, elapsedSeconds: number): boolean
	if elapsedSeconds >= LoadingScreenConfig.MaximumWaitSeconds then
		return true
	end

	if elapsedSeconds < LoadingScreenConfig.MinimumDisplaySeconds then
		return false
	end

	if preloadFinished then
		return true
	end

	return getPreloadRatio(progress) >= LoadingScreenConfig.MinimumPreloadRatio and isQueueMostlyClear()
end

function LoadingScreenRunner.start(options: LoadingScreenRunnerOptions?)
	if not LoadingGate.tryBeginLoading() then
		return
	end

	if options ~= nil and options.removeDefaultLoadingScreen == true then
		ReplicatedFirst:RemoveDefaultLoadingScreen()
	end

	local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local view = LoadingScreenView.new(playerGui)
	local hasRequestedDismiss = false
	local canSkip = false
	local preloadFinished = false
	local progress: AssetProgress = {
		loadedCount = 0,
		totalCount = 0,
	}

	local function requestDismiss()
		if hasRequestedDismiss then
			return
		end

		hasRequestedDismiss = true
		view:setSkipVisible(false)
		view:playExit(function()
			LoadingGate.markCleared()
			view:destroy()
		end)
	end

	view:connectSkipRequested(function()
		if canSkip then
			requestDismiss()
		end
	end)

	task.spawn(function()
		local contentIds = collectPreloadContentIds(playerGui)
		progress.totalCount = #contentIds
		view:setProgress(progress.loadedCount, progress.totalCount)

		if #contentIds > 0 then
			local success, errorMessage = pcall(function()
				ContentProvider:PreloadAsync(contentIds, function(_contentId: string, _assetFetchStatus: Enum.AssetFetchStatus)
					progress.loadedCount = math.min(progress.loadedCount + 1, progress.totalCount)
					if not hasRequestedDismiss then
						view:setProgress(progress.loadedCount, progress.totalCount)
					end
				end)
			end)

			if not success then
				warn(string.format("LoadingScreen preload failed: %s", tostring(errorMessage)))
			end
		end

		progress.loadedCount = progress.totalCount
		preloadFinished = true
		if not hasRequestedDismiss then
			view:setProgress(progress.loadedCount, progress.totalCount)
		end
	end)

	local startedAt = os.clock()
	while not hasRequestedDismiss do
		local elapsedSeconds = os.clock() - startedAt
		canSkip = isEnoughLoaded(progress, preloadFinished, elapsedSeconds)
		view:setSkipVisible(canSkip)

		if preloadFinished and canSkip then
			requestDismiss()
			break
		end

		RunService.Heartbeat:Wait()
	end
end

return table.freeze(LoadingScreenRunner)

--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local weatherFolder = sharedFolder:WaitForChild("Weather") :: Folder

local WeatherEventConfig = require(weatherFolder:WaitForChild("WeatherEventConfig") :: ModuleScript)
local WeatherTypes = require(weatherFolder:WaitForChild("WeatherTypes") :: ModuleScript)

type WeatherCloudConfig = WeatherTypes.WeatherCloudConfig
type WeatherEventDefinition = WeatherTypes.WeatherEventDefinition
type WeatherFolderEffectsConfig = WeatherTypes.WeatherFolderEffectsConfig

local SKYS_FOLDER_NAME = "Skys"
local WEATHER_FOLDER_NAME = "Weather"
local ACTIVE_PARTICLES_FOLDER_NAME = "ActiveWeatherParticles"

local defaultCloudCover: number? = nil
local defaultCloudDensity: number? = nil
local defaultCloudColor: Color3? = nil
local activeCloudTween: Tween? = nil

local WeatherEnvironmentService = {}

local function getSkysFolder(): Folder
	local skysFolder = ReplicatedStorage:WaitForChild(SKYS_FOLDER_NAME)
	assert(skysFolder:IsA("Folder"), "ReplicatedStorage.Skys must be a Folder")
	return skysFolder
end

local function getWeatherAssetsFolder(): Folder
	local assetsFolder = ReplicatedStorage:WaitForChild(WEATHER_FOLDER_NAME)
	assert(assetsFolder:IsA("Folder"), "ReplicatedStorage.Weather must be a Folder")
	return assetsFolder
end

local function getClouds(): Clouds?
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain == nil then
		return nil
	end

	local clouds = terrain:FindFirstChildOfClass("Clouds")
	return clouds
end

local function captureDefaultClouds()
	if defaultCloudCover ~= nil then
		return
	end

	local clouds = getClouds()
	if clouds == nil then
		return
	end

	defaultCloudCover = clouds.Cover
	defaultCloudDensity = clouds.Density
	defaultCloudColor = clouds.Color
end

local function removeLightingSkies()
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") then
			child:Destroy()
		end
	end
end

local function applySky(skyName: string)
	local skysFolder = getSkysFolder()
	local skyTemplate = skysFolder:WaitForChild(skyName)
	assert(skyTemplate:IsA("Sky"), string.format("ReplicatedStorage.Skys.%s must be a Sky", skyName))

	removeLightingSkies()

	local sky = skyTemplate:Clone()
	sky.Parent = Lighting
end

local function getOrCreateActiveParticlesFolder(): Folder
	local existing = Workspace:FindFirstChild(ACTIVE_PARTICLES_FOLDER_NAME)
	if existing ~= nil then
		assert(existing:IsA("Folder"), string.format("Workspace.%s must be a Folder", ACTIVE_PARTICLES_FOLDER_NAME))
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = ACTIVE_PARTICLES_FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

local function clearParticles()
	local folder = Workspace:FindFirstChild(ACTIVE_PARTICLES_FOLDER_NAME)
	if folder ~= nil then
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("ObjectValue") and child.Value ~= nil then
				child.Value:Destroy()
			end
		end

		folder:Destroy()
	end
end

local function trackActiveEffect(activeEffectsFolder: Folder, instance: Instance, markerName: string)
	local marker = Instance.new("ObjectValue")
	marker.Name = markerName
	marker.Value = instance
	marker.Parent = activeEffectsFolder
end

local function cloneParticles(particleName: string, targetName: string, cloneCount: number)
	local weatherAssetsFolder = getWeatherAssetsFolder()
	local particleTemplate = weatherAssetsFolder:WaitForChild(particleName)
	assert(particleTemplate:IsA("ParticleEmitter"), string.format("ReplicatedStorage.Weather.%s must be a ParticleEmitter", particleName))

	local target = Workspace:WaitForChild(targetName)
	assert(target:IsA("BasePart"), string.format("Workspace.%s must be a BasePart", targetName))

	local activeParticlesFolder = getOrCreateActiveParticlesFolder()
	for index = 1, cloneCount do
		local particle = particleTemplate:Clone()
		particle.Name = string.format("%s_%02d", particleName, index)
		particle.Parent = target

		trackActiveEffect(activeParticlesFolder, particle, particle.Name)
	end
end

local function cloneFolderEffects(effectsConfig: WeatherFolderEffectsConfig)
	local weatherAssetsFolder = getWeatherAssetsFolder()
	local sourceFolder = weatherAssetsFolder:WaitForChild(effectsConfig.sourceFolderName)
	assert(
		sourceFolder:IsA("Folder"),
		string.format("ReplicatedStorage.Weather.%s must be a Folder", effectsConfig.sourceFolderName)
	)

	local target = Workspace:WaitForChild(effectsConfig.targetName)
	assert(target:IsA("BasePart"), string.format("Workspace.%s must be a BasePart", effectsConfig.targetName))

	local activeParticlesFolder = getOrCreateActiveParticlesFolder()
	for index, child in ipairs(sourceFolder:GetChildren()) do
		local effect = child:Clone()
		effect.Parent = target

		if effectsConfig.playSounds == true and effect:IsA("Sound") then
			effect:Play()
		end

		trackActiveEffect(activeParticlesFolder, effect, string.format("%s_%02d", effectsConfig.sourceFolderName, index))
	end
end

local function tweenClouds(cloudConfig: WeatherCloudConfig?)
	captureDefaultClouds()

	local clouds = getClouds()
	if clouds == nil then
		return
	end

	if activeCloudTween ~= nil then
		activeCloudTween:Cancel()
		activeCloudTween = nil
	end

	local targetProperties: { [string]: number | Color3 } = {}
	if cloudConfig == nil then
		if defaultCloudCover ~= nil then
			targetProperties.Cover = defaultCloudCover
		end
		if defaultCloudDensity ~= nil then
			targetProperties.Density = defaultCloudDensity
		end
		if defaultCloudColor ~= nil then
			targetProperties.Color = defaultCloudColor
		end
	else
		if cloudConfig.cover ~= nil then
			targetProperties.Cover = cloudConfig.cover
		end
		if cloudConfig.density ~= nil then
			targetProperties.Density = cloudConfig.density
		end
		if cloudConfig.color ~= nil then
			targetProperties.Color = cloudConfig.color
		end
	end

	if next(targetProperties) == nil then
		return
	end

	local tweenSeconds = if cloudConfig ~= nil then cloudConfig.tweenSeconds else 2
	activeCloudTween = TweenService:Create(clouds, TweenInfo.new(tweenSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), targetProperties)
	activeCloudTween:Play()
end

function WeatherEnvironmentService.applyEvent(eventDefinition: WeatherEventDefinition)
	captureDefaultClouds()
	clearParticles()
	applySky(eventDefinition.sky.activeSkyName)

	local particlesConfig = eventDefinition.particles
	if particlesConfig ~= nil then
		cloneParticles(particlesConfig.topParticleName, particlesConfig.topTargetName, particlesConfig.cloneCount)

		local bottomParticleName = particlesConfig.bottomParticleName
		local bottomTargetName = particlesConfig.bottomTargetName
		if bottomParticleName ~= nil and bottomTargetName ~= nil then
			cloneParticles(bottomParticleName, bottomTargetName, particlesConfig.cloneCount)
		end
	end

	local effectsConfig = eventDefinition.effects
	if effectsConfig ~= nil then
		cloneFolderEffects(effectsConfig)
	end

	tweenClouds(eventDefinition.clouds)
end

function WeatherEnvironmentService.clearEvent()
	clearParticles()
	applySky(WeatherEventConfig.defaultSkyName)
	tweenClouds(nil)
end

return table.freeze(WeatherEnvironmentService)

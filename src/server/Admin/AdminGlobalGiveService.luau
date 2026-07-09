--!strict

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local adminFolder = sharedFolder:WaitForChild("Admin") :: Folder

local AdminConfig = require(adminFolder:WaitForChild("AdminConfig") :: ModuleScript)
local AdminGrantService = require(script.Parent.AdminGrantService)

type AdminGrantRequest = AdminGrantService.AdminGrantRequest

type GlobalGiveMessage = {
	id: string,
	grant: AdminGrantRequest,
	createdAtUnix: number,
}

local MESSAGE_ID_CACHE_LIMIT = 80

local hasStarted = false
local seenMessageIds: { [string]: boolean } = {}
local seenMessageIdOrder: { string } = {}
local subscriptionConnection: RBXScriptConnection? = nil

local function rememberMessageId(messageId: string): boolean
	if seenMessageIds[messageId] == true then
		return false
	end

	seenMessageIds[messageId] = true
	table.insert(seenMessageIdOrder, messageId)

	while #seenMessageIdOrder > MESSAGE_ID_CACHE_LIMIT do
		local oldestMessageId = table.remove(seenMessageIdOrder, 1)
		if oldestMessageId ~= nil then
			seenMessageIds[oldestMessageId] = nil
		end
	end

	return true
end

local function isGlobalGiveMessage(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end

	local message = value :: { [string]: unknown }
	return type(message.id) == "string"
		and AdminGrantService.isGrantRequest(message.grant)
		and type(message.createdAtUnix) == "number"
end

local function applyGlobalGiveMessage(message: GlobalGiveMessage)
	if not rememberMessageId(message.id) then
		return
	end

	local result = AdminGrantService.applyGrantToPlayers(Players:GetPlayers(), message.grant)
	if result == "Invalid grant request." then
		warn("[AdminGlobalGiveService] Ignored invalid global grant message.")
	end
end

local function handleMessagingServiceMessage(message: { Data: unknown })
	if not isGlobalGiveMessage(message.Data) then
		return
	end

	applyGlobalGiveMessage(message.Data :: GlobalGiveMessage)
end

local AdminGlobalGiveService = {}

function AdminGlobalGiveService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local success, result = pcall(function()
		return MessagingService:SubscribeAsync(AdminConfig.globalGiveTopicName, handleMessagingServiceMessage)
	end)

	if success then
		subscriptionConnection = result :: RBXScriptConnection
	else
		warn(string.format("Failed to subscribe to global admin grants: %s", tostring(result)))
	end
end

function AdminGlobalGiveService.publishGrant(grant: AdminGrantRequest): string
	if not AdminGrantService.isGrantRequest(grant) then
		return "Invalid grant request."
	end

	local message: GlobalGiveMessage = {
		id = HttpService:GenerateGUID(false),
		grant = grant,
		createdAtUnix = os.time(),
	}

	applyGlobalGiveMessage(message)

	local publishSuccess, publishError = pcall(function()
		MessagingService:PublishAsync(AdminConfig.globalGiveTopicName, message)
	end)

	if not publishSuccess then
		return string.format(
			"Gave %s in this server, but global publish failed: %s",
			AdminGrantService.describeGrant(grant),
			tostring(publishError)
		)
	end

	return string.format("Gave %s globally to all live servers.", AdminGrantService.describeGrant(grant))
end

function AdminGlobalGiveService.stop()
	local connection = subscriptionConnection
	if connection ~= nil then
		connection:Disconnect()
		subscriptionConnection = nil
	end

	hasStarted = false
end

return table.freeze(AdminGlobalGiveService)

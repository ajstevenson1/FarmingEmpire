--!strict

export type AdminConfig = {
	isAdminUserId: (userId: number) -> boolean,
}

local ADMIN_USER_IDS: { [number]: boolean } = {
	[5204470675] = true,
	[343304069] = true,
}

local AdminConfig = {}

function AdminConfig.isAdminUserId(userId: number): boolean
	return ADMIN_USER_IDS[userId] == true
end

return table.freeze(AdminConfig) :: AdminConfig

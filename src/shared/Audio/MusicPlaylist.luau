--!strict

export type MusicTrackId = string

local trackIds: { MusicTrackId } = table.freeze({
	"rbxassetid://107181449991834",
	"rbxassetid://77024728793668",
	"rbxassetid://81946202273748",
	"rbxassetid://121714232027914",
	"rbxassetid://122519120400338",
})

local MusicPlaylist = {}

function MusicPlaylist.getTrackIds(): { MusicTrackId }
	return trackIds
end

return table.freeze(MusicPlaylist)

--!strict

export type ButtonSoundConfig = {
	ClickSoundId: string,
	ClickSoundName: string,
	Volume: number,
	PoolSize: number,
}

local ButtonSoundConfig: ButtonSoundConfig = table.freeze({
	ClickSoundId = "rbxassetid://117783740925901",
	ClickSoundName = "UIButtonClickSound",
	Volume = 0.55,
	PoolSize = 4,
})

return ButtonSoundConfig

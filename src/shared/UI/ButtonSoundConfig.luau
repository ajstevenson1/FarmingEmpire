--!strict

export type ButtonSoundConfig = {
	ClickSoundId: string,
	ClickSoundName: string,
	BuySoundId: string,
	BuySoundName: string,
	BuyTagName: string,
	Volume: number,
	PoolSize: number,
}

local ButtonSoundConfig: ButtonSoundConfig = table.freeze({
	ClickSoundId = "rbxassetid://117783740925901",
	ClickSoundName = "UIButtonClickSound",
	BuySoundId = "rbxassetid://130452529897520",
	BuySoundName = "UIBuyButtonSound",
	BuyTagName = "Buy",
	Volume = 0.55,
	PoolSize = 4,
})

return ButtonSoundConfig

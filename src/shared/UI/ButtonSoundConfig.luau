--!strict

export type ButtonSoundConfig = {
	ClickSoundId: string,
	ClickSoundName: string,
	BuySoundId: string,
	BuySoundName: string,
	StoreOpenSoundId: string,
	StoreOpenSoundName: string,
	BuyTagName: string,
	StoreTagName: string,
	SuppressSoundAttributeName: string,
	Volume: number,
	PoolSize: number,
}

local ButtonSoundConfig: ButtonSoundConfig = table.freeze({
	ClickSoundId = "rbxassetid://117783740925901",
	ClickSoundName = "UIButtonClickSound",
	BuySoundId = "rbxassetid://130452529897520",
	BuySoundName = "UIBuyButtonSound",
	StoreOpenSoundId = "rbxassetid://127488139302452",
	StoreOpenSoundName = "UIStoreOpenSound",
	BuyTagName = "Buy",
	StoreTagName = "Store",
	SuppressSoundAttributeName = "SuppressButtonSound",
	Volume = 0.55,
	PoolSize = 4,
})

return ButtonSoundConfig

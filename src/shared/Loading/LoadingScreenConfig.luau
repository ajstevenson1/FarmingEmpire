--!strict

export type LoadingScreenConfig = {
	AssetImageId: string,
	DisplayOrder: number,
	BackgroundZIndex: number,
	ContentZIndex: number,
	SkipButtonZIndex: number,
	MinimumDisplaySeconds: number,
	MinimumPreloadRatio: number,
	MaximumWaitSeconds: number,
	QueueClearThreshold: number,
	ExitTweenInfo: TweenInfo,
	RockTweenInfo: TweenInfo,
	ProgressTweenInfo: TweenInfo,
}

local LoadingScreenConfig: LoadingScreenConfig = table.freeze({
	AssetImageId = "rbxassetid://138424008141505",
	DisplayOrder = 50,
	BackgroundZIndex = 50,
	ContentZIndex = 55,
	SkipButtonZIndex = 56,
	MinimumDisplaySeconds = 1.25,
	MinimumPreloadRatio = 0.65,
	MaximumWaitSeconds = 8,
	QueueClearThreshold = 25,
	ExitTweenInfo = TweenInfo.new(0.75, Enum.EasingStyle.Back, Enum.EasingDirection.In),
	RockTweenInfo = TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	ProgressTweenInfo = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
})

return LoadingScreenConfig

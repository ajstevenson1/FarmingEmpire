--!strict

export type CoreMenuLeavePromptConfig = {
	RootGuiName: string,
	ContainerName: string,
	FrameNames: { string },
	TextLabelName: string,
	GradientName: string,
	GradientRotationDegrees: number,
	GradientSpeedCyclesPerSecond: number,
	RainbowGradient: ColorSequence,
}

local CoreMenuLeavePromptConfig: CoreMenuLeavePromptConfig = table.freeze({
	RootGuiName = "GUI",
	ContainerName = "HUD",
	FrameNames = {
		"Leave",
		"Leave2",
	},
	TextLabelName = "Text",
	GradientName = "RainbowGradient",
	GradientRotationDegrees = 0,
	GradientSpeedCyclesPerSecond = 0.45,
	RainbowGradient = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 64, 64)),
		ColorSequenceKeypoint.new(0.16, Color3.fromRGB(255, 188, 64)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 244, 80)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(76, 226, 92)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(60, 196, 255)),
		ColorSequenceKeypoint.new(0.83, Color3.fromRGB(142, 92, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 64, 212)),
	}),
})

return CoreMenuLeavePromptConfig

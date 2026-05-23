--!strict

export type MenuPresentationConfig = {
	MenuFrameGroup: string,
	BlurEffectName: string,
	BlurSize: number,
	CameraZoomOutFovDelta: number,
	TweenInfo: TweenInfo,
}

local MenuPresentationConfig: MenuPresentationConfig = table.freeze({
	MenuFrameGroup = "Menu",
	BlurEffectName = "MenuBackgroundBlur",
	BlurSize = 10,
	CameraZoomOutFovDelta = 6,
	TweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
})

return MenuPresentationConfig

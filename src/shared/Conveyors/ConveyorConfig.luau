--!strict

export type ConveyorConfigValues = {
	tagName: string,
	fallbackInstanceName: string,
	defaultConveyorSpeed: number,
	defaultTextureSpeedV: number,
	speedAttributeName: string,
	textureSpeedVAttributeName: string,
}

local ConveyorConfig: ConveyorConfigValues = table.freeze({
	tagName = "Conveyor",
	fallbackInstanceName = "Conveyor",
	defaultConveyorSpeed = -22,
	defaultTextureSpeedV = 4,
	speedAttributeName = "ConveyorSpeed",
	textureSpeedVAttributeName = "TextureSpeedV",
})

return ConveyorConfig

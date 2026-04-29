--!strict

local InventoryService = require(script.Inventory.InventoryService)
local PlacementService = require(script.Placement.PlacementService)
local PlotService = require(script.Plots.PlotService)
local ProductionService = require(script.Production.ProductionService)

PlotService.start()
InventoryService.start()
ProductionService.start()
PlacementService.start()

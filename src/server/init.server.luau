--!strict

local HarvestService = require(script.Harvest.HarvestService)
local InventoryService = require(script.Inventory.InventoryService)
local PlacementService = require(script.Placement.PlacementService)
local PlotService = require(script.Plots.PlotService)
local ProductionService = require(script.Production.ProductionService)
local ToolSyncService = require(script.Tools.ToolSyncService)

PlotService.start()
InventoryService.start()
ToolSyncService.start()
ProductionService.start()
HarvestService.start()
PlacementService.start()

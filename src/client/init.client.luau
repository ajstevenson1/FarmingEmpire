--!strict

local InventoryController = require(script.Inventory.InventoryController)
local PlacementController = require(script.Placement.PlacementController)
local ProductionStatusController = require(script.Production.ProductionStatusController)

InventoryController.start()
PlacementController.start()
ProductionStatusController.start()

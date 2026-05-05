--!strict

local ButtonHoverController = require(script.UI.ButtonHoverController)
local InventoryController = require(script.Inventory.InventoryController)
local PickupController = require(script.Placement.PickupController)
local PlacementController = require(script.Placement.PlacementController)
local ProductionStatusController = require(script.Production.ProductionStatusController)
local ResourceStatusController = require(script.Resources.ResourceStatusController)
local ScytheController = require(script.Tools.ScytheController)

ButtonHoverController.start()
InventoryController.start()
PlacementController.start()
PickupController.start()
ProductionStatusController.start()
ResourceStatusController.start()
ScytheController.start()

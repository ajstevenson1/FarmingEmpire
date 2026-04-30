# FarmingEmpire Tech Spec

## Purpose
This document is the current technical specification for the FarmingEmpire bootstrap systems. It describes what has been implemented so far, the conventions the project is using, and the assumptions the current code makes about Studio assets.

This spec is intended to be updated over time as new systems are added or existing systems are refactored.

## Current Scope
The project currently includes:

- Custom unified inventory + hotbar loadout bootstrap
- Server-authoritative equip state
- Plot assignment
- Grid-based building placement
- Asset-driven placement previews
- Building root + stage visual architecture
- First production behavior: `GrowAndHarvest`
- First building: `WheatField`
- Growth billboard UI
- Stage-based crop visuals
- Scythe tool sync for held tool presentation

The project does not yet include:

- Harvest interaction
- Produced resource flow from harvest
- Save/load persistence
- Livestock buildings
- Processor buildings
- Building removal / refund logic
- Presenter framework for non-crop building visuals

## High-Level Architecture
The project is split into three major layers:

- Shared definitions and config in `src/shared`
- Server-authoritative game state and validation in `src/server`
- Client UI and preview/presentation in `src/client`

Core rule:

- Server owns gameplay state
- Client reads replicated state and shows visuals
- Assets in `ReplicatedStorage` are the source of truth for building visuals

## Current Systems

## Inventory
Inventory is currently server-owned and replicated to the client as a snapshot.

Implemented behavior:

- Inventory is a unified owned-item list
- Hotbar is an explicit server-owned loadout
- Internal hotbar slot `1` is permanently locked to `Scythe`
- Players start with `3` `Wheat Field`
- Players start with `Scythe` in inventory and `Wheat Field` assigned to internal slot `2` (player-facing slot `1`)
- Inventory is stack-based
- Equipped item is stored as custom state, not a Roblox `Tool`
- Hotbar is temporary code-generated UI
- Expanded inventory UI is temporary code-generated scaffolding
- `Scythe` is the first item that also syncs to a real Roblox `Tool`

Important files:

- `src/shared/Inventory/InventoryTypes.luau`
- `src/shared/Inventory/ItemCatalog.luau`
- `src/shared/Inventory/StartingInventoryConfig.luau`
- `src/server/Inventory/InventoryService.luau`
- `src/client/Inventory/InventoryController.luau`
- `src/client/Inventory/InventoryBarView.luau`

Current selection/loadout behavior:

- Click slot or press `0-9` to select
- Click the unlabeled first slot or press `1-9` to select
- Selecting the same filled slot again deselects it
- Empty slots cannot be selected
- Items can be dragged from the expanded inventory list into hotbar slots `1-9`
- Assigned hotbar slots can be cleared while the expanded inventory panel is open
- If quantity reaches `0`, any hotbar references to that item are sanitized away
- `Scythe` cannot be moved, replaced, or cleared

Current server-side model:

- `InventoryContents` stores owned item quantities
- `HotbarLoadout` stores slot assignments
- `SelectedSlotIndex` stores the current slot selection

Current rules:

- Internal slot `1` is always `Scythe`
- `Scythe` cannot be moved, replaced, or cleared
- Hotbar assignments are references to inventory items, not separate stacks
- If an item quantity reaches `0`, any hotbar slots referencing it should be cleared automatically
- Item category determines what selection does, not whether the item is allowed in the hotbar
- Player-facing labels show no number on the scythe slot, then `1-9` on internal slots `2-10`

Current item behavior by category:

- `Tool` items enter tool mode when selected
- `Placeable` items enter placement mode when selected
- `Resource` items may be selected in the hotbar but do not necessarily trigger an action yet

Current tool-sync behavior:

- When slot `0` is selected, the server clones `ReplicatedStorage.Tools.Scythe`
- The cloned scythe is parented to the player's `Backpack`
- If the player has a character and humanoid, the server equips that tool immediately
- When the player deselects `Scythe` or selects a different item, the system-owned scythe tool is removed
- If the player respawns while `Scythe` is still selected, the tool is re-granted and re-equipped

Important files:

- `src/server/Tools/ToolSyncService.luau`

## Networking
Remotes are created by code under `ReplicatedStorage.GameRemotes`.

Current remote groups:

- `Inventory`
- `Placement`

Important files:

- `src/shared/Networking/RemoteNames.luau`
- `src/server/Networking/Remotes.luau`

## Plot Ownership
Plots are assigned on the server from `Workspace.Plots`.

Current behavior:

- First unclaimed plot is assigned to a joining player
- Plot ownership is stored on the plot via attributes
- Client placement is restricted to the player’s assigned plot

Important files:

- `src/server/Plots/PlotService.luau`

Current plot ownership attributes:

- `OwnerUserId`
- `OwnerPlayerName`

## Placement
Placement is server-authoritative and grid-snapped.

Current behavior:

- Placement only works for the currently equipped placeable item
- Placement is restricted to the player’s assigned plot
- Placement uses `1` stud center movement while validating the full footprint
- Placement overlap is checked on the server and also predicted on the client
- Successful placement consumes `1` item from inventory

Important files:

- `src/shared/Placement/PlotMath.luau`
- `src/server/Placement/PlacementService.luau`
- `src/client/Placement/PlacementController.luau`
- `src/client/Placement/PlacementPreviewView.luau`

## Building Root Pattern
Placed buildings use a hidden authoritative root part in `Workspace.PlacedObjects`.

Current behavior:

- The placed root is a transparent `BasePart`
- The root carries gameplay attributes and occupancy size
- The visible crop art is cloned under the root as a child model
- Stage visuals swap without changing the authoritative root object

Why this pattern exists:

- Keeps gameplay state separate from art
- Allows stage visual swaps without replacing the real building instance
- Makes future building presenters easier to implement

## Building Definitions
Buildings now have their own shared config layer.

Important files:

- `src/shared/Buildings/BuildingTypes.luau`
- `src/shared/Buildings/BuildingCatalog.luau`
- `src/shared/Buildings/BuildingAttributeNames.luau`
- `src/shared/Buildings/BuildingAssetUtils.luau`

Current building definitions:

- `WheatField`

Current `WheatField` behavior:

- Production behavior: `GrowAndHarvest`
- Cycle duration: `15` seconds
- Output resource name: `Wheat`
- Output amount: `1`
- Storage cap: `1`
- Growth stages: `Stage0`, `Stage1`, `Stage2`, `Stage3`

## Asset Conventions
Buildings are asset-driven from `ReplicatedStorage.Buildings`.

Current Studio asset layout:

- `ReplicatedStorage`
- `ReplicatedStorage/Buildings`
- `ReplicatedStorage/Buildings/WheatField`
- `ReplicatedStorage/Buildings/WheatField/Stage0`
- `ReplicatedStorage/Buildings/WheatField/Stage1`
- `ReplicatedStorage/Buildings/WheatField/Stage2`
- `ReplicatedStorage/Buildings/WheatField/Stage3`

Current mandatory convention for crop stage models:

- Every stage model contains a `BasePart` named `PlacementBox`
- `PlacementBox` is the `PrimaryPart`
- The bottom face of `PlacementBox` is the ground contact plane
- `PlacementBox` defines the footprint and placement anchor
- Decorative crop parts are positioned relative to `PlacementBox`

Current code assumption:

- Footprint comes from `Stage0.PlacementBox.Size`
- Preview, placement validation, root part size, and stage visual normalization all use that convention

## Placement Preview Convention
The placement preview is now TD-style and box-driven.

Current behavior:

- The client clones `Stage0` as the ghost model
- A `SelectionBox` is attached to the cloned `PlacementBox`
- Green outline means valid placement
- Red outline means invalid placement
- The decorative crop art is semi-transparent
- The `PlacementBox` itself remains invisible

This is intentionally separate from gameplay state. The preview is only client-side.

## Production Framework
Production is being built as a generic framework with behavior modules.

Important files:

- `src/server/Production/ProductionBehaviorRegistry.luau`
- `src/server/Production/ProductionService.luau`
- `src/server/Production/Behaviors/GrowAndHarvestBehavior.luau`

Current production design:

- One central production service
- Building definitions choose a production behavior
- Runtime state is tracked per placed building root
- The service updates building attributes over time
- Crop stage visuals are swapped from production progress thresholds

Current behavior registry coverage:

- `GrowAndHarvest`

## Wheat Field Growth
`WheatField` is the first complete vertical slice of the production system.

Current behavior:

- When placed, the field starts growing immediately
- Progress advances from `0` to `1` over `15` seconds
- Growth stage model swaps occur at configured thresholds
- Final state becomes `Ready`
- Stored amount becomes `1`

Current stage thresholds:

- `Stage0` at `0.00`
- `Stage1` at `0.34`
- `Stage2` at `0.67`
- `Stage3` at `1.00`

## Production Billboard UI
Placed crop buildings display temporary code-generated status UI above the building.

Important files:

- `src/client/Production/ProductionBillboardView.luau`
- `src/client/Production/ProductionStatusController.luau`

Current behavior:

- Billboard shows progress bar
- Billboard shows remaining seconds while growing
- Billboard changes to `Ready` when complete

This UI is temporary scaffolding and can be replaced later with final Studio UI.

## Current Runtime Attributes
The placed building root currently receives production/building attributes from the server.

Current building/production attributes:

- `BuildingId`
- `BuildingDisplayName`
- `ProductionBehaviorId`
- `ProductionState`
- `ProductionProgress`
- `ProductionTimeLeft`
- `ProductionStatusText`
- `ProductionDuration`
- `ProductionOutputName`
- `ProductionStoredAmount`
- `ProductionStorageCap`
- `IsReadyToHarvest`
- `GrowthVisualStageName`

Current placement/root attributes:

- `OwnerUserId`
- `PlotName`
- `ItemId`
- `GridX`
- `GridZ`

## Entry Points
Current bootstrap entry files:

- `src/server/init.server.luau`
- `src/client/init.client.luau`

Server startup currently initializes:

- Plot service
- Inventory service
- Production service
- Placement service

Client startup currently initializes:

- Inventory controller
- Placement controller
- Production status controller

## Design Rules Established So Far
These rules are already reflected in the current implementation direction:

- Server owns game state and validation
- Client owns preview and presentation
- Building roots are hidden authoritative objects
- Visuals are replaceable children under building roots
- Asset conventions should drive placement alignment
- `PlacementBox` is the placement truth
- Crop growth uses stage visuals instead of animation-driven growth

## Planned Direction
The currently agreed future direction is:

- Crops use multi-stage growth visuals
- Livestock buildings will likely use one base building model plus animal behavior/presentation
- Production buildings will likely use active/inactive state models plus optional VFX or animations
- A presenter framework will eventually be needed so building visuals stay organized and do not turn into one-off scripts everywhere

## Known Gaps
The following systems are not implemented yet but are already expected by the current design direction:

- Harvesting wheat fields
- Livestock production behavior
- Input-processing production behavior
- Visual presenter registry for non-crop buildings
- Save/load support
- Final UI replacement for temporary code-generated UI

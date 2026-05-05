# FarmingEmpire Tech Spec

## Purpose
This document is the current technical specification for the FarmingEmpire bootstrap systems. It describes the implemented Rojo project structure, system boundaries, data flow, and Studio asset assumptions used by the current codebase.

This spec should be updated whenever systems are added, renamed, or refactored.

## Codebase Shape
The project is a Roblox game built with Rojo and VS Code.

Rojo maps:

- `src/shared` to `ReplicatedStorage.Shared`
- `src/server` to `ServerScriptService.Server`
- `src/client` to `StarterPlayer.StarterPlayerScripts.Client`

Current source folders:

- `src/shared/Buildings`
- `src/shared/Economy`
- `src/shared/Inventory`
- `src/shared/Networking`
- `src/shared/Placement`
- `src/shared/Plots`
- `src/shared/Resources`
- `src/server/Buildings`
- `src/server/Data`
- `src/server/Economy`
- `src/server/Harvest`
- `src/server/Inventory`
- `src/server/Market`
- `src/server/Networking`
- `src/server/Placement`
- `src/server/Plots`
- `src/server/Production`
- `src/server/Resources`
- `src/server/Tools`
- `src/client/Inventory`
- `src/client/Placement`
- `src/client/Production`
- `src/client/Resources`
- `src/client/Tools`

Core architectural rule:

- Shared modules define types, config, catalogs, and pure helpers.
- Server modules own gameplay state, validation, persistence, and authoritative mutations.
- Client modules own input, previews, temporary UI, and local presentation.

## Current Scope
The project currently includes:

- Unified inventory and hotbar bootstrap
- Server-authoritative equipped item state
- Locked `Scythe` tool slot
- Server-synced Roblox `Tool` presentation for `Scythe`
- Server-authoritative six-slot plot assignment
- Grid-based placement using plot-relative coordinates
- Asset-driven placement previews
- Hidden building root pattern under `Workspace.PlacedObjects`
- Stage-based building visuals under each root
- Generic production behavior registry
- `GrowAndHarvest` production behavior
- `TimedStorageProducer` production behavior
- `InputProcessor` production behavior
- First producer building: `BasicTree`
- First processor building: `CiderMill`
- Apple and cider resource flow
- Scythe cone-harvest loop for producer buildings with stored output
- Cash economy snapshot
- Dynamic cider market price
- Sell-all-cider market action
- Cash/resource persistence through `DataStoreService`
- Placed building position persistence
- Temporary inventory, production billboard, and resource/economy/market UI

The project does not yet include:

- Persistent inventory, hotbar, or plot state
- Building removal or refund logic
- Final Studio-authored UI
- Livestock buildings
- Upgrade systems
- A general visual presenter registry beyond growth-stage visual swapping
- Market support beyond cider

## Studio Object Assumptions
Only code files are visible in this repository. The current code assumes the following Studio objects exist:

- `Workspace.Plots` as a `Folder`
- Six assignable plot children under `Workspace.Plots`
- Each plot may be a `BasePart` or a `Model`
- Model plots should contain a placement base part named `Base`, `PlotBase`, `PlacementBase`, or `Ground`
- Each plot should contain a spawn part named `SpawnPoint`, `SpawnPart`, or `SpawnLocation`
- `ReplicatedStorage.Buildings` as a `Folder`
- `ReplicatedStorage.Buildings.BasicTree` as a `Folder`
- `ReplicatedStorage.Buildings.BasicTree.Stage0` through `Stage3` as `Model` instances
- `ReplicatedStorage.Buildings.CiderMill` as a `Folder`
- `ReplicatedStorage.Buildings.CiderMill.Stage0` and `Stage1` as `Model` instances
- Each stage model contains a `BasePart` named `PlacementBox`
- `ReplicatedStorage.Tools` as a `Folder`
- `ReplicatedStorage.Tools.Scythe` as a `Tool`
- `ReplicatedStorage.Tools.Scythe.Swing` as an `Animation`

The code creates these runtime objects if missing:

- `ReplicatedStorage.GameRemotes`
- Remote folders and remote instances under `ReplicatedStorage.GameRemotes`
- `Workspace.PlacedObjects`

## Entry Points
Current bootstrap entry files:

- `src/server/init.server.luau`
- `src/client/init.client.luau`

Server startup order:

1. `PlayerDataService`
2. `PlotService`
3. `InventoryService`
4. `ResourceService`
5. `EconomyService`
6. `ToolSyncService`
7. `MarketService`
8. `ProductionService`
9. `HarvestService`
10. `PlacementService`

Client startup order:

1. `InventoryController`
2. `PlacementController`
3. `ProductionStatusController`
4. `ResourceStatusController`
5. `ScytheController`

## Networking
Remotes are created by code under `ReplicatedStorage.GameRemotes`.

Current remote groups:

- `Inventory`
- `Placement`
- `Harvest`
- `Resources`
- `Economy`
- `Market`

Important files:

- `src/shared/Networking/RemoteNames.luau`
- `src/server/Networking/Remotes.luau`

Current inventory remotes:

- `InventoryUpdated`
- `GetInventorySnapshot`
- `SetSelectedSlot`
- `AssignHotbarSlot`
- `ClearHotbarSlot`

Current placement remotes:

- `RequestPlacement`
- `RequestPickup`

Current harvest remotes:

- `RequestScytheSwing`

Current resource remotes:

- `ResourceUpdated`
- `GetResourceSnapshot`

Current economy remotes:

- `EconomyUpdated`
- `GetEconomySnapshot`

Current market remotes:

- `MarketUpdated`
- `GetMarketSnapshot`
- `SellAllCider`

## Player Data
Player economy, resource, and placed building data are persisted through `DataStoreService`.

Important files:

- `src/server/Data/PlayerDataStore.luau`
- `src/server/Data/PlayerDataService.luau`

Current persisted schema:

- `schemaVersion`
- `economy.cash`
- `resources.Apple`
- `resources.Cider`
- `placedBuildings`
- `placedBuildings[].buildingId`
- `placedBuildings[].gridX`
- `placedBuildings[].gridZ`

Current behavior:

- DataStore name is `FarmingEmpire_PlayerData_v1`.
- Player data loads on join.
- Failed loads use temporary unsaved default data.
- Cash and resource amounts are sanitized to non-negative whole numbers.
- Placed building records are sanitized to known building IDs and whole-number grid coordinates.
- Autosave runs every `120` seconds.
- Data saves on player leave and `BindToClose`.
- Cash, resources, and placed building positions are persisted right now.

## Inventory
Inventory is server-owned and replicated to the client as snapshots.

Important files:

- `src/shared/Inventory/InventoryTypes.luau`
- `src/shared/Inventory/ItemCatalog.luau`
- `src/shared/Inventory/InventoryUtils.luau`
- `src/shared/Inventory/HotbarConfig.luau`
- `src/shared/Inventory/StartingInventoryConfig.luau`
- `src/shared/Inventory/StartingHotbarConfig.luau`
- `src/server/Inventory/InventoryService.luau`
- `src/client/Inventory/InventoryController.luau`
- `src/client/Inventory/InventoryBarView.luau`

Current item definitions:

- `Scythe`: `Tool`, max stack `1`, tool asset `Scythe`
- `BasicTree`: `Placeable`, display name `Apple Tree`, max stack `99`
- `CiderMill`: `Placeable`, display name `Cider Mill`, max stack `99`

Current starting inventory:

- `1` `Scythe`
- `12` `BasicTree`
- `1` `CiderMill`

Current starting hotbar:

- Internal slot `1`: locked to `Scythe`
- Internal slot `2`: `BasicTree`
- Internal slot `3`: `CiderMill`

Current hotbar rules:

- Internal slots range from `1` through `10`.
- Internal slot `1` is permanently locked to `Scythe`.
- Player-facing keys `1-9` map to internal slots `2-10`.
- `Scythe` cannot be moved, replaced, cleared, or consumed.
- Placeable items can be assigned to assignable slots.
- Duplicate placeable assignments are sanitized.
- Hotbar assignments reference owned item quantities, not separate stacks.
- If an item quantity reaches `0`, related hotbar assignments are removed.
- Selecting an already selected filled slot deselects it.
- Empty slots cannot be selected.

Current inventory state model:

- `quantitiesByItemId` stores owned quantities.
- `hotbarSlots` stores slot assignments.
- `selectedSlotIndex` stores equipped state.

Current UI state:

- Default Roblox backpack UI is disabled.
- Inventory and hotbar UI are generated by code.
- Expanded inventory UI is temporary scaffolding.

## Tool Sync
The `Scythe` inventory item is synced to a real Roblox `Tool`.

Important files:

- `src/server/Tools/ToolSyncService.luau`
- `src/client/Tools/ScytheController.luau`

Current behavior:

- Selecting `Scythe` clones `ReplicatedStorage.Tools.Scythe`.
- The clone is marked with `SystemToolItemId = "Scythe"`.
- The clone is parented to the player's `Backpack`.
- If the player has a character and humanoid, the server equips the clone.
- Deselecting `Scythe` or selecting another item removes system-owned scythes.
- Respawning while `Scythe` is selected re-grants and re-equips the tool.
- Activating the local tool plays its `Swing` animation and sends one harvest request.

## Plot Ownership
Plots are assigned on the server from `Workspace.Plots`.

Important files:

- `src/shared/Plots/PlotLocator.luau`
- `src/server/Plots/PlotService.luau`

Current behavior:

- First unclaimed supported plot slot is assigned to a joining player.
- The server supports six assignable plot slots.
- Plots are considered by `Slot` attribute, falling back to plot-name order.
- Missing or duplicate plot slots are normalized by the server at startup.
- Plot ownership is stored on plot attributes.
- Player assignment is mirrored to player attributes for client lookup.
- The player is teleported to the assigned plot spawn on assignment and respawn.
- Plot ownership is released when the player leaves.
- Client placement finds the local player's assigned plot through `PlotLocator`.

Current plot attributes:

- `OwnerUserId`
- `OwnerPlayerName`
- `Slot`

Current player plot attributes:

- `PlotSlot`
- `AssignedPlotName`

## Placement
Placement is server-authoritative and grid-snapped.

Important files:

- `src/shared/Placement/PlotMath.luau`
- `src/server/Placement/PlacementService.luau`
- `src/client/Placement/PlacementController.luau`
- `src/client/Placement/PlacementPreviewView.luau`

Current behavior:

- Placement only works for the currently selected placeable item.
- Client preview raycasts against the assigned plot only.
- Grid coordinates are plot-relative integer center offsets.
- Placement uses `1` stud center movement while validating the full footprint.
- Placement is restricted to the player's assigned plot.
- Server rejects non-number or non-whole-number grid requests.
- Server validates plot bounds and footprint overlap.
- Client predicts plot bounds and footprint overlap for preview feedback.
- Successful placement consumes `1` item from inventory.
- Successful placement creates a hidden building root and registers it with production.
- Successful placement appends a placed building record to persistent player data.
- Saved placed buildings are recreated on the player's assigned plot when they join.
- Saved placed buildings restore position only; production runtime progress starts fresh after loading.
- A player's live placed roots are removed from `Workspace.PlacedObjects` when they leave.

Current placement/root attributes:

- `OwnerUserId`
- `PlotName`
- `PlotSlot`
- `ItemId`
- `GridX`
- `GridZ`

## Building Root Pattern
Placed buildings use a hidden authoritative root part in `Workspace.PlacedObjects`.

Important files:

- `src/server/Buildings/BuildingVisualService.luau`

Current behavior:

- The root is a transparent anchored `Part`.
- The root carries gameplay attributes and occupancy size.
- The root's size is the current building placement footprint.
- Visible building art is cloned under the root as `CurrentVisual`.
- Stage visuals swap without replacing the authoritative root object.
- Visual parts are anchored, non-colliding, non-queryable, and non-touching.
- `PlacementBox` inside the visual model is kept invisible.

Why this pattern exists:

- Gameplay state stays separate from art.
- Stage visual swaps do not replace the authoritative building instance.
- Future presenter systems can build on a stable root contract.

## Building Definitions
Buildings are defined in shared catalog modules.

Important files:

- `src/shared/Buildings/BuildingTypes.luau`
- `src/shared/Buildings/BuildingCatalog.luau`
- `src/shared/Buildings/BuildingAttributeNames.luau`
- `src/shared/Buildings/BuildingAssetUtils.luau`

Current building definitions:

- `BasicTree`
- `CiderMill`

Current `BasicTree` definition:

- Display name: `Apple Tree`
- Placement size fallback: `6, 6, 6`
- Production behavior: `TimedStorageProducer`
- Produce interval: `10` seconds
- Output resource: `Apple`
- Output amount per interval: `1`
- Storage cap: `10`
- Visual asset folder: `BasicTree`
- Growth stages: `Stage0`, `Stage1`, `Stage2`, `Stage3`

Current `CiderMill` definition:

- Display name: `Cider Mill`
- Placement size fallback: `8, 6, 8`
- Production behavior: `InputProcessor`
- Cycle duration: `12` seconds
- Input resource: `Apple`
- Input amount: `3`
- Output resource: `Cider`
- Output amount: `1`
- Idle status text: `Idle`
- Blocked status text: `Need apples`
- Visual asset folder: `CiderMill`
- Visual stages: `Stage0`, `Stage1`

Current building type unions:

- `BuildingId`: `BasicTree | CiderMill`
- `ProductionBehaviorId`: `GrowAndHarvest | TimedStorageProducer | InputProcessor`
- `ProductionState`: `Growing | Ready | Idle | Processing | Blocked`

## Asset Conventions
Buildings are asset-driven from `ReplicatedStorage.Buildings`.

Current Studio asset layout:

- `ReplicatedStorage/Buildings/BasicTree/Stage0`
- `ReplicatedStorage/Buildings/BasicTree/Stage1`
- `ReplicatedStorage/Buildings/BasicTree/Stage2`
- `ReplicatedStorage/Buildings/BasicTree/Stage3`
- `ReplicatedStorage/Buildings/CiderMill/Stage0`
- `ReplicatedStorage/Buildings/CiderMill/Stage1`

Current mandatory convention for stage models:

- Every stage model contains a `BasePart` named `PlacementBox`.
- `PlacementBox` is used as the model `PrimaryPart`.
- The bottom face of `PlacementBox` is the ground contact plane.
- `PlacementBox` defines the footprint and placement anchor.
- Decorative parts are positioned relative to `PlacementBox`.

Current code behavior:

- Footprint comes from the first configured stage's `PlacementBox.Size`.
- Preview, placement validation, root part size, and visual normalization use that convention.
- Missing building folders or stage models fall back to generated placeholder visuals.
- Missing `PlacementBox` still asserts because footprint and pivoting require it.

## Placement Preview
The placement preview is client-only and box-driven.

Current behavior:

- The client clones `Stage0` for the equipped placeable building.
- A `SelectionBox` is attached to the cloned `PlacementBox`.
- Green outline means valid placement.
- Red outline means invalid placement.
- Decorative art is semi-transparent.
- `PlacementBox` remains invisible.
- Preview models are parented to `Workspace` while visible and unparented when hidden.

## Production Framework
Production is implemented as a generic server framework with behavior modules.

Important files:

- `src/server/Production/ProductionBehaviorRegistry.luau`
- `src/server/Production/ProductionService.luau`
- `src/server/Production/Behaviors/GrowAndHarvestBehavior.luau`
- `src/server/Production/Behaviors/TimedStorageProducerBehavior.luau`
- `src/server/Production/Behaviors/InputProcessorBehavior.luau`

Current production design:

- One central production service tracks placed building roots.
- Building definitions choose a production behavior.
- Runtime production state is tracked per placed root.
- Runtime state is separate from shared definitions.
- The service updates building attributes every `0.25` seconds.
- Visual stage changes are derived from production progress thresholds.
- Production behaviors receive resource functions through a typed context.

Current behavior registry coverage:

- `GrowAndHarvest`
- `TimedStorageProducer`
- `InputProcessor`

## GrowAndHarvest Behavior
`GrowAndHarvest` is the legacy full-cycle harvest behavior. It is currently available in the registry but is not used by the current building catalog.

Current behavior:

- New roots start in `Growing`.
- Progress advances from `0` to `1` over the configured cycle duration.
- Status text shows remaining seconds while growing.
- When complete, state becomes `Ready`.
- Status text becomes `Harvest`.
- Stored amount becomes the configured output amount clamped by storage cap.
- `isReadyToHarvest` becomes true.
- Harvest resets the runtime state to a new growing cycle.
- Harvest returns a resource output for `HarvestService` to grant.

## TimedStorageProducer Behavior
`TimedStorageProducer` is used by `BasicTree`.

Current behavior:

- New roots start in `Growing` with `0` stored output.
- Every configured produce interval, stored output increases by the configured output amount.
- Stored output is clamped to the configured storage cap of `10` apples for `BasicTree`.
- Once storage reaches capacity, state becomes `Ready` and production pauses.
- `ProductionProgress` is the storage fill ratio, not elapsed timer progress.
- Status text shows stored output as `stored/cap` until full, then `Harvest`.
- `IsReadyToHarvest` is true whenever stored output is greater than `0`.
- Harvest can happen before full capacity.
- Harvest returns the stored output amount for `HarvestService` to grant.
- Harvest resets stored output to `0` and starts a new produce interval.

Current `BasicTree` stage thresholds:

- `Stage0` at `0.00`
- `Stage1` at `0.10`
- `Stage2` at `0.50`
- `Stage3` at `1.00`

## InputProcessor Behavior
`InputProcessor` is used by `CiderMill`.

Current behavior:

- New roots start in `Idle`.
- On update, the processor attempts to consume configured input from the owner.
- If enough input exists, it enters `Processing`.
- If input is missing, it enters `Blocked`.
- While processing, progress advances from `0` to `1`.
- When processing completes, output resource is granted to the owner.
- After output, the processor immediately attempts to begin another cycle.
- Processor output is pushed directly to resources; it is not harvested with the scythe.

Current `CiderMill` stage thresholds:

- `Stage0` at `0.00`
- `Stage1` at `0.01`

## Harvesting
`Scythe` harvesting is a server-authoritative cone swing.

Important files:

- `src/client/Tools/ScytheController.luau`
- `src/server/Harvest/HarvestService.luau`
- `src/server/Production/ProductionService.luau`
- `src/server/Resources/ResourceService.luau`

Current behavior:

- Clicking with the equipped `Scythe` plays the local `Swing` animation.
- The client sends one swing request per successful local swing lock window.
- The server validates that `Scythe` is the currently selected item.
- The server checks owned placed building roots in a cone in front of the player.
- Buildings whose production behavior supports harvest can produce output.
- Harvested `BasicTree` buildings grant their current stored apples and reset to `Stage0`.
- A `BasicTree` can grant `1` to `10` `Apple` depending on stored output when harvested.

Current cone values:

- Range: `8` studs
- Half-angle: `60` degrees
- Vertical tolerance: `6` studs
- Client swing lock: `0.5` seconds
- Server cooldown: `0.5` seconds

## Resources
Resources are persistent player-owned amounts separate from inventory items.

Important files:

- `src/shared/Resources/ResourceTypes.luau`
- `src/shared/Resources/ResourceCatalog.luau`
- `src/server/Resources/ResourceService.luau`
- `src/client/Resources/ResourceStatusController.luau`
- `src/client/Resources/ResourceStatusView.luau`

Current resource definitions:

- `Apple`
- `Cider`

Current behavior:

- Resource amounts live in `PlayerDataService`.
- `ResourceService` exposes add, consume, and snapshot functions.
- Resource snapshots include every resource in `ResourceCatalog`.
- Resource updates are pushed to the owning client.
- The client resource status UI displays apples and cider.

## Economy
Economy currently tracks persistent player cash.

Important files:

- `src/shared/Economy/EconomyTypes.luau`
- `src/server/Economy/EconomyService.luau`
- `src/server/Data/PlayerDataService.luau`

Current behavior:

- Cash lives in `PlayerDataService`.
- Economy snapshots include `cash`.
- Cash updates are pushed to the owning client.
- `EconomyService.addCash` ignores non-positive amounts.

## Market
The market currently supports selling cider.

Important files:

- `src/shared/Economy/MarketConfig.luau`
- `src/server/Market/MarketService.luau`
- `src/client/Resources/ResourceStatusController.luau`
- `src/client/Resources/ResourceStatusView.luau`

Current config:

- Price change interval: `30` seconds
- Minimum cider sell price: `$5`
- Maximum cider sell price: `$15`

Current behavior:

- Server rolls the current cider price.
- The price changes every configured interval.
- New price rolls avoid repeating the previous price when the range allows it.
- Market snapshots include `ciderSellPrice` and `nextPriceChangeAt`.
- Market updates are pushed to all clients.
- `SellAllCider` consumes all of the player's cider and grants cash.
- The temporary resource status UI displays cash, apples, cider, price, timer, and sell button.

## Production Billboard UI
Placed production buildings display temporary code-generated status UI above the root.

Important files:

- `src/client/Production/ProductionBillboardView.luau`
- `src/client/Production/ProductionStatusController.luau`

Current behavior:

- The client tracks roots in `Workspace.PlacedObjects`.
- Tracking starts once a root has a `BuildingId` attribute.
- Billboard shows status text.
- Billboard shows progress bar.
- Bar color changes for ready, blocked, idle, and active processing/growing states.
- Billboard is destroyed when the root is removed.

This UI is temporary scaffolding and can be replaced later with final Studio UI.

## Current Runtime Attributes
The placed building root currently receives building, placement, and production attributes from the server.

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
- `PlotSlot`
- `ItemId`
- `GridX`
- `GridZ`

## Data Flow Summary
Inventory and placement flow:

1. Server initializes inventory from starting config.
2. Client receives inventory snapshot.
3. Client selects a placeable hotbar item.
4. Client previews placement on assigned plot.
5. Client sends grid coordinates to server.
6. Server validates selected item, plot bounds, overlap, and inventory quantity.
7. Server consumes item and creates a hidden root.
8. Server registers root with production.
9. Client observes the root and renders production UI.

Producer flow:

1. `BasicTree` stores `1` apple every `10` seconds until it reaches `10` stored apples.
2. Server writes production attributes to the root.
3. Server swaps visual stage models as stored apple fill crosses thresholds.
4. Client billboard reads replicated attributes.
5. Player swings `Scythe`.
6. Server validates cone hit and asks production to harvest the root.
7. Production harvest returns the current stored apples, then resets storage to `0`.
8. Resource service adds apples and pushes a resource snapshot.

Processor/market flow:

1. `CiderMill` attempts to consume apples from the owner.
2. If apples are available, it processes for `12` seconds.
3. On completion, it grants cider and starts another cycle if possible.
4. Market rolls cider price every `30` seconds.
5. Player clicks sell-all-cider in the temporary UI.
6. Server consumes cider and grants cash.
7. Resource and economy snapshots update the client.

## Design Rules Established So Far
These rules are reflected in the current implementation direction:

- Server owns game state and validation.
- Client owns preview and presentation.
- Shared modules own types, catalogs, configs, and pure helpers.
- Building roots are hidden authoritative objects.
- Visuals are replaceable children under building roots.
- Asset conventions should drive placement alignment.
- `PlacementBox` is the placement truth.
- Runtime production state stays separate from building definitions.
- Resource amounts are separate from inventory items.
- Persistent player data is accessed through `PlayerDataService`, not ad hoc service-local state.

## Planned Direction
The currently implied future direction is:

- Keep adding buildings through `BuildingCatalog`, item definitions, and asset folders.
- Expand production behaviors only when a new behavior needs different state transitions.
- Persist inventory, hotbar, and plot state after the in-memory loop stabilizes.
- Replace temporary code-generated UI with final Studio-authored UI.
- Add a presenter registry when non-growth visuals become more varied.
- Generalize market config when more sellable resources exist.

## Known Gaps
The following systems are not implemented yet:

- Inventory persistence
- Hotbar persistence
- Plot persistence
- Building removal/refund flow
- Final UI assets
- Upgrade system
- Livestock production behavior
- Generalized market support for resources beyond cider
- Visual presenter registry for non-growth building visuals

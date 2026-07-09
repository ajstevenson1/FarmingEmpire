# FarmingEmpire Tech Spec

## Purpose

This document is the high-level technical design for the current FarmingEmpire codebase. It describes the active Rojo project structure, runtime ownership boundaries, persisted state, data flow, Studio object contracts, and extension points.

Keep this file current when systems are added, renamed, removed, or promoted from temporary scaffolding to final production paths.

## Project Shape

FarmingEmpire is a Roblox game built with Rojo and VS Code. Only code files are visible in this repository; Studio-authored assets, world models, and GUI instances are assumed to exist unless a service explicitly creates them at runtime.

Rojo mapping:

- `src/shared` maps to `ReplicatedStorage.Shared`
- `src/server` maps to `ServerScriptService.Server`
- `src/client` maps to `StarterPlayer.StarterPlayerScripts.Client`

Architectural ownership:

- Shared modules define Luau types, catalogs, config, constants, and pure helper logic.
- Server modules own authoritative gameplay state, validation, persistence, reward granting, DataStores, and workspace mutations.
- Client modules own input, previews, local navigation, UI state, effects, sounds, and presentation.
- Studio owns world geometry, authored GUIs, building/tool assets, shop pads, teleport pads, templates, and leaderboard boards.

The project uses `--!strict` in source modules and should continue using typed Luau for major systems and data structures.

## Runtime Scope

Current implemented gameplay includes:

- Six-slot server-assigned farm plots
- Persistent player data for cash, resources, inventory, hotbar, placed buildings, production snapshots, offline rewards, settings, and playtime rewards
- Server-owned inventory with a locked scythe slot and assignable placeable slots
- Eight placeable building items across trees and cider mills
- Server-authoritative grid placement, pickup, pickup-all, and sell actions
- Hidden authoritative building roots with cloned visual stage models
- Timed producer and input processor production behaviors
- Apple harvesting through scythe swings and client-assisted auto-harvest navigation
- Walkover collection for processor output
- Apple and cider resource flow
- Persistent cash economy
- Dynamic cider sell market
- Two restocking shops: trees and mills
- Offline cider earnings based on placed building rates
- Playtime reward cycle
- Music/SFX settings and audio bus management
- Cash, time spent, apples earned, cider earned, and Robux spent leaderboard infrastructure
- Cmdr admin commands gated by configured user IDs
- A mix of Studio-authored GUI and code-generated/managed UI

Current limitations and intentional gaps:

- Market logic is cider-only.
- Shop stock and restock timers are per-session and not persisted.
- Plot ownership is session-only.
- Offline earnings are calculated from configured per-building cider rates, not from simulating production cycles.
- Robux leaderboard recording exists as a service API, but no product purchase flow is present in the visible code.
- Final UI is still partly Studio-authored and partly code-generated scaffolding.
- `src/server/Harvest/AutoHarvestService.luau` is not started by `init.server.luau`; the active auto-harvest path is client navigation plus the normal server scythe swing validation.

## Entry Points

Server entry point:

- `src/server/init.server.luau`

Server startup order:

1. `CmdrService`
2. `PlayerDataService`
3. `SettingsService`
4. `PlotService`
5. `TeleportService`
6. `InventoryService`
7. `ResourceService`
8. `EconomyService`
9. `CashLeaderboardService`
10. `TimeSpentLeaderboardService`
11. `ApplesEarnedLeaderboardService`
12. `CiderEarnedLeaderboardService`
13. `RobuxSpentLeaderboardService`
14. `ShopService`
15. `ToolSyncService`
16. `MarketService`
17. `CiderSellService`
18. `ProductionService`
19. `HarvestService`
20. `PlacementService`
21. `WalkoverCollectionService`
22. `OfflineEarningsService`
23. `PlaytimeRewardsService`

Client entry point:

- `src/client/init.client.luau`

Client startup order:

1. `ButtonHoverController`
2. `CloseButtonController`
3. `AudioService`
4. `CmdrClientController`
5. `MusicController`
6. `CiderMarketController`
7. `InventoryController`
8. `OfflineRateController`
9. `PlacementController`
10. `PickupController`
11. `SellController`
12. `ProductionStatusController`
13. `ResourceStatusController`
14. `ScytheController`
15. `AutoHarvestController`
16. `TeleportController`
17. `ShopController`
18. `WorldCiderMarketController`
19. `WorldShopTimerController`
20. `SettingsController`
21. `PlaytimeRewardsController`
22. `BottomNavController`

## Networking

Server code creates remotes under `ReplicatedStorage.GameRemotes` using `src/server/Networking/Remotes.luau` and names from `src/shared/Networking/RemoteNames.luau`.

Remote folders:

- `Inventory`
- `Placement`
- `Harvest`
- `Resources`
- `Economy`
- `Market`
- `Teleport`
- `Shop`
- `Settings`
- `PlaytimeRewards`
- `Tutorial`

Remote contract summary:

- Inventory: `InventoryUpdated`, `GetInventorySnapshot`, `SetSelectedSlot`, `AssignHotbarSlot`, `UnassignHotbarItem`
- Placement: `RequestPlacement`, `RequestPickup`, `RequestPickupAll`, `RequestSell`
- Harvest: `RequestScytheSwing`, `ScytheHarvestConfirmed`
- Resources: `ResourceUpdated`, `GetResourceSnapshot`
- Economy: `EconomyUpdated`, `GetEconomySnapshot`
- Market: `MarketUpdated`, `CiderMarketOpened`, `GetMarketSnapshot`, `SellAllCider`
- Teleport: `RequestTeleport`
- Shop: `ShopOpened`, `GetShopSnapshot`, `RequestShopPurchase`
- Settings: `GetSettingsSnapshot`, `SettingChanged`
- Playtime rewards: `PlaytimeRewardsUpdated`, `GetPlaytimeRewardsSnapshot`, `ClaimPlaytimeReward`
- Tutorial: `TutorialStepUpdated`, `TutorialTapContinue`, `TutorialSkipRequested`, `GetTutorialSnapshot`

Remote design rule:

- Clients may request intent, but the server validates ownership, distance, selected item, shop/product IDs, stock, cash, resource amounts, plot assignment, grid bounds, and overlap before mutating authoritative state.

## Player Data

Player data is centralized behind `PlayerDataService` and serialized by `PlayerDataStore`.

Important files:

- `src/server/Data/PlayerDataStore.luau`
- `src/server/Data/PlayerDataService.luau`

Current DataStore:

- Name: `FarmingEmpire_PlayerData_DEV`
- Current schema version: `10`
- Save attempts: `3`
- Retry delay: `2` seconds times attempt index
- Autosave interval: `120` seconds

Persisted schema:

- `schemaVersion`
- `economy.cash`
- `resources[ResourceId]`
- `placedBuildings[]`
- `placedBuildings[].buildingId`
- `placedBuildings[].gridX`
- `placedBuildings[].gridZ`
- `placedBuildings[].production`
- `inventory.entries[]`
- `inventory.hotbarSlots[]`
- `inventory.selectedSlotIndex`
- `offline.lastSeenAt`
- `offline.pendingCider`
- `offline.ciderPerSecondSnapshot`
- `settings.Music`
- `settings.SFX`
- `playtimeRewards.accumulatedPlaytimeSeconds`
- `playtimeRewards.claimedRewardIndexes`
- `playtimeRewards.totalClaims`

Persistence behavior:

- Data loads on player join and falls back to temporary unsaved default data if loading fails.
- Data is sanitized on load and before write.
- Player data saves on autosave, player leave, and `BindToClose`.
- Services can register before-save listeners for derived snapshots. Placement saves placed building/production state, offline earnings saves the current offline rate snapshot, and playtime rewards saves accumulated session time.
- Legacy daily reward data is migrated by reading a legacy daily rewards field into the current `playtimeRewards` structure when present.

## Catalogs And Config

Primary shared catalogs:

- Buildings: `src/shared/Buildings`
- Inventory: `src/shared/Inventory`
- Resources: `src/shared/Resources`
- Economy/market: `src/shared/Economy`
- Shops: `src/shared/Shops`
- Offline earnings: `src/shared/OfflineEarnings`
- Settings: `src/shared/Settings`
- Playtime rewards: `src/shared/PlaytimeRewards`
- Leaderboards: `src/shared/Leaderboards`
- Tools/harvest: `src/shared/Tools`, `src/shared/Harvest`

Current item IDs:

- Tool: `Scythe`
- Trees: `BasicTree`, `RubyAppleTree`, `GoldenAppleTree`, `CrystalAppleTree`
- Mills: `CiderMill`, `CopperCiderMill`, `SteelCiderMill`, `RoyalCiderMill`

Current building IDs match the placeable item IDs.

Current resources:

- `Apple`
- `Cider`

Starting inventory:

- `1` Scythe

Tutorial starter buildings:

- Current rollout: new and incomplete tutorials use `StarterKitV2`.
- `StarterKitV2` grants `1` `OakTree` and `1` `CiderMill` directly once per player before placement steps.
- Historical `ShopV1` support remains for existing funnel comparison and grants the first `OakTree` and `CiderMill` through free shop purchases when enabled.

Starting hotbar:

- Internal slot `1`: locked to `Scythe`
- Starter-kit grants are auto-assigned to open assignable hotbar slots by `InventoryService`.

## Building Design

Buildings are defined in `BuildingCatalog` and typed by `BuildingTypes`.

Tree family:

- Uses `TimedStorageProducer`
- Footprint fallback: `6, 6, 6`
- Asset folder: `BasicTree`
- Visual stages: `Stage0`, `Stage1`, `Stage2`, `Stage3`
- Produce interval: `5` seconds
- Output resource: `Apple`

Tree definitions:

| Building | Display Name | Sell Price | Apples/Interval | Storage Cap | Offline Cider/Sec |
| --- | --- | ---: | ---: | ---: | ---: |
| `BasicTree` | Apple Tree | 25 | 1 | 10 | 0.05 |
| `RubyAppleTree` | Ruby Apple Tree | 75 | 2 | 18 | 0.12 |
| `GoldenAppleTree` | Golden Apple Tree | 325 | 4 | 35 | 0.35 |
| `CrystalAppleTree` | Crystal Apple Tree | 1250 | 7 | 60 | 1 |

Mill family:

- Uses `InputProcessor`
- Footprint fallback: `8, 6, 8`
- Asset folder: `CiderMill`
- Visual stages: `Stage0`, `Stage1`
- Cycle duration: `1` second
- Input resource: `Apple`
- Output resource: `Cider`
- Output storage mode: unlimited
- Output is harvestable through walkover collection, not by scythe.

Mill definitions:

| Building | Display Name | Sell Price | Apple Input | Cider Output | Offline Cider/Sec |
| --- | --- | ---: | ---: | ---: | ---: |
| `CiderMill` | Cider Mill | 50 | 1 | 1 | 0.1 |
| `CopperCiderMill` | Copper Cider Mill | 175 | 1 | 2 | 0.3 |
| `SteelCiderMill` | Steel Cider Mill | 600 | 2 | 5 | 0.8 |
| `RoyalCiderMill` | Royal Cider Mill | 2250 | 3 | 10 | 2 |

Visual variants:

- Higher-tier trees and mills reuse the base asset folders and apply tint/material rules at clone time.
- Variant tinting matches part names such as leaf/leaves/canopy/apple/fruit/accent/trim/roof/body.
- If no tint rule matches, an optional fallback color/material is applied to visible parts.

## Asset Convention

Building assets are expected under `ReplicatedStorage.Buildings`.

Expected asset folders:

- `ReplicatedStorage.Buildings.BasicTree`
- `ReplicatedStorage.Buildings.CiderMill`

Expected stage models:

- `BasicTree.Stage0` through `BasicTree.Stage3`
- `CiderMill.Stage0` and `CiderMill.Stage1`

Stage model contract:

- Every stage model must contain a `BasePart` named `PlacementBox`.
- `PlacementBox` is used as the model primary part.
- `PlacementBox.Size` defines the placement footprint.
- The stage model is positioned by pivoting `PlacementBox` to the authoritative root part.
- `PlacementBox` is hidden in final visuals and previews.

Fallback behavior:

- Missing building folders or missing stage models create placeholder visuals.
- Missing `PlacementBox` still asserts because placement footprint and pivoting require it.

## Building Root Pattern

Placed buildings are represented by hidden root parts under `Workspace.PlacedObjects`.

Root attributes:

- `OwnerUserId`
- `PlotName`
- `PlotSlot`
- `ItemId`
- `GridX`
- `GridZ`
- Building/production attributes listed by `BuildingAttributeNames`

Root behavior:

- The root is transparent, anchored, non-colliding, touch-disabled, and queryable.
- The root size is the current placement footprint.
- The visible model is cloned below the root as `CurrentVisual`.
- Visual parts are anchored, non-colliding, non-queryable, non-touching, and shadow-disabled.
- Stage changes replace only `CurrentVisual`; the root remains stable for gameplay, selection, persistence, and UI.

This pattern keeps gameplay identity separate from visual presentation and lets production visuals change without replacing the authoritative object.

## Plots

Plots are assigned by `PlotService` using `PlotLocator`.

Important files:

- `src/shared/Plots/PlotLocator.luau`
- `src/server/Plots/PlotService.luau`

Plot behavior:

- Up to six plot slots are supported.
- Plots are read from `Workspace.Plots`.
- Slot assignment uses a `Slot` attribute when valid, otherwise normalizes plots into open slots.
- The first available supported plot is assigned to each joining player.
- Plot ownership is stored on plot attributes and mirrored onto player attributes.
- If all plots are full, new players are kicked with a capacity message.
- Players are teleported to their plot spawn on assignment and respawn.
- Plot ownership is released when the player leaves.

Plot attributes:

- `OwnerUserId`
- `OwnerPlayerName`
- `Slot`

Player attributes:

- `PlotSlot`
- `AssignedPlotName`

Supported plot model contract:

- Plot instance may be a `BasePart` or `Model`.
- Model plots should contain a placement base part named `Base`, `PlotBase`, `PlacementBase`, or `Ground`.
- Spawn part names supported by `PlotLocator` include `SpawnPoint`, `SpawnPart`, and `SpawnLocation`.

## Placement And Structure Actions

Placement is server-authoritative and grid-snapped.

Important files:

- `src/shared/Placement/PlotMath.luau`
- `src/server/Placement/PlacementService.luau`
- `src/client/Placement/PlacementController.luau`
- `src/client/Placement/PickupController.luau`
- `src/client/Placement/SellController.luau`
- `src/client/Placement/PlacedBuildingTargeting.luau`
- `src/client/Placement/StructureActionMode.luau`

Placement flow:

1. Client observes inventory and detects an equipped placeable.
2. Client raycasts or mobile-projects a placement point onto the assigned plot.
3. Client converts the point to plot-relative integer grid coordinates.
4. Client previews the stage model and checks local bounds/overlap for feedback.
5. Client sends `RequestPlacement(gridX, gridZ)`.
6. Server validates numeric whole grid coordinates, plot assignment, selected placeable item, footprint bounds, overlap, and inventory quantity.
7. Server consumes one item, creates a building root, registers it with production, and appends a persisted placed building record.

Grid rules:

- Coordinates are plot-relative integer center offsets.
- Placement uses `1` stud center movement.
- Footprint overlap is tested by `PlotMath.doFootprintsOverlap`.
- Placement is restricted to the player's assigned plot.

Pickup flow:

- Pickup mode clears selected hotbar state and targets owned placed building roots on the assigned plot.
- Single pickup validates ownership, plot, distance, and target instance.
- Pickup-all targets every owned root on the assigned plot.
- Pickup grants any stored output, returns one building item, unregisters production, destroys the root, and saves placed buildings.

Sell flow:

- Sell mode targets owned placed building roots on the assigned plot.
- Selling grants any stored output, grants the building `sellPrice` as cash, unregisters production, destroys the root, and saves placed buildings.

Interaction distance:

- Pickup and sell target validation currently use a `40` stud max distance.

## Inventory And Hotbar

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

State model:

- `quantitiesByItemId` stores item quantities.
- `hotbarSlots` stores item assignment by internal slot index.
- `selectedSlotIndex` stores equipped state.

Rules:

- Internal slots range from `1` through `10`.
- Slot `1` is permanently locked to `Scythe`.
- Player-facing keys `1-9` map to internal slots `2-10`.
- `Scythe` cannot be moved, replaced, cleared, or consumed.
- Placeable items can be assigned to assignable slots only if owned.
- Duplicate hotbar assignments are sanitized.
- If a quantity reaches `0`, related hotbar assignments are removed.
- Selecting the already selected filled slot deselects it.
- Empty slots cannot be selected.
- New item grants auto-assign to the hotbar when space exists.
- Inventory and hotbar state are persisted after initialization and mutation.

Client UI:

- Default Roblox backpack UI is disabled.
- Hotbar and inventory UI use Studio HUD objects where available and controller-rendered state.
- Inventory menu integrates with `FrameManager` under the `Menu` frame group.

## Tool Sync And Scythe

The `Scythe` inventory item is synchronized to a real Roblox `Tool`.

Important files:

- `src/server/Tools/ToolSyncService.luau`
- `src/client/Tools/ScytheController.luau`
- `src/shared/Tools/ScytheConfig.luau`
- `src/shared/Tools/ScytheSwingVolume.luau`

Behavior:

- Selecting `Scythe` clones `ReplicatedStorage.Tools.Scythe`.
- The clone is marked with `SystemToolItemId = "Scythe"`.
- The server parents the clone to the player's backpack and equips it through the humanoid when possible.
- Deselecting scythe or selecting another item removes system-owned scythe tools.
- Respawning while scythe is selected re-syncs the tool.
- Client activation plays local swing animation/sound and sends one `RequestScytheSwing`.

Scythe config:

- Cooldown: `0.5` seconds
- Swing half-angle: `60` degrees
- Swing range: `7` studs
- Vertical tolerance: `6` studs
- Server hit volume is approximated with seven box slices from `ScytheSwingVolume`.

## Production

Production is a server-side behavior framework.

Important files:

- `src/server/Production/ProductionService.luau`
- `src/server/Production/ProductionBehaviorRegistry.luau`
- `src/server/Production/Behaviors/GrowAndHarvestBehavior.luau`
- `src/server/Production/Behaviors/TimedStorageProducerBehavior.luau`
- `src/server/Production/Behaviors/InputProcessorBehavior.luau`

Design:

- `ProductionService` tracks placed building roots.
- Building definitions choose a production behavior.
- Runtime state is separate from shared building definitions.
- Runtime state can be serialized into saved production state for persistence.
- The production loop updates every `0.25` seconds.
- The service writes production attributes to root parts for client UI and other systems.
- Visual stage changes are derived from `BuildingCatalog.getGrowthStageForProgress`.
- Production behavior context exposes typed resource functions.

Production attributes:

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

`TimedStorageProducer`:

- Used by all tree definitions.
- Adds stored output every produce interval until storage cap.
- Progress is storage fill ratio.
- Ready-to-harvest is true when stored amount is greater than zero.
- Scythe harvest returns the stored output and resets production.
- Saved state stores stored amount and seconds until next produce.

`InputProcessor`:

- Used by all mill definitions.
- Attempts to consume input from the owner when not processing.
- If input is available, processes for the configured cycle duration.
- On completion, output is added to local building storage.
- Stored output is harvestable through behavior `harvest`, currently collected by walkover collection.
- Saved state stores stored output and remaining cycle time when processing.

`GrowAndHarvest`:

- Legacy behavior still registered.
- Not currently used by `BuildingCatalog`.

## Harvesting And Collection

Manual harvesting:

- `ScytheController` sends `RequestScytheSwing`.
- `HarvestService` validates cooldown, selected scythe, character root, owned roots, assigned plot, and harvestable production behavior.
- The server harvests matching roots in the scythe hit volume through `ProductionService.tryHarvestPlacedBuilding`.
- Harvest outputs are granted through `ResourceService`.
- If any harvest succeeds, `ScytheHarvestConfirmed` is sent to the client for feedback.

Auto-harvest:

- Active implementation is client-side in `AutoHarvestController` and `AutoHarvestNavigator`.
- It is visible only while scythe is selected.
- The client scores ready apple-producing targets, pathfinds/moves the humanoid toward a selected target, plays a local swing, and fires the normal scythe swing remote.
- Server authority remains with `HarvestService`; auto-harvest does not bypass selected-tool, ownership, plot, cooldown, or hit-volume checks.
- Movement input, character removal, or deselecting scythe cancels auto-harvest.

Walkover collection:

- `WalkoverCollectionService` tracks roots whose production behavior is `InputProcessor`.
- Every `0.15` seconds it checks player root parts against collectable building bounds.
- Owned processor output on the assigned plot is harvested through `ProductionService.tryHarvestPlacedBuilding` and granted as resources.
- Per-player/per-part collection cooldown is `0.25` seconds.

## Resources And Economy

Resource service:

- `ResourceService` is the authoritative wrapper around persistent resource amounts.
- It supports get, add, consume, snapshots, client updates, and resource-added observers.
- Resource snapshots include all configured resources.

Economy service:

- `EconomyService` is the authoritative wrapper around persistent cash.
- It supports add, spend, get, snapshots, client updates, and cash-changed observers.
- Cash and resources are stored in `PlayerDataService`.

Resource/economy client UI:

- `ResourceStatusController` combines economy and resource snapshots.
- `ResourceStatusView` displays cash, apples, and cider.
- Resource/cash gain toasts and sounds are produced by `ResourceGainToastView` and `ResourceGainSoundPlayer`.

## Market

The active market supports selling cider for cash.

Important files:

- `src/shared/Economy/MarketConfig.luau`
- `src/shared/Economy/MarketPriceRank.luau`
- `src/server/Market/MarketService.luau`
- `src/server/Market/CiderSellService.luau`
- `src/client/Market/CiderMarketController.luau`
- `src/client/Market/CiderMarketView.luau`
- `src/client/Market/WorldCiderMarketController.luau`

Config:

- Price change interval: `30` seconds
- Min cider sell price: `5`
- Max cider sell price: `15`

Behavior:

- Server rolls current cider price and next change time.
- Re-rolled prices avoid repeating the previous price when the configured range allows it.
- Market snapshots include `ciderSellPrice` and `nextPriceChangeAt`.
- Market updates are broadcast to all clients.
- `Workspace.CiderSell.Touch` opens the cider market UI through `CiderSellService`.
- `SellAllCider` validates the player is close to `Workspace.CiderSell.Touch`, consumes all cider, and grants cash.
- World market UI can display current price and timer.

## Shops

Shops sell placeable items for cash.

Important files:

- `src/shared/Shops/ShopTypes.luau`
- `src/shared/Shops/ShopCatalog.luau`
- `src/server/Shops/ShopService.luau`
- `src/client/Shops/ShopController.luau`
- `src/client/Shops/ShopMenuView.luau`
- `src/client/Shops/WorldShopTimerController.luau`

Current shops:

- `TreesShop`
- `MillsShop`

Shop contract:

- Each shop has a `Workspace` model named by `worldModelName`.
- Each shop model has a touch part named `Touch`.
- Each shop has a restock GUI named `RestockGUI` with `NameLabel` and `TimerLabel`.

Server behavior:

- Shop state is per-player and held in server memory.
- Restock interval is `5` minutes.
- A shop touch opens the menu for that player.
- Purchase requests validate shop, product, stock, distance, quantity, and cash.
- Successful purchases spend cash, decrement stock, add inventory, and return a fresh shop snapshot.

Current product families:

- Trees shop sells all four tree items.
- Mills shop sells all four mill items.

## Offline Earnings

Offline earnings grant pending cider based on placed building rates.

Important files:

- `src/shared/OfflineEarnings/OfflineEarningsConfig.luau`
- `src/shared/OfflineEarnings/OfflineCiderRateCalculator.luau`
- `src/server/OfflineEarnings/OfflineEarningsService.luau`
- `src/client/Offline/OfflineRateController.luau`
- `src/client/Offline/OfflineRateView.luau`

Config:

- Max offline window: `12` hours
- Minimum offline seconds to reward: `5`
- Max pending cider: `1,000,000`

Behavior:

- Before save, the service snapshots current cider-per-second based on persisted placed buildings.
- On join, it computes offline seconds from `lastSeenAt`, clamps by max window, and adds pending cider up to the cap.
- Pending cider is displayed on each player's assigned plot offline plate.
- Touching the assigned plot's offline plate claims pending cider into live resources.

Studio plot contract:

- Each plot should contain `OfflineEarningsPlate`
- The plate should contain `Touch`
- The plate should contain a GUI named `RestockGUI`
- The GUI should contain `NameLabel` and `OfflineEarnings`

## Playtime Rewards

Playtime rewards are persistent, claimable rewards based on accumulated playtime.

Important files:

- `src/shared/PlaytimeRewards/PlaytimeRewardsTypes.luau`
- `src/shared/PlaytimeRewards/PlaytimeRewardsConfig.luau`
- `src/server/PlaytimeRewards/PlaytimeRewardsService.luau`
- `src/client/PlaytimeRewards/PlaytimeRewardsController.luau`
- `src/client/PlaytimeRewards/PlaytimeRewardsView.luau`

Current cycle:

- Seven rewards
- Reward 1 is immediately claimable
- Later rewards unlock at 10, 20, 30, 40, 50, and 60 minutes
- Reward entries can grant cash, resources, or inventory items

Behavior:

- Session time is accumulated from server time.
- Before save, current session playtime is folded into persisted progress.
- Snapshot includes current playtime, reward state, next remaining time, total claims, and claimable reward index.
- Claiming grants the first unclaimed reward whose required playtime has been reached.

## Settings And Audio

Settings are persistent player preferences.

Important files:

- `src/shared/Settings/SettingsConfig.luau`
- `src/server/Settings/SettingsService.luau`
- `src/client/Settings/SettingsController.luau`
- `src/shared/Audio/AudioBus.luau`
- `src/shared/Audio/MusicPlaylist.luau`
- `src/client/Audio/AudioService.luau`
- `src/client/Audio/MusicController.luau`

Current settings:

- `Music`: default `0.5`, step `0.05`
- `SFX`: default `0.5`, step `0.05`

Behavior:

- Client loads saved settings through `GetSettingsSnapshot`.
- Slider changes apply immediately to local `SoundGroup` volume and debounce-save to the server.
- `AudioService` creates or reuses `SoundService.Music` and `SoundService.SFX` sound groups.
- `MusicController` creates or reuses `SoundService.BackgroundMusic` and shuffles through configured track IDs without immediately repeating the last track when possible.

## Teleport

Teleport buttons request server-side character pivoting.

Important files:

- `src/server/Teleport/TeleportService.luau`
- `src/client/Teleport/TeleportController.luau`

Destinations:

- `Plot`: assigned plot spawn
- `Shop`: first workspace `BasePart` named `ShopTeleport`
- `Sell`: first workspace `BasePart` named `SellTeleport`

Behavior:

- Client buttons under the HUD fire `RequestTeleport`.
- Server validates destination and applies a `0.25` second per-player cooldown.
- Character is pivoted to destination part CFrame plus a small upward offset.

## UI Architecture

The client uses several common UI helpers:

- `FrameManager`: registers open/close/toggle frames, enforces one open frame per group, and animates panel positions.
- `BottomNavController`: hides the hotbar when another menu frame in the `Menu` group is open.
- `ButtonHoverController`: central hover styling.
- `CloseButtonController`: shared close button behavior.
- `HudTooltip`: shared HUD tooltip ownership.
- `Slider`: reusable slider input abstraction.

The current UI is not fully generated from code. Many controllers require Studio-authored hierarchy under `PlayerGui.GUI`.

Common Studio GUI assumptions include:

- `PlayerGui.GUI`
- `GUI.HUD`
- `GUI.HUD.Inventory.hotBar`
- `GUI.HUD.Left.Settings`
- `GUI.HUD.Right.Pickup`
- `GUI.HUD.Right.Sell`
- `GUI.HUD.BottomRight.AutoScythe`
- `GUI.HUD.BottomRight.PickupAll`
- `GUI.HUD.Top.Buttons.PlotTeleport`
- `GUI.HUD.Top.Buttons.ShopTeleport`
- `GUI.HUD.Top.Buttons.SellTeleport`
- `GUI.Frames.Settings`
- shop, market, inventory, and playtime reward frames expected by their controllers/views

Templates expected in `ReplicatedStorage.Templates`:

- `ItemCollected`
- `LeaderboardEntry`

## Leaderboards

Leaderboards use OrderedDataStores and Studio-authored display boards.

Important files:

- `src/shared/Leaderboards/*LeaderboardConfig.luau`
- `src/server/Leaderboards/AccumulatingLeaderboardServiceFactory.luau`
- `src/server/Leaderboards/NumberLeaderboardStoreFactory.luau`
- `src/server/Leaderboards/NumberLeaderboardRendererFactory.luau`
- `src/server/Leaderboards/LeaderboardTemplateRenderer.luau`

Current boards:

- `CashLeaderboard`
- `TimeSpentLeaderboard`
- `ApplesEarnedLeaderboard`
- `CiderEarnedLeaderboard`
- `RobuxSpentLeaderboard`

Current OrderedDataStores:

- `FarmingEmpire_CashLeaderboard_DEV`
- `FarmingEmpire_TimeSpentLeaderboard_DEV`
- `FarmingEmpire_ApplesEarnedLeaderboard_DEV`
- `FarmingEmpire_CiderEarnedLeaderboard_DEV`
- `FarmingEmpire_RobuxSpentLeaderboard_DEV`

Behavior:

- Cash leaderboard tracks latest cash value from `EconomyService`.
- Time spent leaderboard tracks session seconds and periodically writes totals.
- Apples and cider earned leaderboards increment from `ResourceService.observeResourceAdded`.
- Robux spent leaderboard exposes `recordRobuxSpent`, but visible code does not currently call it.
- Renderers merge stored top entries with online players for responsive display.
- Rows clone `ReplicatedStorage.Templates.LeaderboardEntry` into the board's `ScrollingFrame`.

Leaderboard Studio contract:

- `Workspace.<LeaderboardModelName>`
- Descendant named `Board`
- `Board` contains a `SurfaceGui`
- `SurfaceGui` contains a `ScrollingFrame`
- Template row contains `RankLabel`, `NameLabel`, `ScoreLabel`, and `PlayerImage`

## Admin

Admin commands use bundled Cmdr under `src/server/Vendor/Cmdr`.

Important files:

- `src/server/Admin/CmdrService.luau`
- `src/shared/Admin/AdminConfig.luau`
- `src/server/Admin/CmdrCommands`
- `src/server/Admin/CmdrTypes`

Behavior:

- Cmdr default commands, custom commands, and custom types are registered on server start.
- A `BeforeRun` hook blocks non-admin users.
- Current admin user IDs are configured in `AdminConfig`.
- Current custom commands include giving cash and giving buildings.

## Studio Object Contracts

The code assumes these non-code objects exist unless noted otherwise.

World:

- `Workspace.Plots`
- Up to six assignable plot instances
- Plot placement base and spawn parts using supported names
- `Workspace.CiderSell.Touch`
- `Workspace.TreesShop.Touch`
- `Workspace.MillsShop.Touch`
- `Workspace.ShopTeleport`
- `Workspace.SellTeleport`
- Leaderboard models listed in the leaderboard section

ReplicatedStorage:

- `ReplicatedStorage.Buildings.BasicTree`
- `ReplicatedStorage.Buildings.CiderMill`
- Stage models with `PlacementBox`
- `ReplicatedStorage.Tools.Scythe`
- `ReplicatedStorage.Tools.Scythe.Swing`
- `ReplicatedStorage.Templates.ItemCollected`
- `ReplicatedStorage.Templates.LeaderboardEntry`

Player GUI:

- `PlayerGui.GUI` and the HUD/frame hierarchy used by inventory, placement actions, settings, teleport, shops, market, offline rate, and playtime rewards controllers.

Runtime-created by code:

- `ReplicatedStorage.GameRemotes`
- Remote folders and remotes under `GameRemotes`
- `Workspace.PlacedObjects`
- `SoundService.Music`
- `SoundService.SFX`
- `SoundService.BackgroundMusic`
- Placeholder building stage models when folders/stages are missing

## Core Data Flows

Placement and production:

1. Inventory selects a placeable item.
2. Client previews a grid-snapped building on the assigned plot.
3. Server validates and creates a hidden building root.
4. Server registers the root with production.
5. Production updates runtime state, root attributes, and visuals.
6. Client production UI observes replicated root attributes.
7. Before save, placement serializes roots plus saved production states.

Apple flow:

1. Tree production stores apples up to its cap.
2. Root attributes mark stored amount and readiness.
3. Player swings scythe manually or auto-harvest moves and swings.
4. Server harvest validation grants apples through `ResourceService`.
5. Resource snapshots update the client and apple-earned leaderboard.

Cider flow:

1. Mill production consumes apples and stores cider output.
2. Walkover collection harvests stored processor output.
3. `ResourceService` grants cider and updates the cider-earned leaderboard.
4. Player opens cider market near `Workspace.CiderSell.Touch`.
5. `SellAllCider` consumes cider and grants cash.
6. Economy snapshots update the client and cash leaderboard.

Shop flow:

1. Player touches a shop touch part.
2. Server sends the shop snapshot and opens the shop UI.
3. Client requests a purchase.
4. Server validates distance, product, stock, and cash.
5. Server spends cash, decrements stock, grants item, and returns a new snapshot.

Offline flow:

1. Before save, current placed buildings are converted into a cider-per-second snapshot.
2. On next join, elapsed offline seconds are multiplied by the saved or current rate.
3. Pending cider is stored up to the configured cap.
4. Player touches their offline plate to claim pending cider.

## Extension Guidelines

Adding a new placeable building generally requires:

- Add item ID and item definition in `InventoryTypes` and `ItemCatalog`.
- Add building ID and building definition in `BuildingTypes` and `BuildingCatalog`.
- Choose or add a production behavior.
- Add shop product entries if the item should be purchasable.
- Add Studio assets under `ReplicatedStorage.Buildings`, or intentionally rely on placeholders.
- Add offline earning config if it should contribute to offline cider.

Adding a new resource generally requires:

- Add resource ID and definition in `ResourceTypes` and `ResourceCatalog`.
- Extend production, rewards, shops, market, and UI where the resource should appear.
- Update persistence sanitization expectations through the existing resource catalog path.

Adding a new menu/UI frame should:

- Use `FrameManager.registerFrame`.
- Choose a frame group when it should be mutually exclusive with other menus.
- Keep server state authoritative and treat UI as local presentation.

Adding a new DataStore-backed system should:

- Route player-owned persistent state through `PlayerDataService` when it belongs to the player's profile.
- Use dedicated OrderedDataStore services only for global ranked values.
- Sanitize all loaded data and clone outgoing data before save.

## Design Rules

Established project rules:

- Server owns gameplay truth and validation.
- Client owns presentation, previews, local effects, and ergonomic input.
- Shared modules own contracts, types, config, catalogs, and pure helpers.
- Game state should flow through services and player data, not hidden script-local state.
- Building roots are authoritative; visuals are replaceable children.
- Placement truth comes from `PlacementBox`.
- Production runtime state is behavior-owned and definition-driven.
- Resources are separate from inventory items.
- Cash is economy state, not a resource.
- Persistent state should be sanitized and accessed through `PlayerDataService`.
- Expansion should be catalog-driven whenever possible.

## Known Gaps And Risks

- No automated test suite is visible in the repository.
- Some UI code still depends on exact Studio hierarchy names and will assert if objects are missing.
- Market and sell UI are cider-specific.
- Shop stock is not persisted.
- Plot assignment is not persisted.
- Offline earnings are an approximation based on configured building rates.
- `AutoHarvestService` under server harvest appears inactive and out of sync with current `Remotes`; active auto-harvest relies on `HarvestService`.
- Current building variants reuse base tree/mill assets and tint them; unique models for each tier would require more asset folders or catalog support.
- DataStore names are currently suffixed with `_DEV`.

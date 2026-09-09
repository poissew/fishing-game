# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A 3D fishing game built with **Godot 4.6** (GL Compatibility renderer). The main scene is `main.tscn`.

## Running the Game

Open the project in the Godot 4.6 editor and press **F5** (Run Project) or use the editor's play button. There is no CLI build command — all development happens through the Godot editor.

## Architecture

### Autoloads (global singletons)

Four autoloaded nodes are accessible from any script by name:

| Name | File | Purpose |
|------|------|---------|
| `Itemdb` | `autoload/itemDB.tscn` + `item_db.gd` | Registry of all `Item` resources, keyed by integer `id`. Use `Itemdb.get_item(id)` |
| `Tablesdb` | `autoload/tablesDB.tscn` + `autoload/tables_db.gd` | Registry of all `LootTable` resources, keyed by string `id`. Use `Tablesdb.get_table(id)` |
| `randomizer` | `randomizer.gd` | Shared `RandomNumberGenerator` instance. Use `randomizer.RNG` |
| `options` | `options.gd` | Global settings (e.g. `options.MOUSE_SENS`) |

### Data / Resource hierarchy

```
Item (Resource)           — base item: id, name, icon, size, rotatable
├── FishData              — adds min/max size, base_value, mesh, rarity, price_curve
└── RodData               — adds power, durability_max, reel_speed

ItemInstance (Resource)   — runtime placement: data ref + grid position + rotated flag
├── FishInstance          — adds size, weight, quality; has create_fish_instance(FishData)
└── RodInstance           — adds durability; has create_rod_instance(RodData)
```

### Loot system

- `LootEntry` (Resource) — holds an `Item`, `weight`, `min_amount`, `max_amount`
- `LootTable` (Resource) — holds an array of `LootEntry`; `pick_entry(rng)` does weighted random draw
- `Tablesdb` maps string IDs (`"default"`, `"tropical"`, `"atlantic"`) to `LootTable` resources
- Water `Area3D` nodes carry group tags (`water`, optionally `atlantic`/`tropical`/`mud`/`lava`) to select the right table

### Fishing loop

1. **Player** (`classes/player.gd`, `CharacterBody3D`) — on `left_click`, calls `cast_bobber()` which spawns a `Bobber` into the scene
2. **Bobber** (`scripts/bobber.gd`, `RigidBody3D`) — state machine: `IN_AIR → IN_WATER → BITE → REELING`
   - On entering a `water` group `Area3D`, sets its `LootTable` from `Tablesdb` and starts the `TimeToFish` timer
   - Timer expiry → `BITE` state; player presses **right-click** → `REELING`
   - On reel, calls `LootTable.pick_entry()` then emits `loot_rolled(item, amount)` back to Player
3. **Player** receives `loot_rolled`, creates `FishInstance` objects via `FishInstance.create_fish_instance()`

### Inventory

- `Inventory` (Resource) — 2D grid (width × height) of `ItemInstance`; supports `place_item`, `rotate_item`, `try_place_anywhere`
- `UIInventory` (`classes/ui/UI_Inventory.gd`, Control) — bound to an `Inventory` via `bind_inventory()`; emits `item_requested_equip`
- `InventorySlot` (`classes/ui/InventorySlot.gd`, Panel) — individual cell, draws item icon

### Hands

- `Hands` (Resource) — two slots (`Hands.Slot.LEFT` / `RIGHT`), each holding one `ItemInstance` or null; emits `changed`
- `HandsViewmodel` (`classes/hands_viewmodel.gd`, Node3D) — in-world first-person viewmodel under `head/Camera3D` in `Player.tscn`, with `LeftHand` / `RightHand` anchor Node3Ds. There is no hands HUD
- It instantiates the item's real 3D model: `FishData.mesh` for fish, `objects/Rod.tscn` for rods. Fish are scaled by `FishInstance.size * MODEL_SCALE`, the same convention as `Fish._apply_random_scale()`, so a big catch is visibly big
- Pose the hands by moving the anchor Node3Ds in the editor — nothing in the script hardcodes their placement
- `get_screen_rect()` / `slot_at()` unproject an anchor through the camera so `UIInventory` can still drag items into and out of a hand; the zones are only drawn mid-drag
- Hands are the source of truth for what is equipped: `Player.equipped_rod` is a read-only property backed by `hands.get_rod()`
- Use `Player.equip_item(item, slot)` / `unequip_slot(slot)` to move items between hands and inventory
- While the inventory is open, items can be dragged between the grid and the hand slots; `E` on a held item equips it

### Input map

| Action | Key/Button |
|--------|-----------|
| `forward/backward/left/right` | WASD |
| `left_click` | Mouse left — cast bobber |
| `right_click` | Mouse right — reel in (when in BITE state) |
| `pause` | Escape — quits game |
| `interact` | E |
| `open_inventory` | F2 |

### Physics layers

- Layer 1: `Ground`
- Layer 2: `Water`

## Key Conventions

- Data (static properties) lives in `*Data` / `Item` **Resources** (`.tres` files), stored in `classes/`.
- Runtime state lives in `*Instance` **Resources** that wrap a `data` reference.
- All random rolls go through `randomizer.RNG` (the shared, pre-seeded `RandomNumberGenerator`).
- Water biome is determined by `Area3D` groups on the water body; the `Bobber` reads those groups on entry.
- New fish species: create a `FishData` resource (`.tres`), add a `LootEntry` referencing it to the appropriate `LootTable`, and register it in `Itemdb` if it needs to be retrievable by ID.

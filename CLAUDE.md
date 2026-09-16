# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A 3D fishing game built with **Godot 4.6** (GL Compatibility renderer). The main scene is `main.tscn`.

## Running the Game

Open the project in the Godot 4.6 editor and press **F5** (Run Project) or use the editor's play button. There is no CLI build command — all development happens through the Godot editor.

## Architecture

### Autoloads (global singletons)

Six autoloaded nodes are accessible from any script by name:

| Name | File | Purpose |
|------|------|---------|
| `Itemdb` | `autoload/itemDB.tscn` + `item_db.gd` | Registry of all `Item` resources, keyed by integer `id`. Use `Itemdb.get_item(id)` |
| `Tablesdb` | `autoload/tablesDB.tscn` + `autoload/tables_db.gd` | Registry of all `LootTable` resources, keyed by string `id`. Use `Tablesdb.get_table(id)` |
| `randomizer` | `randomizer.gd` | Shared `RandomNumberGenerator` instance. Use `randomizer.RNG` |
| `options` | `options.gd` | Global settings (e.g. `options.MOUSE_SENS`) |
| `daynight` | `autoload/day_night.gd` | Day/night clock. `daynight.is_night()`, `hour_of_day()`, `time_string()`, signals `phase_changed` / `hour_passed` / `day_passed` |
| `gamephase` | `autoload/game_phase.gd` | Which half of the round the game is in: `is_fishing()` / `is_selecting()` / `is_battling()`, signals `phase_changed` / `selection_started` / `battle_started` / `battle_ended` |

### Data / Resource hierarchy

```
Item (Resource)           — base item: id, name, icon, size, rotatable
├── FishData              — adds min/max size, base_value, rarity, price_curve, fighting data
└── RodData               — adds power, durability_max, reel_speed

ItemInstance (Resource)   — runtime placement: data ref + grid position + rotated flag
├── FishInstance          — adds size, weight, quality, fighting stats, current_health; has create_fish_instance(FishData)
└── RodInstance           — adds durability; has create_rod_instance(RodData)

SpellData (Resource)      — static spell definition: name, base_power, base_type, base_cooldown
SpellInstance (Resource)  — runtime spell: data ref + cooldown_left; tick/is_ready/try_cast
SpellType (RefCounted)    — Type enum (PHYSICAL, FIRE, ICE, WATER, LIGHTNING, POISON, ARCANE)
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

### Game phases

The game runs in rounds: a day of fishing, then one fish sent to fight.

```
FISHING  ──day runs out──>  SELECTION  ──fish picked──>  BATTLE  ──end_battle()──>  FISHING (next day)
```

- `gamephase` (`autoload/game_phase.gd`) is the state machine and nothing else — like `daynight` it owns no scene, no UI and no reference to the player. It listens to `daynight.day_passed` (the 20-minute cycle wrapping is what ends the fishing day), freezes `daynight.time_scale` for the whole of SELECTION and BATTLE, and sets it running again on the way back to FISHING.
- Note `gamephase.phase_changed(phase)` and `daynight.phase_changed(is_day)` are different signals: the first is fishing/selection/battle, the second is day/night.
- **Player** is the one that drives the screens: it connects to `selection_started` / `battle_started` / `battle_ended`, closes whatever panel was open, and shows `UIFishSelect` then `UIBattle`. Movement, casting and the debug keys are all gated on `gamephase.is_fishing()`, and any bobber still in the water when the day ends is freed.
- `UIFishSelect` (`classes/ui/UI_FishSelect.gd` + `ui/UI_FishSelect.tscn`) lists everything in `Player.carried_fish()` — inventory grid plus hands — with its combat stats (HP / PHYS / MAG / spell count), strongest first. Click or arrow-keys to pick, Enter or the button to send. With no fish on the player the button becomes SKIP BATTLE and `gamephase.skip_battle()` goes straight to the next day.
- `UIBattle` (`classes/ui/UI_Battle.gd` + `ui/UI_Battle.tscn`) is **a placeholder for the arena**, not the arena: it holds the BATTLE phase open, shows the champion, and closes the round out on Enter. **Building the arena means replacing it** — connect to `gamephase.battle_started(fish)`, run the fight, then call `gamephase.end_battle(won)`. Nothing else in the game reaches into that file.
- The champion is not consumed: `send_to_battle()` calls `reset_health()` on it and it stays in the inventory. A fish that comes back dead or beaten is removed from whatever the player was carrying it in (`Player._on_battle_ended`).
- `daynight.end_day()` runs the rest of the current day out and fires `day_passed`, which is how F3 (second press, at night) reaches the battle without sitting out 20 minutes. `skip_to_day()` still only repositions the clock and does *not* end the day.

### Day/night cycle

- One cycle is **20 real minutes**: `DAY_LENGTH` 600 s of daylight (06:00 → 18:00) then `NIGHT_LENGTH` 600 s of night (18:00 → 06:00). Time runs uniformly, so one in-game hour is 50 real seconds.
- `daynight` (autoload) is the clock and nothing else — no scene or rendering dependencies. Query `is_day()` / `is_night()` / `hour_of_day()`, or connect to `phase_changed(is_day)`, `hour_passed(hour)`, `day_passed(day)`. `cycle_progress()` returns 0.0 at dawn, 0.25 at noon, 0.5 at dusk, 0.75 at midnight.
- `set_time_of_day(hour)` jumps the clock; `time_scale` speeds it up or freezes it (handy for eyeballing a whole cycle without waiting 20 minutes).
- `DayNightLighting` (`classes/day_night_lighting.gd`, Node3D) is the visual side, sitting in `levels/trees.tscn` as `DayNightCycle` with its `sun` export pointed at the `DirectionalLight3D`. It reads the clock each frame; the clock never pushes to it.
- Because the game is sprite-first, **most of the scene ignores lights** — the ground is `SHADING_MODE_UNSHADED`, trees and held items are `Sprite3D`. So the cycle is carried mainly by a full-screen `ColorRect` multiplied over the viewport (`CanvasLayer` at layer `-1`: above the 3D world, below the UI on layer 0). It lives inside the low-res `SubViewport`, so it pixelates with everything else. Daytime tint is white, i.e. a no-op.
- The sun and moon share one arc: each rises at the start of its phase, sits overhead halfway through, and sets at the end. Light colour, energy and sky dimming all interpolate continuously through dawn and dusk — `twilight_energy_ratio` is the shared floor both phases fade to, which is what stops the light popping at the handover.
- `Camera3D` in `Player.tscn` carries its **own** `Environment`, which overrides the level's `WorldEnvironment`. `DayNightLighting._resolve_environment()` asks the current camera first for that reason.
- `UIDayTimer` (`classes/ui/UI_DayTimer.gd` + `ui/UI_DayTimer.tscn`) is the centre-top countdown: real time left in the current day as MM:SS, starting each dawn at `20:00` and rolling over at `00:00`. It reads `daynight.time_left_in_day()` and draws with the shared `UIFont` (see **Text**), at `UIFont.SIZE * 2` so the countdown reads bigger than the panels.
- `UIDayNightIcon` (`classes/ui/UI_DayNightIcon.gd` + `ui/UI_DayNightIcon.tscn`) is the top-right HUD readout: `ui/icons/sun.png` spinning on itself while the sun is up, swapped for `ui/icons/lune.png` pulsing dim→bright→dim once it sets. Both run off one `spin_period`, so the two phases share a tempo. `Player` instantiates it **before** the inventory and shop so their full-screen dimming backgrounds draw over it.

### Text

- Everything in the game is set in **monogram** (`ui/fonts/monogram.ttf`), a pixel font.
- `UIFont` (`classes/ui/ui_font.gd`) is the single accessor for scripts that draw their own
  text: `UIFont.FONT`, `UIFont.SIZE` (16) and `UIFont.CAP_H` (7, the height of a capital above
  the baseline — `draw_string` positions by baseline, so this is what you need to centre text
  in a bar of a known height).
- Control nodes (`Label` and friends) get the same file from the `gui/theme/custom_font`
  project setting instead, so a newly added Control is already right without touching `UIFont`.
  Leave their `font_size` alone: Godot's default is already 16.
- **Only whole multiples of `UIFont.SIZE` are usable.** monogram is drawn on a 16px grid — 5px
  glyphs on a 6px monospaced advance, caps 7px, descenders 2px below the baseline. Anything in
  between puts glyphs on half pixels, which is glaring at 480x270.
- That 6px advance makes text noticeably wider than a proportional font would be, so panel
  widths and column offsets in `UIInventory` / `UIShop` are sized in whole characters.
- The pixel-crispness (no antialiasing, no hinting, no subpixel positioning, no oversampling)
  lives in `ui/fonts/monogram.ttf.import`, not in any script.

### Inventory

- `Inventory` (Resource) — 2D grid (width × height) of `ItemInstance`; supports `place_item`, `rotate_item`, `try_place_anywhere`
- `UIInventory` (`classes/ui/UI_Inventory.gd`, Control) — bound to an `Inventory` via `bind_inventory()`; draws the whole panel and grid itself in `_draw()`; emits `item_requested_equip`

### Hands

- `Hands` (Resource) — two slots (`Hands.Slot.LEFT` / `RIGHT`), each holding one `ItemInstance` or null; emits `changed`
- `HandsViewmodel` (`classes/hands_viewmodel.gd`, Node3D) — in-world first-person viewmodel under `head/Camera3D` in `Player.tscn`, with `LeftHand` / `RightHand` anchor Node3Ds. There is no hands HUD
- Every held item is a `Sprite3D` of its `Item.icon` (nearest filtering, `ALPHA_CUT_DISCARD` so it writes depth for the edge shader), falling back to `icon.svg`. New item types need no viewmodel code — just an icon
- A held fish's world height comes from `FishInstance.size` over a `sqrt` curve clamped to `FISH_MIN_H`..`FISH_MAX_H`, so a big catch is visibly big without filling the view; everything else uses `ITEM_BASE_H`
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
| `open_inventory` | Tab |
| `debug_skip_time` | F3 — dev only: skip to nightfall, again to end the day (which starts the battle phase) |
| `ui_up` / `ui_down` / `ui_accept` | Godot built-ins — move and confirm the pick on the end-of-day screens |

### Physics layers

- Layer 1: `Ground`
- Layer 2: `Water`

## Key Conventions

- Data (static properties) lives in `*Data` / `Item` **Resources** (`.tres` files), stored in `data/`.
- The game is sprite-only: items are drawn from their `Item.icon`, there are no 3D meshes for fish or held items.
- All text is monogram at `UIFont.SIZE` (or a whole multiple of it) — see **Text**.
- Runtime state lives in `*Instance` **Resources** that wrap a `data` reference.
- All random rolls go through `randomizer.RNG` (the shared, pre-seeded `RandomNumberGenerator`).
- Water biome is determined by `Area3D` groups on the water body; the `Bobber` reads those groups on entry.
- New fish species: create a `FishData` resource (`.tres`), add a `LootEntry` referencing it to the appropriate `LootTable`, and register it in `Itemdb` if it needs to be retrievable by ID.

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

SpellData (Resource)      — static spell definition: name, trigger, base_power, base_type, base_cooldown
├── ExplosionSpellData    — adds damage_scale, radius, knockback_scale, frames; an ON_HIT blast
├── BubbleSpellData       — adds count, hang_time, speed, max_range; an AT_JUMP_PEAK volley
└── CowardSpellData       — adds flee_bias; a PASSIVE, never cast, read off the fish
SpellInstance (Resource)  — runtime spell: data ref + cooldown_left; tick/is_ready/try_cast
SpellType (RefCounted)    — Type enum (PHYSICAL, FIRE, ICE, WATER, LIGHTNING, POISON, ARCANE)
SpellExplosion (AnimatedSprite3D) — the animation a blast draws; plays once, frees itself
SpellBubble (Sprite3D)    — one bubble in flight; moves itself, pops on the first fish it may hit
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

### Battle fish

- `BattleFish` (`classes/battle_fish.gd` + `objects/BattleFish.tscn`, `RigidBody3D`) is one fish inside the arena. `BattleFish.spawn(fish_instance)` builds one; `bind_fish()` is what reads a `FishInstance` and turns it into a body — icon → `Sprite3D`, `size` → world length nose to tail (the viewmodel's clamped `sqrt` curve, measured along the icon's width because fish icons are long and shallow), `weight` → `mass`, `phys_dmg` → contact damage, `health` → the pool it fights on.
- The `FishInstance` stays the source of truth: damage goes through `FishInstance.take_damage()`, so the fish that fought is the same object the player carries home, and `UIFishSelect`/`UIBattle` read the same numbers. `bind_fish()` calls `reset_health()`, so a fish always enters the arena full.
- **Contact is the attack.** Touching another `BattleFish` deals this fish's `phys_dmg` to it (`body_entered`), and because both bodies see the same collision they trade damage both ways. `HIT_COOLDOWN` per opponent is what stops two fish resting against each other from draining one another every frame. `team` (−1 = free-for-all) decides who is allowed to hit whom.
- **Every hit knocks its target back**, away from whoever landed it and scaled by the size of the hit — not by the health it managed to remove, so a killing blow shoves just as hard against a fish on its last point as against a fresh one. The impulse is **not** mass-scaled, so weight is what resists: a 10-damage hit moves a 0.25 kg sardine at the 2.5 u/s cap and a 4.4 kg shark at 0.23. Damage with no source given (a spell with no caster) leaves the fish where it stands.
- **A spell can take the fish over for a moment.** `_start_volley()` / `_tick_volley()` / `_end_hang()` freeze the body mid-air, run a spell's shots out on a timer and hand it back to gravity; `_tick_flop()` and `_tick_peak()` are both off while `_hang_left` is running, and dying mid-volley drops the rest of it and lets the fish fall.
- **Spells ride on the `FishInstance` and are cast from here** — see **Spells** below. A spell rolls its damage through `SpellInstance.try_cast(fish)` and feeds the result into the same `take_damage()` a touch uses; `fish.tick_spells()` is called every physics frame and `bind_fish()` resets the cooldowns along with the health.
- **Damage with a place rather than a source.** `take_damage(amount, from)` shoves the fish away from `from`; `take_blast(amount, origin, knockback_scale, from)` shoves it away from a point in the world instead, which is what an explosion needs, and scales both the shove and its ceiling. Both land in `_apply_damage()`. Damage carrying `NO_ORIGIN` moves the fish not at all.
- Every battler joins the `battlers` group in `_ready()`. A blast walks that group rather than asking the physics server what is inside a sphere: contact callbacks run mid-step, where a shape query is not welcome.
- Flopping is a low, long hop on a random timer (`FLOP_INTERVAL`). The timer runs in mid-air but only fires on something solid, so a fish flops the instant it lands and never off thin air. `chase_target` / `chase_bias` steer the hop towards an opponent — or away from the nearest one, if the fish carries `CowardSpellData`; leave the target null and it wanders — two fish left to wander take an age to find each other, so an arena should point them at one another. The bias is **distance-scaled** (`_chase_strength()`): full strength inside `CHASE_NEAR`, fading to `CHASE_FAR_SCALE` of it past `CHASE_FAR`, so a fish across the arena blunders about and only commits once its opponent is close. Bounce is the scene's `PhysicsMaterial`, not the script.
- `tint` colours the sprite (team colours, so two fish of one species are told apart). The hit flash fades back to it rather than to white.
- **The collider is the fish, not a ball around it**: a `CapsuleShape3D` lying down its length, as long as the sprite and as thick as the icon is tall (`_sprite_height()` reads the aspect off the texture). It matches to the pixel at every size, and a fish rests with its drawn bottom edge on the floor instead of floating on a ball.
- **Only yaw is locked.** The fish faces the camera — **point the arena camera down −Z** — while pitch and roll are the capsule's own and it tumbles the way it is thrown. The cost, measured over a 200-second soak: the sprite is under half-on for ~17% of frames and near edge-on for ~4%, because a capsule lying down a fish log-rolls about that length readily. That is the price of the hitbox doing the rotating instead of a script; lock `axis_lock_angular_x` again to trade the tumble for a sprite that always reads.
- `_face_the_tumble()` copies the body's pitch and roll onto the sprite each frame and drops the yaw — rotations about two axes compose into a turn about the third, and a fish that *settles* side-on is an invisible fish rather than a briefly thin one. The flop wiggle and the belly-up death pose ride on top as roll; `flip_h` faces it the way it is travelling.
- `MAX_SPEED` / `MAX_SPIN` are clamped every frame in `_integrate_forces()`. Nothing a fish does to itself approaches them (a flop is ~3 units/s, a hard knockback adds 2.5) — they exist for the solver, which can pinch a spinning capsule between floor and wall and hand back energy from nowhere. Unclamped, a sardine was launched over a 4-unit wall and out of the world; both caps are hit in practice.
- Signals: `dealt_damage(target, amount)`, `took_damage(amount, from)`, `died(battler)`. A dead fish keeps its physics and stays in the arena — whoever spawned it decides when to free it.
- Physics layer 3 (`Battler`); collides with `Ground` and other battlers, never with `Water`.
- **`dev/TestArena.tscn`** (`dev/test_arena.gd` + `dev/arena_hud.gd` + `dev/free_camera.gd`) is where to watch a fight: two random species dropped in a walled box, HP bars and a hit log. **R** fresh pair, **1** rematch of the same two healed up, **E** the same rematch with both fish handed a spell they did not roll, stepping to the next one in `FishData.SPELL_POOL` on each press and finishing on the whole pool (one at a time because handing both fish everything includes Coward, and two cowards spend the round running away from each other), **Esc** hands the cursor back and then quits. Run it on its own with F6 — nothing in the game loads it and it never touches `gamephase`. It renders through the same 480x270 `SubViewport` as `main.tscn`, so it pixelates the way the real arena will.
- The arena camera is a freecam (`dev/free_camera.gd`): **right mouse** toggles looking, **WASD** flies where it points, **Space/Ctrl** up and down, **Shift/Alt** faster/finer, **wheel** sets the base speed, **F** returns to the opening view. Its events are read in `test_arena.gd::_camera_input()`, not in the camera — the camera is inside the `SubViewport`, which only sees what its container passes on, while the arena root is in the main viewport and gets everything. Flying itself polls `Input` (through the game's own WASD actions) and needs no events at all.

### Spells

- A spell is two halves, the way items are: `SpellData` (`.tres` in `data/spells/`) is what the spell *is*, `SpellInstance` is one fish's copy of it and owns the only thing that moves during a fight, `cooldown_left`. `SpellData.compute_damage(caster_power)` takes a plain int — it never sees the `FishInstance` — and `SpellInstance.caster_power()` is what decides whether that int is the fish's `phys_dmg` (PHYSICAL) or its `magic_dmg` (everything else).
- `SpellData.trigger` says what sets a spell off, and `FishInstance.ready_spell(trigger)` is the one lookup for all of them — the first spell waiting on that trigger and off cooldown, or null.
  - `MANUAL` waits to be cast by something else. Nothing uses it yet.
  - `ON_HIT` is armed the moment it comes off cooldown and is spent on the caster's **next contact of any kind** — another fish, a wall, the floor at the end of a flop. `BattleFish._cast_on_hit()` spends it, hung off `body_entered` rather than off `_hit()` so that a touch which is not allowed to do damage (a team mate, a fish already dead) still counts. The cooldown is the only gate, which is what keeps a fish from going up every time it lands: over a 60-second armed soak in `TestArena` two fish on a 6-second cooldown cast 30 times between them, so in practice it fires the moment it comes back up.
  - `PASSIVE` is never cast at all. `BattleFish._read_passives()` picks it off the fish once in `bind_fish()` and caches it; from then on it is the fish's behaviour rather than an event. Nothing about cooldown or damage applies.
  - `AT_JUMP_PEAK` waits for the top of a hop — rising the frame before, no longer rising now, nothing underfoot — which `BattleFish._tick_peak()` spots by comparing `linear_velocity` against `_approach_velocity`. Unlike an ON_HIT spell it is **aimed**, so `_cast_at_peak()` keeps the charge rather than spending it when `_nearest_enemy()` comes back null.
- **`PEAK_RISE` has to stay just over zero** (0.02). It is how fast the fish must have been rising the frame *before* the apex, and one physics frame of gravity is only 0.16 units/s at 60 Hz — so a fish about to turn over the top is by definition crawling. The first draft used 0.35 and the spell simply never fired. What keeps the floor out of it is the `_grounded` check, not this number.
- **Detonate** (`data/spells/explosion.tres`, `ExplosionSpellData`) is the one spell that exists. The next thing its carrier runs into goes up with it: every fish the caster may hit within `radius` of the impact takes `magic_dmg * damage_scale` (1.5) and is thrown outwards from the blast, hardest at the middle and `EDGE_KNOCKBACK` of that at the rim. `base_power` is unused — the whole point of it is the caster's own magic stat. Damage does **not** fall off with distance; only the shove does. A blast does not set off another fish's spell, so explosions cannot chain.
- **The caster is thrown by its own blast but never hurt by it.** `can_hit()` rules itself and its team out of the damage; `_recoil()` then shoves it separately, `self_knockback` (0.7) of what the blast is worth at its centre, back the way it was travelling when it hit. That direction comes from `_approach_velocity`, the velocity kept from *before* the physics step — by the time `body_entered` fires the solver has already bounced the fish off whatever it ran into, so the live velocity points the wrong way.
- `knockback_scale` multiplies BattleFish's ceiling on a single shove as well as the shove itself, so it is really "how much faster than a touch can this throw a fish": at 3.0 a point-blank blast is worth 7.5 units/s, which is past `MAX_SPEED` and so means "as fast as a fish is allowed to go". Raising it further does nothing the clamp does not take straight back. Measured over a 60-second armed soak in `TestArena`: 30 casts, fish reach 3.67 on a floor that walls off at 4.0 and 2.84 above it against 6-unit walls, and never once leave the box.
- `SpellExplosion` (`classes/spells/spell_explosion.gd`) is the animation only — billboarded, nearest-filtered, sized off the spell's `radius`, built in code because a scene of one node whose every property comes off the spell would have nothing in it to edit. It is parented **alongside** the fish, not under it, so it stays where it went off and outlives a caster that gets freed.
- **Bubble Blast** (`data/spells/bubble_blast.tres`, `BubbleSpellData`) is the AT_JUMP_PEAK one. The fish stops dead at the top of its hop (`freeze = true` for `hang_time`, 0.6 s) and spits `count` (3) bubbles at the nearest fish it may hit, one every `interval` (0.15 s). Each is worth `base_power + magic_dmg * damage_scale` — 5 + half its magic — and travels at `base_speed + speed_per_power * magic_dmg`, so 1 u/s for a dull fish and 3 u/s for a MAG 10 one. **They do not home**: each is aimed at where the target stood when it left, and a fish flops at around 3 u/s, so a moving target really does dodge them. Measured against a target nailed in place: 3 hits, 10 damage each, 0.15 s apart, at exactly 3.00 u/s.
- `SpellBubble` moves itself in `_physics_process` and pops on the first fish it may hit or once it has flown `max_range`. It carries the damage rolled at the muzzle and a **copy of the caster's team**, so it keeps flying and keeps hitting after the fish that fired it has been freed — which is why its team check is its own `_may_hit()` and not `BattleFish.can_hit()`, the latter asking whether the *attacker* is still alive. With no bubble art in the project it draws its own 16-pixel ring (`_shared_texture()`, built once and shared); put a texture on the resource and that takes over.
- **Coward** (`data/spells/coward.tres`, `CowardSpellData`) is the passive. A fish carrying it hops *away* from the nearest fish it could fight instead of towards it — `_flop_direction()` flips the heading and swaps `chase_bias` for `flee_bias` (0.9), keeping the same `_chase_strength()` falloff, so it barely reacts to something across the arena and bolts from something next to it. It runs from whoever is actually closest rather than from whatever `chase_target` was set to.
- **A coward still hits back, and still loses rounds.** Contact damage is traded by both bodies and neither gets a say in it, so the spell buys distance and not immunity: on open ground a coward never makes contact at all (measured: 1.6 → 31 units out over 25 seconds, its target untouched, against a control fish that stayed within 2.6 and dealt 35), but the arena is 8 by 5 and the walls do the cornering. Four rounds of one coward against one ordinary fish ended at 5.5, 12.6, 17.1 and 31.9 seconds — longer fights, fewer exchanges, no stalling. **Two** cowards in one arena, though, will never find each other.
- **New spells**: a `SpellData` resource in `data/spells/`, added to `FishData.SPELL_POOL` — the stand-in registry every fish rolls from, until there are enough spells to be worth a `Spellsdb` autoload keyed by id the way `Itemdb` does it for items. A spell that needs behaviour rather than a number subclasses `SpellData` and gets a branch in whichever of `BattleFish._cast_on_hit()` / `_cast_at_peak()` matches its trigger, or in `_read_passives()` if it is never cast; a new *trigger* means a new enum entry and a new place in BattleFish that spots the moment. Nothing else in the game needs to know any of it exists.
- `FishData.roll_spells()` draws 0..`max_spells` of them without replacement, so a fish never carries the same spell twice and a pool smaller than `max_spells` caps the count on its own. `UIFishSelect` and `UIBattle` show the count as SPL.

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
- Layer 3: `Battler` — fish in the arena (`BattleFish`)

## Key Conventions

- Data (static properties) lives in `*Data` / `Item` **Resources** (`.tres` files), stored in `data/`.
- The game is sprite-only: items are drawn from their `Item.icon`, there are no 3D meshes for fish or held items.
- All text is monogram at `UIFont.SIZE` (or a whole multiple of it) — see **Text**.
- Runtime state lives in `*Instance` **Resources** that wrap a `data` reference.
- All random rolls go through `randomizer.RNG` (the shared, pre-seeded `RandomNumberGenerator`).
- Water biome is determined by `Area3D` groups on the water body; the `Bobber` reads those groups on entry.
- New fish species: create a `FishData` resource (`.tres`), add a `LootEntry` referencing it to the appropriate `LootTable`, and register it in `Itemdb` if it needs to be retrievable by ID.

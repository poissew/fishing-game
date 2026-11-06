# art

Editable sources for the models in `models/`. Kept out of Godot's filesystem by
the `.gdignore` beside this file: a `.blend` left under `res://` is imported by
Godot through Blender itself, which both duplicates the exported `.glb` and
makes opening the project depend on a Blender install.

| Source | Exports to |
|--------|-----------|
| `slot_machine.blend` | `models/slot_machine.glb` + `models/slot_reel_symbols.png` |

`slot_machine.blend` is built by script rather than by hand — the cabinet is
flat-shaded boxes with the lighting baked into vertex colours, and the reel
symbols are drawn pixel by pixel into the texture. Re-exporting by hand:
select the five meshes, glTF 2.0, **+Y up**, Material vertex colours on,
animation mode *Actions* with NLA strips, cameras and lights off.

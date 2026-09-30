# Asset register

Milestone 1 uses **no external assets**. All geometry is Roblox primitives with built-in materials,
fonts are Roblox built-ins, and the lighting uses engine effects only. This file tracks the assets later
milestones need, so nothing is faked with made-up IDs.

## Milestone 2 — weapons & soldiers
| Asset | Status |
|---|---|
| 5 weapon meshes, 12 faction gear meshes (FBX + GLB, baked 1024² Color/Roughness/Metalness atlases) | **Modelled and baked** with Blender 4.2 in `assets/export/`, verified by re-import. They must be **imported manually** in Studio (docs/ASSET_PIPELINE.md). The game uses the primitive fallback until then. |
| Preview renders | `assets/previews/` (Cycles) |
| Animations | **None needed.** All animation is procedural in code, with no animation IDs. |
| Textures | None; flat PBR colours are applied from the spec palettes. |

## Needed for Milestone 3 — audio
All sounds must be original or properly licensed (Roblox Creator Store sounds uploaded or
distributed by Roblox are fine; check each item's licence). Fill the IDs in
`src/shared/Config/SoundConfig.lua`. Empty IDs are skipped at runtime.

| Group | Sounds |
|---|---|
| Weapons (per class: rifle, carbine, support, scout, sidearm) | fire (near), fire (distant), reload sequence, equip, dry-fire |
| Foley | footsteps × {grass, dirt, concrete, wood, metal} (3–4 variations each), jump, land, gear rustle |
| Ambience | forest wind, tree rustle, birds, river, industrial hum, distant combat |
| Vehicles | engine idle/rev loop, door, collision |
| UI / feedback | hitmarker, capture progress, capture complete, victory, defeat |

## Milestone 1 — none required
If you'd like photographic textures (e.g. custom MaterialVariants for brick or roof tiles), they can
be added later as `MaterialService` variants without code changes.

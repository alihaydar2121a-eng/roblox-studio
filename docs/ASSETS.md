# Asset register

Milestone 1 uses **no external assets**. All geometry is Roblox primitives with built-in materials,
fonts are Roblox built-ins, and the lighting uses engine effects only. This file tracks the assets later
milestones need, so nothing is faked with made-up IDs.

## Needed for Milestone 2 — weapons & soldiers
| Asset | Type | Notes |
|---|---|---|
| R6 animations: idle, walk, run, sprint, crouch (idle and move), jump, fall/land | Animation (uploaded by the experience owner) | Author in Studio's Animation Editor on an R6 rig; upload under the owner/group that publishes the game. Record the IDs in a config module. |
| Weapon animations: equip, idle-hold, fire, reload, aim-down-sights (per weapon class) | Animation | Same process. Until uploaded, the code must fall back to procedural poses (Motor6D offsets) rather than reference missing IDs. |
| Optional weapon meshes | MeshPart (FBX/OBJ import) | Only if an artist provides original models; otherwise weapons are built from parts. |

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

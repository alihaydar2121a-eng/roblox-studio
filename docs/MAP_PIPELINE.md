# Kestrel Valley — map pipeline

The battlefield is **source code**: a deterministic generator in `src/server/World/` turns
`src/shared/Config/MapLayout.lua` into Roblox terrain and ~21 000 anchored parts. Everything
survives Rojo builds, because the generator is what Rojo syncs. You then pick where the output
lives:

| Mode | How | When |
|---|---|---|
| **Baked** (recommended) | Studio plugin *Ironfront → Bake Map* (or the command bar), then **File → Save** | Normal development and publishing. The terrain and `Workspace.Map` are saved in the place, so servers start instantly and you can inspect or hand-tune the map in Edit mode. |
| **Runtime** (fallback) | Nothing: the server generates on start if no matching baked map is found | Fresh `rojo build` places, CI builds, or a baked map from an older generator version. Players see “Preparing battlefield…” on the deploy panel while it builds. |

`MapBuilder.VERSION` is stamped on `Workspace.Map` as `GeneratorVersion`. If you change the generator,
bump the version. Servers will then ignore stale bakes (with a warning) until you re-bake.

## Bake in Studio

1. `rojo serve`, and connect the Rojo plugin (so `ServerScriptService.Server.World` exists).
2. Install the tools plugin once: `rojo build plugin.project.json --plugin IronfrontTools.rbxmx`
   (writes into your local Studio *Plugins* folder), then restart Studio. The **Ironfront** toolbar
   appears.
3. In **Edit mode**, click **Bake Map**. Output shows the wedge calibration, terrain and per-site part
   counts. Expect a few seconds to tens of seconds, depending on your machine.
4. **File → Save** (or Publish). The terrain voxels and `Workspace.Map` are now part of the place.

Command-bar alternative (Edit mode):
```lua
require(game.ServerScriptService.Server.World.MapBuilder).bake()
```
*Clear Map* (or `...MapBuilder).clear()`) removes both terrain and `Workspace.Map`.

> Studio caches required modules per plugin/command-bar session. After editing generator code,
> re-enable the plugin (Plugins → Manage Plugins) or restart Studio before re-baking.

Delete the template `Baseplate`/`SpawnLocation` before baking; the generator does not need them.

## What gets generated

* **Terrain:** a 1 792 × 1 792 stud area, written with chunked `WriteVoxels` (196 calls, ~4 M
  voxels):
  * rolling noise and 13 named hills
  * a rounded mountain ring with ridged peaks, plus passes behind each HQ
  * rock spires, including the Kestrel Rock landmark
  * the Kestrel River with a floodplain valley, and the Harlow Brook ravine
  * zig-zag trench lines carved into two hills
  * flat pads under every site and outpost
  * roads blended onto smoothed profiles, painted as Asphalt, Ground or Cobblestone
  * surface materials chosen by slope and altitude, forest-floor LeafyGrass, mud patches and sandy
    riverbanks
  * a custom terrain palette, water look and grass decoration
* **Sites:** Fort Harlow (A), Millbrook (B), Kessler Works (C), both team HQs (24 spawn pads each)
  and 15 outposts: woodland checkpoints, ruined farmstead and chapel, old mill with water wheel,
  radio mast, lookout tower, cabins, bunkers and footbridges. Road bridges are placed automatically
  where roads cross rivers. There are also trench revetments and a power line along the highway.
* **Foliage:** about 1 150 trees in five species (Spruce, Pine, Oak, Birch, Snag), plus bushes, rock
  clusters, fallen logs and road puddles. Placement uses a deterministic jittered grid driven by
  domain-warped forest masks.
* **Boundary:** invisible walls at ±768 studs and a kill height at Y −40, enforced by `SpawnService`.

## Code map

| File | Role |
|---|---|
| `shared/Config/MapLayout.lua` | Macro geography: HQs, zones, roads, rivers, hills, spires, forests, outposts, trenches |
| `shared/Util/Rng.lua` | Platform-independent xorshift RNG (identical in Roblox, luau CLI and Lune) |
| `server/World/Plans.lua` | Pure site planner: building placements, pads, paints, lanes, bridge crossings |
| `server/World/Heightfield.lua` | Pure terrain function: height and material at any (x, z) |
| `server/World/TerrainGenerator.lua` | Voxel writer and terrain palette |
| `server/World/Kit.lua` | Geometry kit: calibrated wedges, framed walls, stairs with ramps, roofs, level slabs, railings, signs, lamps |
| `server/World/Props.lua` | Set dressing: military, village and industrial props and furniture |
| `server/World/Buildings.lua` | Building archetypes with interiors |
| `server/World/Structures.lua` | Structure dispatcher, perimeters, industrial equipment, bridges |
| `server/World/Foliage.lua` | Tree species and scatter |
| `server/World/Sites/*.lua` | Site assemblers (HQ, MilitaryBase, Village, Industrial, Outposts, Objectives) |
| `server/World/MapBuilder.lua` | Orchestration, bake/ensure/clear, metadata |
| `server/World/Env.lua` | The only engine seam (workspace, terrain, raycasts, yielding); mocked offline |

### Wedge calibration
Roblox never documents WedgePart and CornerWedgePart slope directions as an API contract. So on each
run, `Kit.calibrate` raycasts a test wedge and a test corner wedge, and orients every ramp, gable and
pyramid from the *measured* result. The Output line `wedge calibration: rise=… apex=… measured=true`
confirms it worked. `measured=false` means the defaults were used; see the validation checklist.

### Stairs
Every flight is solid 1-stud steps plus an invisible ramp through the step nosings, so R6 characters
climb smoothly even if step-up behaviour varies. Two-storey interiors use a rear-wall flight with a
railed stairwell. Roof access (Command Post, Kessler warehouse) adds a second switch-back flight
through a roof hatch.

## Editing the map

* Move or retune features in `MapLayout.lua`: road points, hill heights, forest masks, outposts.
  The planner, pads, bridges and tree clearings follow automatically.
* Building mixes and site layouts live in `Plans.lua` (plan functions per site).
* After changes, run `./scripts/check.sh`. It covers the unit tests (flat footprints, no overlaps,
  wet rivers, road grades, boundaries), the full generation harness, and Rojo builds. Then re-bake.

## Offline previews (no Studio needed)

```
lune run tests/harness.luau                          # generate offline → build/parts.tsv, build/Map.rbxm
luau scripts/dump_heightfield.luau > hf.txt
python3 scripts/render_heightmap.py hf.txt map.png build/footprints.tsv   # top-down
python3 scripts/render_parts.py village.png 40 20 20 75 35 32             # oblique parts render
```
`build/Map.rbxm` holds the generated parts without terrain. You can drag it into Studio for a quick
look, but the bake workflow is the supported path. The images in `docs/previews/` come from these
scripts. They are **software renders of the generated geometry, not Roblox screenshots.**

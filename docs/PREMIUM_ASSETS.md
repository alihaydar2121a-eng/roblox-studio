# Premium assets: IR-7 Carbine and Ashford Coalition kit

These are the first two hand-modelled assets of the art pass. Everything is real Blender geometry:
filleted profile extrusions, lofts, lathes, swept sections, EXACT boolean cuts, bevels and weighted
normals. Each asset has a baked PBR texture atlas. Nothing here is built from Roblox parts.

| Asset | Replaces in game | Files | Triangles |
|---|---|---|---|
| **IR-7 Carbine** | carbine slot `CB` (was the primitive "KC-9 Talon") | `assets/premium/weapons/IR7/` | ≈34 k (10 MeshParts) |
| **Ashford Coalition soldier** | team `Alpha` gear (was the primitive kit) | `assets/premium/characters/Ashford/` | ≈24.5 k base, ≈28 k with every variant |

Each folder contains:

* `*.blend`: the source scene. It holds the modelled objects, the procedural source materials
  (kept with fake users for re-baking), the baked atlas material and a camera for every review view.
* `*.fbx` and `*.glb`: Roblox-ready exports with Y up, −Z forward and 1 unit = 1 stud. Textures are
  embedded.
* `textures/`: the 1024² atlas maps `*_Color.png` (albedo with baked AO), `*_Normal.png`
  (tangent space), `*_Roughness.png` and, for metal assets, `*_Metalness.png`.
* `renders/`: front, side, rear and both three-quarter views, close-ups, a clay + wireframe
  topology pass and, for the rifle, a sight-line check. The renders use the **baked atlas**, which
  is exactly what the exports carry. They are not the procedural source shaders.
* `*.json`: the manifest (objects, triangle counts, sizes, attachment points, atlas usage). The Lune
  harness checks it against the runtime config.

![IR-7](../assets/premium/weapons/IR7/renders/IR7_threequarter.jpg)
![Ashford](../assets/premium/characters/Ashford/renders/Ashford_threequarter.jpg)

## Art direction (applies to the remaining assets)

* **Scale:** R6 studs. The IR-7 is 2.98 studs long with the grip at the origin. Gear hugs the R6
  limb blocks (Torso 2×2×1, arms and legs 1×2×1, head ≈1.25) with shells 0.02–0.04 studs proud of
  the body faces. That is enough to avoid z-fighting without bulking up the silhouette. There are
  no oversized shoulder pieces.
* **Palette:** olive `#5C6342`, ranger green `#4E543A`, coyote/tan `#98805D`, black anodised
  `#26272A`, tungsten grey `#44464A` and gunmetal `#46484C`. Materials are separated by finish
  (anodised, cerakote, polymer, rubber, cordura, ripstop, suede, leather).
* **Surface language:** crisp chamfers on machined parts, rounded bevels on polymer, pillowy
  rounded soft goods, and a baked micro-surface for detail too fine for geometry: stipple, ripstop,
  webbing weave, leather grain. The edge wear follows the real bevels.
* **Signature details:** the IR row of slanted handguard vents, stacked-chevron "Ironfront Arms"
  mark, and the Ashford shield with an ash leaf.

## Roblox Studio setup (once per place)

Start with the game code synced (`rojo serve` → Rojo plugin → Connect), then rebuild and reinstall
the Studio plugin so it has the new **Install Assets** button:

```
rojo build plugin.project.json --plugin IronfrontTools.rbxmx
```

Restart Studio after installing the plugin.

### 1. Import the IR-7

1. Go to *Home → Import 3D* (or *File → Import 3D*) and choose
   `assets/premium/weapons/IR7/IR7.fbx`. `IR7.glb` works too.
2. In the importer panel (option names differ slightly between Studio versions):
   * **Rig type:** *No rig*.
   * **Merge meshes:** **off**. The separate parts are needed: the magazine drops out during
     reloads and the optic hides while you aim.
   * **Scale unit / file dimensions:** *Studs*. The preview should report about **2.98 studs**
     long. If it doesn't, the installer rescales and warns.
   * **World forward / up:** leave the defaults (front = −Z, up = +Y).
   * Leave texture/material import **on**. The importer turns the embedded PBR maps into a
     `SurfaceAppearance`.
3. Click *Import*. A Model named **IR7** appears in Workspace.
4. Click **Ironfront → Install Assets**. The Output shows
   `IR7 -> ReplicatedStorage.ImportedAssets.Weapons.CB` and lists any warnings. The installer:
   * moves and renames the model to `ReplicatedStorage.ImportedAssets.Weapons.CB`, the slot the
     game reads;
   * checks the size (it rescales on a unit mismatch) and the axes (it warns on a wrong
     forward/up);
   * checks every expected part (`IR7_receiver`, `IR7_olive_mag`, `IR7_receiver_optic`, …);
   * makes every part cosmetic: no collision, query or touch, massless, `CollisionFidelity = Box`,
     `RenderFidelity = Automatic`;
   * copies the `SurfaceAppearance` to every part that didn't get one (all parts share one atlas)
     and sets the lens to transparent Glass;
   * records one undo step, so Ctrl+Z restores the previous state.

### 2. Import the Ashford kit

Import these six files the same way: *No rig*, *Merge meshes off*, *Studs*.

| File | Installed as |
|---|---|
| `assets/premium/characters/Ashford/Ashford_Head.fbx` | `ImportedAssets.Gear.Alpha.Head` |
| `…/Ashford_Torso.fbx` | `ImportedAssets.Gear.Alpha.Torso` |
| `…/Ashford_Arm.fbx` | `ImportedAssets.Gear.Alpha.Arm` (right arm) |
| `…/Ashford_Arm_L.fbx` | `ImportedAssets.Gear.Alpha.Arm_L` |
| `…/Ashford_Leg.fbx` | `ImportedAssets.Gear.Alpha.Leg` (right leg) |
| `…/Ashford_Leg_L.fbx` | `ImportedAssets.Gear.Alpha.Leg_L` |

You can import all six before installing them. Select the six models, or leave them in Workspace,
and click **Install Assets** once.

### 3. If a part shows up untextured

Some Studio versions import FBX textures only as a colour map, or not at all. When the installer
warns `no SurfaceAppearance found`:

1. Open *Asset Manager → Bulk Import* and upload the four PNGs from the asset's `textures/` folder.
2. Add a `SurfaceAppearance` to one part (for example `…Weapons.CB.IR7_receiver`). Set
   `ColorMap`, `NormalMap`, `RoughnessMap` and `MetalnessMap` to the uploaded IDs. Atlases without a `*_Metalness.png` (the arms)
   leave `MetalnessMap` empty.
3. Click **Install Assets** again, with that model selected. It copies the `SurfaceAppearance` to
   every other part.

Until this is done, untextured parts are recoloured from the palette in `WeaponModels.CB` and
`GearModels.Alpha`, so the look stays consistent, just without the texture detail.

### 4. Save and check

Save the place. The Rojo project only maps `ReplicatedStorage.Shared`, so the imported assets live
in the place file. Then play-test with 2+ clients:

* the carbine's weapon model has `AssetSource = imported`;
* an Ashford character's `Gear` folder has `Source = imported`;
* in first person, the forearms, cuffs and gloves are the premium meshes.

## How it plugs into the game (no gameplay changes)

* **Weapons:** `WeaponRig` builds an invisible `Handle` at the grip and welds every imported part
  to it using the `Origin` marker. The attachment points come from `WeaponModels.CB.Points` and are
  measured on the Blender model: grip, `Support` (left hand), `Muzzle`, `Sight` (ADS eye point) and
  `Stock`. `renders/IR7_sightline.jpg` is rendered from the `Sight` point, so the red dot lines up
  in ADS. The same rig serves third person (server) and the first-person viewmodel (client).
* **Gear:** `UniformService` welds each piece to its R6 limb (`Head`, `Torso`, `Right Arm`,
  `Left Arm`, `Right Leg`, `Left Leg`), pivot = limb centre. Every part is massless and not
  collidable, queryable or touchable. Hit detection keeps using the standard R6 body parts, and
  the procedural animator (Motor6D transforms) is unaffected.
* **Variants:** the optional pieces follow `GearModels.variantsFor(userId)`, so each player gets a
  stable mix:
  * `_v_cover`: camo helmet cover;
  * `_v_goggles`: goggles on the helmet;
  * `_v_headset`: comms headset with a boom mic;
  * `_v_bedroll`: rolled mat on the pack;
  * `_v_antenna`: radio whip antenna.
* **Textured vs. flat:** `ModelBuilder.attachImported` keeps the imported look on parts that have
  a `SurfaceAppearance` or `TextureID`, and recolours only untextured parts.
* **Fallback:** if nothing is imported, or an import is malformed, the game falls back to the
  primitive builds. `WeaponModels.CB` was rebuilt to match the IR-7 silhouette, colours and points.

## Performance budget

| | Triangles | MeshParts | Textures |
|---|---|---|---|
| IR-7 | ≈34 k | 10 (+ Origin) | 4 × 1024² |
| Ashford (base / all variants) | ≈24.5 k / ≈28 k | 6 models, 5–13 parts each | 4 atlases × 3–4 maps, 1024² |

The largest single mesh is well under Roblox's per-mesh limit. `RenderFidelity = Automatic` lets
Roblox LOD distant players. Parts don't collide, cast only when visible, and the viewmodel copies
have shadows off.

## Rebuilding

```
pip install bpy==4.2.0                        # or use Blender 4.2+
python3 scripts/blender/premium/build_premium.py ir7 ashford   # --quick, --no-render
# or: blender --background --python scripts/blender/premium/build_premium.py -- ir7 ashford
```

| Script | What it does |
|---|---|
| `scripts/blender/premium/iflib/geo.py` | modelling toolkit (profiles, lofts, lathes, sweeps, soft goods, booleans, bevels) |
| `iflib/mats.py` | procedural PBR looks with named output channels for baking |
| `iflib/bake.py` | shared UV atlas; zero-margin bake with island-aware dilation (no cross-object bleeding); FBX/GLB export |
| `iflib/render.py` | review studio, auto-framed cameras, clay + wireframe pass |
| `assets/ir7.py`, `assets/ashford.py` | the two assets |

Then run `lune run tests/assets.luau`. It fails if the manifests, `WeaponModels` points or the
`PremiumAssets` install table drift apart.

## Honesty note

The meshes, textures and renders were produced and checked here:
* the exports were re-imported into Blender;
* the UV overlap was measured;
* the attachment points were compared by the harness.

The Studio steps above have **not** been run by the author. Two behaviours need confirming when
you import: the importer's handling of embedded PBR textures, which depends on the Studio version,
and the first-person premium arms. Both have fallbacks: the palette recolour and the primitive
arms.

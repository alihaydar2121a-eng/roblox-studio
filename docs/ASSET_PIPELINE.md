# Soldiers, weapons & animation — asset pipeline

> **Premium assets:** the IR-7 Carbine (slot `CB`) and the Ashford Coalition kit (team `Alpha`)
> are now hand-modelled in Blender with baked PBR textures. They have their own build and import
> steps in [PREMIUM_ASSETS.md](PREMIUM_ASSETS.md). The primitive pipeline below still covers the
> other weapons and the Varn kit, and it skips anything marked `Premium` in the specs.

```
scripts/blender/ironfront/        modelling library (Blender 4.2 bpy)
  geo.py      lofts, lathes, extrusions, shells, straps, booleans, bevels, weighted normals
  mats.py     procedural PBR materials (grain, camo, edge wear, AO) + atlas baking
  weapons.py  KR-20, KC-9, RG-7, LX-3, P-11 builders (grip = origin)
  soldiers.py Ashford Coalition + Varn Directorate bodies and kit, per R6 limb
        │
scripts/blender/build_assets.py   → bakes one 1024² atlas per asset (Color/Roughness/Metalness)
        │                            → assets/export/{weapons,gear}/<asset>.fbx|.glb (+ PNGs)
        │                            → assets/export/manifest.json
scripts/blender/verify_exports.py → re-imports every file: size, axes, names, embedded texture
scripts/blender/render_previews.py→ assets/previews/*.png rendered from the exported GLBs
scripts/blender/qc_weapon.py / qc_soldier.py → multi-angle QC renders of the source scenes
        ▼
Roblox Studio 3D Importer → Models of textured MeshParts
        ▼
ReplicatedStorage.ImportedAssets.{Weapons,Gear}   (saved in the place file)
        ▼
ModelBuilder / WeaponRig / UniformService / ViewModel use them at runtime.
Missing or broken imports fall back to the primitive specs
(src/shared/Config/WeaponModels.lua, GearModels.lua) automatically.
```

**What is in the repository**
* **Meshes:** modelled in code with Blender 4.2 and committed under `assets/export/`. There are no
  box-and-cylinder primitives.
  * Weapons use lathed barrels, brakes and scopes. They have lofted magazines with curvature,
    extruded receiver profiles with bevels, a finger-grooved grip, rail slots cut by boolean, and
    vents.
  * Soldiers have lofted and tapered bodies, gloved fists and boots with tread.
  * Soldier kit is shaped: plates, pouches with magazines, straps, helmets, radios and packs.
  * Triangle budgets:
    * Weapons: about 1.7k (P-11) to 6.5k (AR).
    * Soldiers: about 15–16k for a full faction kit across 6 pieces.
* **Textures:** each asset bakes one atlas: `<asset>_Color.png`, `_Roughness.png` and
  `_Metalness.png`.
  * The atlas includes camo, grain, edge wear and ambient occlusion.
  * The FBX embeds the atlas and the GLB packs it.
* **Previews:** `assets/previews/` is rendered from the exported files.
* **Not uploaded to Roblox.** Rojo cannot create MeshParts, and uploading needs your account.
  Until you import the assets, the game uses the primitive fallback.

## Rebuilding

```
python3 scripts/blender/build_assets.py [--only AR,Alpha_Torso] [--size 1024]   # ~3 min/asset on CPU
python3 scripts/blender/verify_exports.py
python3 scripts/blender/render_previews.py
python3 scripts/blender/qc_weapon.py AR /tmp/qc ; python3 scripts/blender/qc_soldier.py /tmp/qc
```
With the Blender app instead of pip `bpy`, run
`blender --background --python <script> -- <args>`. The old primitive exporter is kept as
`scripts/blender/legacy_build_assets.py` for reference.

Conventions:
* **Units:** 1 unit = 1 stud.
* **Axes:** Y-up with −Z forward, which matches Roblox.
* **Pivots:** the weapon pivot is the right-hand grip. The gear pivot is the R6 limb centre.
* **Objects:** each asset exports a few joined, textured meshes that share the atlas:
  * `<asset>_body`;
  * `<asset>_mag` (weapons: hidden during reload);
  * `<asset>_optic` (hidden at full aim);
  * `<asset>_v_<variant>` for per-player optional kit: goggles, headset, bedroll, visor, mask and
    antenna;
  * a tiny `Origin` part that marks the pivot.
* **Soldier body pieces:** `Torso`, `Arm*` and `Leg*` are complete limbs (uniform, gloves and
  boots). When they are imported, the runtime makes that R6 limb invisible and keeps it as the
  hitbox. `Head` is helmet and kit only, so the player's own head and face show.

## Importing into Roblox Studio (manual, once per asset)

1. *Home → Import 3D* and choose `assets/export/weapons/AR.fbx`.
2. Importer settings:
   * **Scale unit: Studs.** The AR should report about 3.8 × 0.8 × 0.2.
   * **Merge Meshes OFF.**
   * **Anchored OFF.**
   * **Rig: None.**
   * **Import textures ON.** The 3D Importer uploads the embedded Color map as the MeshPart
     `TextureID`.
3. For PBR, optionally add a `SurfaceAppearance` to each MeshPart:
   * `ColorMap`, `RoughnessMap` and `MetalnessMap` come from the PNGs next to the FBX, uploaded via
     the Asset Manager.
   * The runtime never recolours a part that has a `TextureID` or `SurfaceAppearance`.
4. Put the Model in `ReplicatedStorage.ImportedAssets.Weapons` and name it `AR`. Repeat for CB, LMG,
   SR and P11.
5. Import the gear files into `ReplicatedStorage.ImportedAssets.Gear.Alpha` and `...Gear.Bravo`.
   Name them `Head`, `Torso`, `Arm`, `Arm_L`, `Leg` and `Leg_L` (drop the team prefix).
6. Select all imported MeshParts and set:
   * *CanCollide/CanQuery/CanTouch off*;
   * *CollisionFidelity = Box*;
   * *RenderFidelity = Automatic*.
7. **Save the place.** Rojo only maps `ReplicatedStorage.Shared`, so it leaves `ImportedAssets`
   alone.

To check the result in a play test:
* The weapon model's `AssetSource` attribute reads `imported`.
* The character's `Gear` folder `Source` attribute reads `imported`, and the blocky R6 limbs
  disappear behind the new bodies.
* In first person, the viewmodel uses the imported `Arm` and `Arm_L` meshes.
* A malformed import logs `[ModelBuilder] imported asset failed, using primitives` and play
  continues.

## Animation system

Animations are **procedural and run entirely in code**. No animation IDs are used or needed, and
none are invented. `Shared.Animation.PoseLibrary` holds the pure pose maths.
`Client.Controllers.CharacterAnimator` drives `Motor6D.Transform` on every R6 character locally,
from replicated state:

| Clip | Driven by |
|---|---|
| Idle breathing, walk, run, sprint (lean, bigger stride) | root velocity and `Stance` |
| Crouch idle and crouch walk (kneeling pose, lowered torso) | `Stance = "Crouch"` |
| Jump, fall (leg flail), landing (compression) | vertical velocity |
| Weapon equip and switch (raise from low ready) | `EquipStart`, set when the server attaches the weapon |
| Weapon idle (hip), aiming (stock up, sights level), sprint carry | `Aiming`, `Stance` |
| Firing (recoil impulse) | local shots and `ShotFx` for other players |
| Reload (tilt, magazine out and in, left hand to belt and back) | player `Reloading` and `ReloadStart` |
| Head, torso and weapon pitch follow aim | `AimPitch` |

Blending uses per-joint exponential smoothing, and the aim and sprint weights are time-based. So
walk to sprint, hip to aim, and stand to crouch all transition continuously. Hands are solved onto
the weapon's grip and support points. R6 arms are rigid 2-stud limbs, so the harness measures the
fit:
* The right hand reaches the grip to within **0.01 studs**.
* The torso is bladed (yawed about 24° for rifles), which brings the support shoulder forward. The
  left hand now lands within **about 0.73 studs** of the foregrip, down from 1.05.

The empty `src/character/Animate.client.lua` stub stops Roblox inserting its default Animate
script, which would fight over the joints.

**Publishing:** none required. If you later author keyframed clips in the Animation Editor, you'd
need to add a clip-playing backend. It isn't implemented; animations are procedural only.

## First-person viewmodel

`Client.Controllers.ViewModel` is active whenever the camera is in first person: always while
aiming, or when zoomed all the way in. It builds the same `WeaponRig` as the third-person weapon,
plus the imported faction arm meshes (or sleeve and glove fallback parts), and adds:
* sway, walk bob and recoil springs;
* the sprint lower, equip raise and reload tilt with the magazine swap;
* aim-down-sights, which moves the weapon's `Sight` point onto the camera, hides the optic mesh and
  shows a red-dot reticle or full scope overlay (SR, 22° FOV);
* wall push-back, so the weapon never clips through geometry;
* full cleanup on unequip and on death.

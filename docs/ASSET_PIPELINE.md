# Soldiers, weapons & animation — asset pipeline

> **Premium assets:** the IR-7 Carbine (slot `CB`) and the Ashford Coalition kit (team `Alpha`)
> are now hand-modelled in Blender with baked PBR textures. They have their own build and import
> steps in [PREMIUM_ASSETS.md](PREMIUM_ASSETS.md). The primitive pipeline below still covers the
> other weapons and the Varn kit, and it skips anything marked `Premium` in the specs.

```
src/shared/Config/WeaponModels.lua ┐   single source of truth (primitive specs)
src/shared/Config/GearModels.lua   ┘
        │ lune run tests/assets.luau        → assets/specs/asset_specs.json
        ▼
scripts/blender/build_assets.py (Blender 4.2) → assets/export/{weapons,gear}/*.fbx|.glb
        │                                      + assets/export/manifest.json
        │                                      + assets/previews/*.png (Cycles)
        ▼
Roblox Studio 3D Importer  → Models of MeshParts
        ▼
ReplicatedStorage.ImportedAssets.{Weapons,Gear}  (saved in the place file)
        ▼
Shared.Assets.ModelBuilder / WeaponRig pick them up at runtime.
Missing or broken imports fall back to the primitive builds automatically.
```

**What exists in the repository today**
* **Meshes:** real, generated here with Blender 4.2 (`bpy`). All files are committed under
  `assets/export/`.
  * 5 weapons: AR, CB, LMG, SR and P11, as `.fbx` and `.glb`.
  * 12 gear meshes: `Alpha_*` and `Bravo_*` for Head, Torso, Arm, Arm_L, Leg and Leg_L.
  * `scripts/blender/verify_exports.py` re-imports every file and checks sizes, axes and object
    names. It currently reports 34 of 34 ok.
* **Previews:** Cycles renders of these meshes in `assets/previews/`.
* **Not uploaded to Roblox.** Rojo cannot import FBX or create MeshParts, and uploading needs your
  account. Until you import them, the game uses the primitive fallback built from the same specs, so
  the look matches minus the bevels.

## Rebuilding the meshes

```
lune run tests/assets.luau                                            # writes asset_specs.json
blender --background --python scripts/blender/build_assets.py        # or: python3 scripts/blender/build_assets.py (pip bpy 4.2, Python 3.11)
blender --background --python scripts/blender/verify_exports.py
```
Add `-- --no-render` after the script path (or `--no-render` with python3) to skip the preview
renders.

Conventions:
* **Units:** 1 unit = 1 stud. The AR is 3.88 studs long and the P-11 is 0.88.
* **Axes:** the files are Y-up with −Z forward, which matches Roblox directly. The weapon pivot is
  the right-hand grip; the gear pivot is the R6 limb centre.
* **Objects:** one object per colour key, named `<Model>_<key>`. Magazine parts end in `_mag`,
  optics in `_optic`, and optional kit pieces in `_v_<variant>`. A tiny `Origin` object marks the
  pivot. The runtime recolours parts from the spec palette by name, so importer material settings
  don't matter.

## Importing into Roblox Studio (manual, once per asset)

1. Open the place and *Home → Import 3D*. Choose `assets/export/weapons/AR.fbx`.
2. Importer settings:
   * **File dimensions: Studs**, or whatever unit makes the AR report about 3.9 studs long.
   * **Merge Meshes OFF**, because the separate objects are needed.
   * **Anchored OFF**.
   * **Rig type: None**.
   * Leave "Keep Hierarchy" on.
3. The import appears as a Model named `AR` containing MeshParts `AR_body`, `AR_mag_mag`, `Origin`,
   and so on. Create the folders `ReplicatedStorage.ImportedAssets.Weapons` (ordinary Folders) and
   move the model in, keeping the name `AR`.
4. Repeat for CB, LMG, SR and P11.
5. Do the same for the gear files. Put them in `ReplicatedStorage.ImportedAssets.Gear.Alpha` and
   `...Gear.Bravo`, named `Head`, `Torso`, `Arm`, `Arm_L`, `Leg` and `Leg_L` (drop the team prefix
   from the model name).
6. Optional: select all imported MeshParts and set *CollisionFidelity = Box* and
   *RenderFidelity = Automatic*. The parts are cosmetic and never collide.
7. **Save the place.** Rojo leaves `ImportedAssets` alone because the ReplicatedStorage node only
   maps `Shared`.

To check the result, equip a weapon in a play test. The weapon model's attribute `AssetSource`
reads `imported`, and the character's `Gear` folder attribute `Source` reads `imported` or `mixed`.
If an import is malformed (no parts, wrong names), Output shows
`[ModelBuilder] imported asset failed, using primitives` and the game keeps working.

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
* The left hand can land **up to about 1 stud short** of a long rifle's foregrip.

The empty `src/character/Animate.client.lua` stub stops Roblox inserting its default Animate
script, which would fight over the joints.

**Publishing:** none required. If you later author keyframed clips in the Animation Editor, you'd
need to add a clip-playing backend. It isn't implemented; animations are procedural only.

## First-person viewmodel

`Client.Controllers.ViewModel` is active whenever the camera is in first person: always while
aiming, or when zoomed all the way in. It builds the same `WeaponRig` as the third-person weapon,
plus faction-coloured sleeve and glove arms, and adds:
* sway, walk bob and recoil springs;
* the sprint lower, equip raise and reload tilt with the magazine swap;
* aim-down-sights, which moves the weapon's `Sight` point onto the camera, hides the optic mesh and
  shows a red-dot reticle or full scope overlay (SR, 22° FOV);
* wall push-back, so the weapon never clips through geometry;
* full cleanup on unequip and on death.

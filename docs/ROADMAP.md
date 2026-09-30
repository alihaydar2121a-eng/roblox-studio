# Roadmap

## Phase 1 — playable vertical slice ✅
Teams, spawning, one rifle with server-authoritative hit detection, three capture points, tickets and
timer, HUD. (Commit 574921c.)

## Milestone 1 — visual foundation ✅ (this change)
Rebuilt Kestrel Valley:
* noise- and feature-driven terrain with mountains, a river valley, a brook ravine, trenches, spires,
  roads and mud
* three distinct objective sites and two HQs
* 15 outposts and automatic bridges
* buildings with interiors, working stairs and roof access
* five tree species with natural scatter
* cinematic lighting (Future lighting, Atmosphere, Bloom, SunRays, colour grade) persisted through Rojo
* the Studio bake workflow, plus runtime fallback and versioning

Bug fixes:
* The deploy screen showed mostly sky: the StreamingEnabled replication focus was wrong, and the
  camera pitched too high.
* The deploy UI was oversized; it is now a compact side panel.
* Spawns now stream in before the character is placed, snap to the ground and use free pads.
* Objective capture height is now measured relative to the real terrain.
* Players out of bounds are now killed.
* The old flat baseplate map and single-sphere trees have been replaced.

## Milestone 2 — weapons & soldiers ✅ (implemented; Studio validation pending)
* Five original weapons (KR-20 rifle, IR-7 carbine, MG-44 support weapon, SR-3 scout rifle, P-11
  sidearm):
  * one set of shared specs drives both the Blender FBX/GLB meshes and the in-game primitive
    fallback;
  * primary plus sidearm loadout with per-weapon ammo, server-validated switching, and a loadout
    picker.
* Faction soldier kits (helmets, vests, packs, pouches, gloves, boots, camo patches, variants),
  welded to R6 limbs.
* Procedural R6 animation: locomotion, crouch and air states, equip/aim/fire/reload, and
  pitch-following weapon holds.
* First-person viewmodel with aim-down-sights, reticles and a scope overlay, sway, bob, recoil and
  wall push-back.
* Sprint and crouch stances with server-authoritative speeds, and movement-dependent spread.
* See docs/ASSET_PIPELINE.md for the Blender → Studio import steps.


## Premium art pass 🟡 (first assets in review)
Hand-modelled Blender assets with baked PBR atlases, see [PREMIUM_ASSETS.md](PREMIUM_ASSETS.md).
* ✅ **IR-7 Carbine** (replaces the carbine slot) and the ✅ **Ashford Coalition** soldier kit.
  Both have FBX/GLB/.blend exports, 1024² atlases, review renders, a Studio installer and harness
  checks.
* ⏳ These follow the same art direction once the two above are approved:
  * the **AR-12 Infantry Rifle**, **SG-4 Support Weapon**, **SR-9 Scout Rifle** and **PX-6
    Sidearm**;
  * the **Varn Directorate** kit (charcoal/navy uniform, original helmet, blue accents).
## Milestone 3 — SFX & VFX (next)
Pooled audio system (spatial, surface footsteps, ambience zones, mixing through SoundGroups) and
pooled VFX: muzzle flash, tracers, surface-aware impacts, dust and mist, explosions. Quality scaling
throughout.

## Milestone 4 — UI & gameplay
Main menu (Play / Team / Class / Loadout / Settings / Credits), deployment with class and
spawn-point selection, redesigned HUD (minimap, compass, squad info, prompts), four classes with
abilities, assists, and a custom scoreboard.

## Milestone 5 — vehicles & polish
Transport truck, armoured transport, utility vehicle (server-validated seats, damage, respawn),
predefined destructible scenery, graphics presets (Low–Ultra), accessibility settings,
DataStore-backed progression, and performance passes. 80-player support is only claimed after
load testing.

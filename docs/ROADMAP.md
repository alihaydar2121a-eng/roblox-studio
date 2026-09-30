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

## Milestone 2 — weapons & soldiers (next)
* Five original weapons (standard rifle, compact carbine, support weapon, scout rifle, sidearm) built
  as detailed multi-part models, with correct R6 grips.
* Aim-down-sights, movement-dependent spread, equip, fire and reload animation integration (procedural
  first, uploaded animations when available), and recoil as camera and animation.
* Faction soldier kits: helmets, vests, backpacks, pouches, gloves, boots and cosmetic variants.
* Animation controller: sprint, crouch and priority/transition handling.

## Milestone 3 — SFX & VFX
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

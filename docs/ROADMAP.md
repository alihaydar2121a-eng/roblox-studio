# Implementation plan & milestones

## Phase 1 — Vertical slice ✅ (this commit)
Rojo layout; server services (Team, Spawn, Uniform, Combat, Objective, Match); procedural Kestrel
Valley; three capture points with contested logic; tickets/timer/victory/intermission; one fictional
rifle (IR-7) with server-authoritative hitscan; HUD, deployment screen, objective markers,
leaderstats scoreboard; unit tests for pure logic; offline build checks.

## Phase 2 — Classes & deployment
* `ClassConfig` (Assault, Medic, Engineer, Scout) with loadouts: Assault (IR-7 + grenade-style
  concussion charge), Medic (compact SMG + healing kit: server-validated heal of nearby teammates, revive),
  Engineer (carbine + repair tool for vehicles/cover, ammo crate), Scout (marksman rifle + spotting
  that pings enemies on teammates' HUD).
* Class selection in the deployment screen; `RequestClass` remote with validation and per-team caps.
* Spawn selection: base or any objective your team owns and is not contested.
* Custom Tab scoreboard grouped by team.

## Phase 3 — Vehicles & destruction
* Lightweight transport truck + light utility vehicle using `VehicleSeat` + `HingeConstraint`
  wheels / `CylindricalConstraint` suspension; network ownership handed to the driver; server
  validates seat entry, speed caps and respawns wrecked/abandoned vehicles at base depots.
* Destructible predefined cover (`CollectionService` tag `Destructible`, `Health` attribute):
  CombatService damages tagged parts; on zero health the server swaps in pre-split debris
  (few parts, anchored after settle, cleaned up by timer) with a dust puff; no runtime CSG.

## Phase 4 — Polish, persistence, accessibility
* Minimap (ViewportFrame-free: 2D map image rendered from MapLayout data) and compass strip.
* DataStore-backed `ProfileService`-style persistence (own implementation): XP, level, kills,
  deaths, wins, captures, with session locking, retries and autosave.
* Settings menu: sensitivity, FOV, colour-blind palettes (team colour + shape cues), reduced
  camera shake/recoil, hitmarker size, HUD scale, subtitles for audio cues; stored per player.
* Custom R6 animations (authored in Studio's Animation Editor, uploaded by the owner) for aim,
  fire recoil and reload; sprint and crouch.
* Performance: effect part pooling, LOD for distant trees (StreamingEnabled model modes), 80-player
  load tests.

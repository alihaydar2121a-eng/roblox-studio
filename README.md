# OPERATION IRONFRONT

An original large-scale multiplayer military team shooter for Roblox (R6), built with Luau and Rojo.
Two fictional factions — the **Ashford Coalition** (olive) and the **Varn Directorate** (steel blue) —
fight over three objectives in **Kestrel Valley**, a procedurally assembled battlefield of forests,
roads, hills, villages and a farm. No third-party or unlicensed assets are used: all geometry is built
from Roblox primitives and built-in materials, and audio IDs are empty placeholders.

## Status: Phase 1 — playable vertical slice

| Feature | State |
|---|---|
| Rojo project, modular client/server/shared layout | ✅ |
| Team selection (balance-validated), auto-balance | ✅ |
| Server-driven spawning at team bases, spawn protection, respawn timer | ✅ |
| Original uniforms (body colours + helmet/vest/armbands) | ✅ |
| Large map: terrain, hills, forests, roads, 11 buildings (2-storey with ramps), bases | ✅ |
| 3 capture points with contested / neutralize / capture logic | ✅ |
| Tickets (deaths + majority bleed), 20-min timer, victory, intermission, round reset | ✅ |
| Server-authoritative hitscan rifle: validation, cadence, ammo, reload, falloff, headshots | ✅ |
| Hitmarkers, damage direction, tracers, dust puffs (non-graphic) | ✅ |
| HUD: tickets, timer, objective strip, capture bar, health, ammo, kill feed, notices | ✅ |
| World objective markers with distance | ✅ |
| Scoreboard (leaderstats: Score / Kills / Deaths) | ✅ |
| PC (mouse/keyboard), gamepad and mobile touch buttons | ✅ (untested on device) |
| Classes, vehicles, destruction, minimap/compass, persistence, settings | ⏳ see [docs/ROADMAP.md](docs/ROADMAP.md) |

> **Honesty note:** this code has been syntax-checked, unit-tested (pure logic) and built into a place
> file with Rojo, but it has **not yet been run inside Roblox Studio**. See
> [docs/STUDIO_VALIDATION.md](docs/STUDIO_VALIDATION.md) for the play-test checklist.

## Layout

```
default.project.json         Rojo tree (StreamingEnabled, CharacterAutoLoads=false, Teams, Lighting)
src/shared  -> ReplicatedStorage.Shared
  Config/   GameConfig, WeaponConfig, MapLayout, SoundConfig   (pure data)
  Logic/    CaptureLogic, TicketLogic, WeaponLogic, TeamLogic  (pure, unit-tested)
  Util/     RateLimiter, Signal, Validate, Color
  Net/      Remotes (single definition of every network endpoint)
src/server  -> ServerScriptService.Server (init.server.lua bootstrap)
  Net.lua          creates remotes, per-player rate limiting, error isolation
  GameState.lua    replicated match/zone state as attributes
  World/           MapBuilder (deterministic battlefield), Builder helpers
  Services/        TeamService, SpawnService, UniformService, WeaponFactory,
                   CombatService, ObjectiveService, MatchService
src/client  -> StarterPlayerScripts.Client (init.client.lua bootstrap)
  Controllers/     WeaponController, EffectsController, HudController,
                   TeamSelectController, ObjectiveMarkers, SoundPlayer
  UI/              Ui helper, Theme
tests/             luau unit tests for shared logic
scripts/check.sh   syntax check + tests + rojo build
```

### Authority & networking model
* The client only sends **intent**: `RequestTeam(teamId)`, `Fire({o=origin, d=direction})`, `Reload()`.
* Every remote passes through `Net.on` (token-bucket rate limit per player + `pcall`).
* `CombatService` re-validates everything: alive, holding the right weapon, cadence
  (≥75% of the fire interval), ammo, not reloading, origin within 10 studs of the server head,
  unit direction, match active. The **server raycasts** and applies damage via `Humanoid:TakeDamage`
  (respects spawn ForceFields). No friendly fire.
* Scoring, tickets, capture state and victory live exclusively on the server; clients read
  `ReplicatedStorage.GameState` attributes (independent of what workspace parts have streamed in).
* Cosmetic shot effects use an `UnreliableRemoteEvent` and are distance-culled on the client.

### Scaling toward 80 players
Objective checks are O(players × zones) on a 0.25 s tick; zone attributes only replicate on change;
tracers are unreliable + culled; the map is anchored primitives under StreamingEnabled. Known work for
80p: pool effect parts, lag-compensated hit validation, and spatial partitioning if more zones are added.

## Setup: Rojo → Roblox Studio

1. **Install Rojo 7.4.x**
   * CLI: via [Aftman](https://github.com/LPGhatguy/aftman) (`aftman install` in this repo uses `aftman.toml`),
     or download from <https://github.com/rojo-rbx/rojo/releases>.
   * Studio plugin: in a terminal run `rojo plugin install`, or install "Rojo" from the Creator Store.
2. **Create a place**: open Roblox Studio → *New* → *Baseplate*. Delete the `Baseplate` part and the
   default `SpawnLocation` in Workspace (the map is generated at runtime).
3. **Game settings** (Home → Game Settings; the place must be published/saved to Roblox to edit some):
   * *Avatar* → **Avatar Type: R6** (the server logs a warning if characters are not R6).
   * *Places* → set **Max Players** to 24 (Phase 1 target).
   * *Security* → enable "Allow HTTP Requests" is **not** required. Enable Studio API access only when
     persistence arrives in Phase 4.
4. **Serve**: from the repo root run `rojo serve`. In Studio open the *Rojo* plugin and click
   **Connect** (default `localhost:34872`). The `Shared`, `Server` and `Client` containers plus the
   Workspace/Players/Lighting properties sync into the place.
5. **Play-test**: *Test* → *Clients and Servers* → 2+ players → *Start*. Pick a side in the
   deployment screen in each client window. Single-player *Play* works too (you can capture points
   but there are no opponents).
6. Save the place (File → Save to Roblox) — Rojo syncs code; the place file keeps game settings.

Alternatively build a place file offline: `rojo build default.project.json -o OperationIronfront.rbxlx`
and open it in Studio (you still need step 3's settings).

## Controls
* **PC:** WASD move, mouse aim (over-the-shoulder, cursor locked while armed), LMB fire, R reload,
  hold Left Alt to free the cursor, Tab player list/scoreboard, M change team while redeploying.
* **Gamepad:** R2 fire, X reload.
* **Mobile:** thumbstick move, drag to aim (screen centre), on-screen FIRE and R buttons.

## Development checks
```
./scripts/check.sh            # needs luau, luau-compile, rojo on PATH (or TOOLS_DIR=...)
```
CI (`.github/workflows/check.yml`) runs the same script on every push.

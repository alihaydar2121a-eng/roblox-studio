# Studio-only validation checklist

Everything in this repository has been syntax-checked, unit-tested and built with Rojo. The map
generator has also been **executed offline** under Lune with real Roblox datatypes: property names
and types are checked, terrain write dimensions validated, and structures verified to rest on the
ground. None of it has been run inside Roblox Studio by the author. Check the items below in Studio
(Test → Clients and Servers, 2+ players) and tick them off.

## Milestone 1 — map bake & visuals
- [ ] **Bake:** Ironfront → Bake Map (Edit mode) completes without errors. Output lists
      `wedge calibration: … measured=true`. If it says `measured=false`, check one gable roof and one
      watchtower roof; if they look inverted, report it (defaults are in `Kit.lua`).
- [ ] Bake time noted: ______ s. Part count reported ≈ 21 000.
- [ ] After **File → Save**, closing and reopening the place, the terrain and `Workspace.Map` are
      still there. A play test prints `using baked map (version 3)`.
- [ ] Without a bake (fresh `rojo build` place), the server prints `battlefield ready (generated)`.
      The deploy panel shows "Preparing battlefield…" until then. Time: ______ s.
- [ ] **Terrain:**
  - mountains ring the valley
  - the river has water and carries under the three road bridges
  - the brook ravine is on the west side
  - trench lines are on the two hills west of Millbrook
  - there are no holes or seams between terrain chunks (every 128 studs)
- [ ] Grass decoration is visible on Grass terrain. If it isn't, enable *Terrain → Decoration* in
      the Properties panel.
- [ ] **Lighting:** Future lighting, warm afternoon sun, haze toward the mountains, no blown-out bloom.
- [ ] **Sites:** Fort Harlow, Millbrook (about 20 buildings, clock tower) and Kessler Works (tank
      farm, silos, chimney, gantry) look like the images in `docs/previews/`.
- [ ] **Interiors:** enter at least one two-storey house, the Command Post and a Kessler warehouse.
  - Stairs are climbable, and the stairwell railing blocks falls.
  - Command Post and warehouse roof hatches lead onto the roof.
  - The Maintenance building's external stair reaches its upper door.
  - Container stacks, tank catwalk and watchtower decks are all reachable.
- [ ] **Collision:** doors are walkable (4.6+ studs wide). Windows are open. Canopies and bushes
      don't block movement. Tree trunks do block movement.
- [ ] **No floating geometry:** trees, puddles and rocks sit on the terrain. Building foundations
      meet the ground.
- [ ] **Boundary:** you can't walk past ±768 studs. Falling below Y −40 kills you, and you respawn.
- [ ] **Streaming:** walking between sites, buildings and trees stream in without large pop-in
      directly around the player.
- [ ] **Performance:** on a mid-range PC the frame time is steady in the village and in the forest.
      Run MicroProfiler and note: ______ ms. Try a mobile device emulator too.

## Deployment camera (bug fix)
- [ ] On join, the deploy panel is docked left and doesn't cover the screen. The camera slowly
      orbits Millbrook with the battlefield filling the frame (not mostly sky), and the area is
      streamed in.

## Boot
- [ ] Output shows `[Ironfront] Server ready` with no errors.
- [ ] No `[SpawnService] Character is not R6` warning (set Avatar Type to R6 in Game Settings).

## Deployment & spawning
- [ ] Deployment screen appears with overview camera; team counts update.
- [ ] Joining a team spawns the character on a spawn pad inside that team's HQ, facing the
      battlefield, standing on the ground (not falling or stuck), wearing the team uniform.
      Two players never spawn on the same pad at once.
- [ ] Balance rule: with 2 players, both can't join the same side (second gets "That team is full").
- [ ] ForceField visible for ~3 s; bullets do no damage during it.
- [ ] After death: countdown shows, respawn after 6 s; pressing M opens the deploy screen and allows
      switching sides.

## Weapon
- [ ] Rifle auto-equips; **check the grip** — the barrel should point forward. If it points
      backwards/sideways, adjust `tool.Grip` in `src/server/Services/WeaponFactory.lua`.
- [ ] Over-the-shoulder camera, cursor locked (PC), character faces camera direction; Left Alt frees it.
- [ ] Holding LMB fires at ~600 RPM; tracers & dust puffs appear; other clients see your tracers.
- [ ] Hitmarker on enemy hit, gold on headshot, larger/orange on kill; victim sees damage arrow.
- [ ] Ammo counts down, R reloads (2.2 s), "RELOADING" shown; empty mag auto-requests reload.
- [ ] No damage to teammates.
- [ ] Mobile emulator (Test → Device): FIRE and R touch buttons appear and work.

## Objectives & match
- [ ] Standing in a zone shows the capture bar, including on the Millbrook plaza and inside nearby
      building ground floors. Neutral → captured takes about 12 s solo.
- [ ] Two opposing players in a zone shows CONTESTED and progress freezes.
- [ ] Flag and ring recolour to the owner; HUD chips and world markers update.
- [ ] Holding 2 of 3 points drains the enemy's tickets; deaths cost 1 ticket.
- [ ] At 0 tickets (tip: temporarily set `StartingTickets = 5`) the winner banner shows, weapons are
      removed, and after 15 s everyone respawns with reset tickets/zones/stats.
- [ ] Leaderboard (Tab) shows Score / Kills / Deaths.


## Networking abuse (optional, via the command bar on the client)
- [ ] Spamming `Fire` faster than the weapon's cadence does not increase damage output.
- [ ] Sending a Fire origin far from the head is ignored.

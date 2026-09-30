# Studio-only validation checklist

Everything in this repository has been syntax-checked, unit-tested and built with Rojo. The map
generator has also been **executed offline** under Lune with real Roblox datatypes: property names
and types are checked, terrain write dimensions validated, and structures verified to rest on the
ground. None of it has been run inside Roblox Studio by the author. Check the items below in Studio
(Test → Clients and Servers, 2+ players) and tick them off.

## Milestone 2 — soldiers, weapons, animation
Run it in Studio with 2+ players (Test → Clients and Servers) so you see both your own character and
others.
- [ ] **Joints:** Output has no `[CharacterAnimator]` warnings. The characters are not T-posing or
      frozen, which would mean the stub `Animate` script failed to replace the default one.
- [ ] **Soldier kits:** Ashford soldiers wear the olive helmet, plate carrier, rucksack, tan gloves
      and brown boots. Varn soldiers wear the angular dark helmet, blue-grey rig, radio pack and black
      gloves and boots.
  - Gear moves with the limbs while walking and never floats.
  - Shots still register on the body; gear is non-queryable.
- [ ] **Walking:**
  - idle has a visible breathing bob;
  - walking and running swing the legs;
  - Shift sprint leans forward, lowers the weapon and raises speed and FOV;
  - C (or Ctrl) crouch kneels, slows you down and tightens spread;
  - jump, fall and landing poses play.
- [ ] **Weapons:** the KR-20 (default), IR-7 Carbine, MG-44, SR-3 and P-11 (key 2).
  - The barrel points forward and the right hand is on the pistol grip.
  - The left hand is under the handguard. R6 arms are rigid, so it may sit short of the foregrip on
    long rifles.
- [ ] **Equip and switch:** 1 and 2 (or Q) switch with a raise animation, and you can't fire until
      the weapon is up. Other players see your weapon change.
- [ ] **Aiming:** RMB goes to first person with a smooth move to the sights.
  - KR-20, IR-7 and MG-44 show a red-dot reticle and hide the optic model.
  - The SR-3 shows the black scope overlay at high zoom.
  - The P-11 aims down its iron sights.
- [ ] **Firing:** recoil kicks the camera and viewmodel. A flash and tracer come from the muzzle in
      first and third person, and other players see your character's recoil.
- [ ] **Reload:** R reloads. The weapon tilts, the magazine disappears and returns, and the left hand
      goes down and back. Other players see this too. Ammo updates.
- [ ] **Viewmodel:** zoom fully in with the mouse wheel (or aim).
  - Sleeve and glove arms are in your faction colours.
  - Sway on mouse turn and bob while walking look right.
  - Walk into a wall: the weapon pulls back instead of clipping through.
  - Die and respawn: no leftover viewmodel.
- [ ] **Loadout:** the deploy panel's "Primary weapon" picker changes your primary on the next
      deployment.
- [ ] **Mobile emulator:** FIRE, AIM, R, SWAP, RUN and CRCH touch buttons all work. AIM, RUN and
      CRCH are toggles.
- [ ] **Optional imported meshes** (docs/ASSET_PIPELINE.md): after importing, the weapon model's
      `AssetSource` attribute reads `imported`, and the textured meshes appear in both first and
      third person.
- [ ] **Imported soldiers:** the blocky R6 limbs are hidden (Transparency 1) under the imported
      bodies, the head and face still show, and variant kit differs between players.
- [ ] Shots still register on the hidden limbs.
- [ ] The magazine hides during the reload and the optic hides at full aim.
- [ ] The first-person arms use the imported sleeves and gloves, and the fists sit on the grip and
      foregrip. Note any wrist twist here: ______.

## Premium assets — IR-7 Carbine and Ashford kit
Import them as described in [PREMIUM_ASSETS.md](PREMIUM_ASSETS.md), then check:
- [ ] **Install Assets** prints `IR7 -> ReplicatedStorage.ImportedAssets.Weapons.CB` and the six
      `Ashford_* -> …Gear.Alpha.*` lines. It shows no `rescaled`, `extent` or `missing part`
      warnings.
- [ ] Parts are textured: camo, stipple and edge wear are visible. If the importer did not create a
      `SurfaceAppearance`, follow step 3 in PREMIUM_ASSETS.md.
- [ ] **IR-7 third person:**
  - the grip is in the right hand and the barrel points forward;
  - the magazine disappears during reloads;
  - `AssetSource = imported`.
- [ ] **IR-7 first person:**
  - the red dot hides at full aim and the reticle is centred;
  - the muzzle flash comes from the brake;
  - nothing clips at hip fire.
- [ ] **Ashford soldier:**
  - helmet, plate carrier, pack, gloves and boots follow the limbs while walking, sprinting,
    crouching and reloading;
  - nothing floats;
  - arms don't visibly clip the vest;
  - shots still hit the body.
- [ ] **Variants:** different players show different mixes of helmet cover, goggles, headset,
      bedroll and antenna.
- [ ] **First-person arms:** as Ashford, the viewmodel forearms, cuffs and gloves are the premium
      meshes, and the hands sit on the grip and handguard.

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

# Studio-only validation checklist

The following could **not** be verified outside Roblox Studio and must be checked in a play-test
(Test → Clients and Servers, at least 2 players). Tick them off as you go.

## Boot
- [ ] Output shows `[Ironfront] Server ready` with no errors.
- [ ] Map generates (terrain, hills, roads, buildings, trees, both bases, 3 objectives). Note the
      server start time — terrain fill + ~600 trees should take well under a few seconds.
- [ ] No `[SpawnService] Character is not R6` warning (set Avatar Type to R6 in Game Settings).

## Deployment & spawning
- [ ] Deployment screen appears with overview camera; team counts update.
- [ ] Joining a team spawns the character at that team's base facing the battlefield, wearing the
      team uniform (body colours, helmet, vest, armbands). Player clothing/accessories are absent.
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
- [ ] Standing in a zone shows the capture bar; neutral → captured in ~12 s solo.
- [ ] Two opposing players in a zone shows CONTESTED and progress freezes.
- [ ] Flag and ring recolour to the owner; HUD chips and world markers update.
- [ ] Holding 2 of 3 points drains the enemy's tickets; deaths cost 1 ticket.
- [ ] At 0 tickets (tip: temporarily set `StartingTickets = 5`) the winner banner shows, weapons are
      removed, and after 15 s everyone respawns with reset tickets/zones/stats.
- [ ] Leaderboard (Tab) shows Score / Kills / Deaths.

## Visual/geometry spot checks
- [ ] Two-storey buildings: ramp is climbable and reaches the upper floor (WedgePart orientation).
- [ ] Doors and windows are open (walkable/shootable); no floating parts at road joints.
- [ ] Trees sit on the terrain on hills; none block roads or objectives.

## Networking abuse (optional, via the command bar on the client)
- [ ] Spamming `Fire` faster than the weapon's cadence does not increase damage output.
- [ ] Sending a Fire origin far from the head is ignored.

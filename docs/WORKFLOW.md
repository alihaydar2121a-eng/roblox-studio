# Development workflow: GitHub → Git → Rojo → Roblox Studio

You stop downloading ZIP files. You clone the repository **once**. After that, one script pulls
new commits and runs Rojo, and Rojo pushes the scripts into Studio while it is connected.

```
Claude Code (cloud) ──push──▶ GitHub branch claude/upbeat-fermi-oodwi6
                                   │
             Sync-Ironfront.ps1 / Watch-Ironfront.ps1  (git fetch + safe fast-forward)
                                   ▼
                       your local clone (files on disk)
                                   │  rojo serve (watches the files)
                                   ▼
                   Roblox Studio ── Rojo plugin (connected)
```

> **Important:** Rojo only syncs files that are already on your computer. It cannot fetch from
> GitHub by itself. The scripts do the fetching. Rojo also cannot turn FBX, GLB or PNG files into
> MeshParts or images. Those are imported once with Studio's 3D Importer (see
> `docs/PREMIUM_ASSETS.md`).

## One-time setup

1. **Install Git for Windows:** <https://git-scm.com/download/win>. The defaults are fine. They
   include Git Credential Manager, which remembers your GitHub sign-in securely, so the scripts
   never store a password.
2. **Install Rojo 7.7.0.** Pick one option:
   * **Aftman (recommended).** Download the latest `aftman-…-windows-x86_64.zip` from
     <https://github.com/LPGhatguy/aftman/releases>, unzip it and run `aftman self-install`. Then
     open a new PowerShell window. Step 4 runs `aftman install`, which reads `aftman.toml` and
     installs Rojo 7.7.0.
   * **Manual.** Download `rojo-7.7.0-windows-x86_64.zip` from
     <https://github.com/rojo-rbx/rojo/releases/tag/v7.7.0>. Put `rojo.exe` in a folder on your
     PATH.
3. **Clone the repository.** Open PowerShell in the folder where you keep projects (for example
   `Documents`) and run:
   ```powershell
   git clone --branch claude/upbeat-fermi-oodwi6 https://github.com/alihaydar2121a-eng/roblox-studio.git OperationIronfront
   cd OperationIronfront
   ```
   The repository is private, so a GitHub sign-in window appears the first time. Sign in once.
4. **If you use Aftman,** run `aftman install` inside `OperationIronfront` once. Then run
   `rojo --version`, which should print `Rojo 7.7.0`.
5. **Install the Rojo Studio plugin** to match the server. Run `rojo plugin install`, then restart
   Studio.
6. **Move your existing Studio place (the one with the baked map) out of the old ZIP folder.**
   `.rbxl` files are ignored by Git, so you can keep it inside `OperationIronfront` or anywhere
   else. Rojo never touches the map (see below). You can delete the old ZIP folders.

## Every session

1. Open your place in Roblox Studio.
2. Double-click **`Sync-Ironfront.cmd`** in the `OperationIronfront` folder, or run
   `.\Sync-Ironfront.ps1` in PowerShell. It:
   * checks Git and Rojo, the folder and the branch;
   * downloads new commits and fast-forwards your copy, but only when that can't overwrite your
     own edits;
   * lists what changed, and warns when something needs a manual Studio step (plugin or binary
     assets);
   * rebuilds the **Ironfront Tools** plugin when it changed;
   * checks that the project builds, then starts `rojo serve` and keeps running.
3. In Studio, go to **Plugins → Rojo → Connect** (`localhost`, port `34872`). Your scripts now
   match the repository.
4. Press **Play** to test.
5. Stop with **Ctrl+C**, or close the window.

**Getting new updates while you work:**
* **Easy:** stop the sync window and run it again.
* **Automatic:** also double-click **`Watch-Ironfront.cmd`**, or run
  `.\Watch-Ironfront.ps1 -IntervalSeconds 60`. It checks GitHub every 60 seconds and
  fast-forwards when it's safe. The running Rojo picks up the new files and Studio updates within
  seconds.
* **One window:** `.\Watch-Ironfront.ps1 -WithRojo` does both jobs.

**If PowerShell says "running scripts is disabled":** use the `.cmd` files, or run
`powershell -ExecutionPolicy Bypass -File .\Sync-Ironfront.ps1`. The `.cmd` files already do this
for the one script only, without changing your system setting.

### What the scripts will never do
* `git reset --hard`, `git clean`, `git rebase` or any force-push. They don't push at all.
* Merge when both you and GitHub have new commits. They tell you, and you decide.
* Overwrite a file you edited. If an incoming commit touches a file with local edits, the update
  is skipped and the file is named. Edits to other files are kept and the update goes ahead.
* Switch branches while you have uncommitted changes.

These rules are tested by `tests/workflow_sync.sh`, which runs the real scripts in PowerShell
against a throwaway remote repository. The test covers:
* the up-to-date and fast-forward cases;
* a conflicting local edit, and a non-conflicting one;
* diverged history;
* a wrong branch, with and without uncommitted changes;
* Rojo starting and listening.

It passes 16 of 16. It runs on Linux with PowerShell 7.4. The scripts are written for Windows
PowerShell 5.1 as well (ASCII only, no PowerShell 7-only syntax), but no Windows machine was
available to run them on.

## What Rojo manages and what stays in Studio

| Instance | Managed by | Notes |
|---|---|---|
| `ReplicatedStorage.Shared` | **Rojo** (`src/shared`) | Config, logic, animation and asset code. Edits made in Studio inside it are replaced. |
| `ReplicatedFirst.IronfrontLoading` | **Rojo** (`src/first`) | Loading card. |
| `ServerScriptService.Server` | **Rojo** (`src/server`) | Services and the map generator (`Server.World`). |
| `StarterPlayer.StarterPlayerScripts.Client` | **Rojo** (`src/client`) | Controllers and UI code. The UI is built in code. |
| `StarterPlayer.StarterCharacterScripts` | **Rojo** (`src/character`) | Only the `Animate` stub. Don't add scripts here in Studio. |
| Properties of Workspace (streaming), Players, StarterPlayer and Lighting, plus `Lighting.Atmosphere/Bloom/SunRays/Grade` | **Rojo** (`default.project.json`) | Reapplied on connect. Change them in the project file, not in Studio. |
| **Workspace contents:** the baked Kestrel Valley map, Terrain, spawns and objectives | **Studio** | Rojo never deletes or replaces them. |
| `ReplicatedStorage.ImportedAssets` (weapon and soldier meshes) | **Studio** | Created by *Ironfront → Install Assets* and saved in the place. |
| `ServerStorage`, `StarterGui`, `StarterPack`, any other `Lighting` children (Sky and so on) | **Studio** | Mapped with `$ignoreUnknownInstances`, so Rojo leaves their contents alone. |

Every service node in `default.project.json` sets `$ignoreUnknownInstances: true`, so Rojo only
changes the folders it maps.

## The map stays safe

* The map lives in **Workspace**, which Rojo doesn't manage. Connecting Rojo, pulling updates and
  generator code changes never alter a baked map.
* Map-generator code (`src/server/World`) does sync through Rojo. A generator change only affects
  the map when you click **Ironfront → Bake Map**, which replaces the map by design. **Save a copy
  of the place before re-baking** (*File → Save to File As…*).
* The **Ironfront Tools** plugin is built from `plugin/` by the sync script. Restart Studio after
  it says the plugin was rebuilt.

## Saving your own work

The scripts only ever download. If you change code locally and want to keep it, run:

```powershell
git add -A
git commit -m "Describe the change"
git push
```

Claude's next commits then build on top of yours. If both sides changed, the scripts report
"both have new commits". Run `git pull --no-rebase`, resolve any conflict it lists, then push.

## Troubleshooting

| Message | Fix |
|---|---|
| `Git is not installed` / `Rojo is not installed` | Install the tool (setup steps 1–2), then open a new PowerShell window. |
| `Port 34872 is already in use` | Another Rojo window is running. Close it, or use `.\Sync-Ironfront.ps1 -Port 34873` and the same port in Studio. |
| `Could not reach GitHub` | Check your internet connection. Run `git fetch` once by hand to redo the sign-in. |
| `local edits AND incoming changes` | Commit your edit, or stash it (`git stash`), or undo it (`git checkout -- <file>`). Then run the script again. |
| Studio's Rojo plugin says the version doesn't match | Run `rojo plugin install` and restart Studio. |
| A script change doesn't show in Studio | Check the Rojo plugin says *Connected*, and that the file is under `src/`. |

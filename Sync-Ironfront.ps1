<#
.SYNOPSIS
    One-click update + Rojo live sync for Operation Ironfront.

.DESCRIPTION
    1. Checks that Git and Rojo are installed.
    2. Finds this repository and checks the branch.
    3. Downloads new commits from GitHub and fast-forwards your local branch
       ONLY when that cannot overwrite your own edits (never resets, cleans or force-pushes).
    4. Rebuilds the Ironfront Tools Studio plugin when it changed (or is missing).
    5. Starts "rojo serve" and keeps running until you press Ctrl+C.

    Rojo only syncs files that are already on this computer. It does not download from GitHub
    by itself - that is what step 3 (or Watch-Ironfront.ps1) does.

.PARAMETER Branch
    Branch to follow. Default: claude/upbeat-fermi-oodwi6

.PARAMETER Port
    Rojo port. Default: 34872 (the Studio plugin's default).

.PARAMETER NoUpdate
    Skip the GitHub update; just start Rojo.

.PARAMETER NoPlugin
    Never rebuild the Ironfront Tools plugin.

.EXAMPLE
    .\Sync-Ironfront.ps1
.EXAMPLE
    .\Sync-Ironfront.ps1 -NoUpdate -Port 34873
#>
[CmdletBinding()]
param(
    [string]$Branch = 'claude/upbeat-fermi-oodwi6',
    [int]$Port = 34872,
    [switch]$NoUpdate,
    [switch]$NoPlugin
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scripts\windows\Ironfront.Common.ps1')

Write-Host ''
Write-Host '  OPERATION IRONFRONT - sync' -ForegroundColor White
Write-Host ''

Write-Step 'Checking tools'
Assert-Git
$repo = Find-Repo $PSScriptRoot
Write-Ok "Repository: $repo"
$rojoVersion = Assert-Rojo $repo

Write-Step 'Checking branch'
if (-not (Select-Branch $repo $Branch)) { exit 1 }

$changes = Get-LocalChanges $repo
if ($changes.Count -gt 0) {
    Write-Warn "$($changes.Count) uncommitted local change(s). They are kept; updates that would touch them are skipped."
    $changes | Select-Object -First 8 | ForEach-Object { Write-Info "  $_" }
} else {
    Write-Ok 'No local changes.'
}

$pluginChanged = $false
if ($NoUpdate) {
    Write-Step 'Skipping GitHub update (-NoUpdate)'
} else {
    Write-Step "Updating from GitHub ($Branch)"
    $result = Update-Branch $repo $Branch
    switch ($result.Status) {
        'updated'  { Write-Ok $result.Message; Show-UpdateReport $repo $result }
        'current'  { Write-Ok $result.Message }
        'ahead'    { Write-Warn $result.Message }
        default    { Write-Fail $result.Message; Write-Warn 'Continuing with your current files.' }
    }
    if ($result.Status -eq 'updated') {
        $pluginChanged = [bool](@($result.Files) | Where-Object { $_ -like 'plugin/*' -or $_ -eq 'plugin.project.json' })
    }
}

if (-not $NoPlugin) {
    $pluginFile = Join-Path $env:LOCALAPPDATA 'Roblox\Plugins\IronfrontTools.rbxmx'
    if ($pluginChanged -or -not (Test-Path $pluginFile)) {
        Write-Step 'Building the Ironfront Tools Studio plugin'
        Push-Location $repo
        try {
            & rojo build plugin.project.json --plugin IronfrontTools.rbxmx
            if ($LASTEXITCODE -eq 0) { Write-Ok 'Installed to your Studio plugins folder. Restart Studio if it is open.' }
            else { Write-Warn 'Plugin build failed (see above). The game sync still works.' }
        } finally { Pop-Location }
    }
}

Write-Step 'Checking the project'
Push-Location $repo
try {
    $check = Join-Path ([System.IO.Path]::GetTempPath()) 'ironfront-check.rbxl'
    & rojo build default.project.json -o $check | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Fail 'rojo build failed - the project has an error (see above). Not starting the server.'
        exit 1
    }
    Remove-Item $check -ErrorAction SilentlyContinue
    Write-Ok 'default.project.json builds.'
} finally { Pop-Location }

if (-not (Test-PortFree $Port)) {
    Write-Fail "Port $Port is already in use - is another Rojo window still running? Close it, or run: .\Sync-Ironfront.ps1 -Port $($Port + 1)"
    exit 1
}

Write-Host ''
Write-Host '  Rojo is starting. In Roblox Studio:' -ForegroundColor White
Write-Host '    1. Open your Operation Ironfront place (the one with the baked map).'
Write-Host '    2. Plugins tab -> Rojo -> Connect  (address localhost, port ' -NoNewline; Write-Host $Port -NoNewline; Write-Host ').'
Write-Host "    3. Scripts now update live when files change. The Rojo Studio plugin must be 7.x (server is $rojoVersion)."
Write-Host '    4. To get new commits later: press Ctrl+C here and run this script again,'
Write-Host '       or keep Watch-Ironfront.ps1 running in a second window.'
Write-Host ''
Write-Host '  Press Ctrl+C to stop.' -ForegroundColor Yellow
Write-Host ''

Push-Location $repo
try {
    & rojo serve default.project.json --port $Port
    if ($LASTEXITCODE -ne 0) { Write-Fail "Rojo exited with code $LASTEXITCODE." }
} finally {
    Pop-Location
    Write-Host 'Rojo stopped.'
}

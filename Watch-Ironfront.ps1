<#
.SYNOPSIS
    Live update mode: checks GitHub every N seconds and fast-forwards your local
    branch when it is safe. Rojo (running in Sync-Ironfront.ps1) then pushes the new
    files into Studio.

.DESCRIPTION
    - Pulls only when a fast-forward is possible and no incoming file has local edits.
    - Skips (and says why) when you have conflicting edits or local commits.
    - Never resets, cleans, rebases or force-pushes.
    - Uses your normal Git sign-in (Git Credential Manager); stores no credentials.
    - Stop with Ctrl+C.

.PARAMETER IntervalSeconds
    Seconds between checks. Default 60 (minimum 15).

.PARAMETER Branch
    Branch to follow. Default: claude/upbeat-fermi-oodwi6

.PARAMETER WithRojo
    Also start "rojo serve" in this window, so one window does everything.

.EXAMPLE
    .\Watch-Ironfront.ps1
.EXAMPLE
    .\Watch-Ironfront.ps1 -IntervalSeconds 120 -WithRojo
#>
[CmdletBinding()]
param(
    [ValidateRange(15, 86400)][int]$IntervalSeconds = 60,
    [string]$Branch = 'claude/upbeat-fermi-oodwi6',
    [switch]$WithRojo,
    [int]$Port = 34872,
    [switch]$Once
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scripts\windows\Ironfront.Common.ps1')
# Never hang on a password prompt in the background loop.
$env:GIT_TERMINAL_PROMPT = '0'

Write-Host ''
Write-Host '  OPERATION IRONFRONT - live update' -ForegroundColor White
Write-Host ''
Write-Step 'Checking tools'
Assert-Git
$repo = Find-Repo $PSScriptRoot
Write-Ok "Repository: $repo"
if (-not (Select-Branch $repo $Branch)) { exit 1 }

$rojo = $null
if ($WithRojo) {
    Assert-Rojo $repo | Out-Null
    if (-not (Test-PortFree $Port)) {
        Write-Fail "Port $Port is in use - Rojo is probably already running (Sync-Ironfront.ps1). Run without -WithRojo."
        exit 1
    }
    $rojo = Start-Process -FilePath 'rojo' -ArgumentList @('serve', 'default.project.json', '--port', "$Port") `
        -WorkingDirectory $repo -NoNewWindow -PassThru
    Write-Ok "Rojo serving on port $Port (connect from Studio: Plugins -> Rojo -> Connect)."
}

Write-Host ''
Write-Host "  Checking GitHub every $IntervalSeconds s. Press Ctrl+C to stop." -ForegroundColor Yellow
Write-Host ''

$lastNote = ''
try {
    while ($true) {
        $stamp = Get-Date -Format 'HH:mm:ss'
        $result = Update-Branch $repo $Branch
        switch ($result.Status) {
            'updated' {
                Write-Host "[$stamp] " -NoNewline; Write-Host $result.Message -ForegroundColor Green
                Show-UpdateReport $repo $result
                $lastNote = ''
            }
            'current' {
                if ($lastNote -ne 'current') { Write-Host "[$stamp] Up to date. Waiting for new commits..." }
                $lastNote = 'current'
            }
            default {
                # Repeat the same warning only when it changes, to keep the window readable.
                if ($lastNote -ne $result.Message) {
                    Write-Host "[$stamp] " -NoNewline; Write-Host "Skipped: $($result.Message)" -ForegroundColor Yellow
                }
                $lastNote = $result.Message
            }
        }
        if ($rojo -and $rojo.HasExited) {
            Write-Fail "Rojo stopped (exit code $($rojo.ExitCode)). Restart this script."
            break
        }
        if ($Once) { break }
        Start-Sleep -Seconds $IntervalSeconds
    }
} finally {
    if ($rojo -and -not $rojo.HasExited) {
        Stop-Process -Id $rojo.Id -ErrorAction SilentlyContinue
        Write-Host 'Rojo stopped.'
    }
    Write-Host 'Live update stopped.'
}

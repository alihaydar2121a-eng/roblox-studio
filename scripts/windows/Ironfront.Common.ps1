# Shared helpers for Sync-Ironfront.ps1 and Watch-Ironfront.ps1.
# Works in Windows PowerShell 5.1 and PowerShell 7+. ASCII only (5.1 reads
# BOM-less scripts as ANSI). Never runs destructive Git commands: updates are
# fast-forward merges only, and Git itself refuses to overwrite local edits.

$script:DefaultBranch = 'claude/upbeat-fermi-oodwi6'
$script:Remote = 'origin'

function Write-Step([string]$Text) { Write-Host "==> $Text" -ForegroundColor Cyan }
function Write-Ok([string]$Text) { Write-Host "    $Text" -ForegroundColor Green }
function Write-Info([string]$Text) { Write-Host "    $Text" }
function Write-Warn([string]$Text) { Write-Host "    WARNING: $Text" -ForegroundColor Yellow }
function Write-Fail([string]$Text) { Write-Host "    ERROR: $Text" -ForegroundColor Red }

# Runs git with the given arguments in the repository; returns stdout lines.
# Throws with git's own message when git exits non-zero.
# Usage: Invoke-Git <repo> <git arguments...>  (plain function on purpose: "--flags"
# pass straight through to git on every PowerShell version).
function Invoke-Git {
    $Repo = $args[0]
    $GitArgs = @($args | Select-Object -Skip 1)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'   # git writes progress to stderr
    try {
        $output = & git -C $Repo @GitArgs 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    $lines = @($output | ForEach-Object { "$_" })
    if ($code -ne 0) {
        throw ("git {0} failed (exit {1}):`n{2}" -f ($GitArgs -join ' '), $code, ($lines -join "`n"))
    }
    return $lines
}

function Test-Command([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Assert-Git {
    if (-not (Test-Command 'git')) {
        Write-Fail 'Git is not installed or not on PATH.'
        Write-Info 'Install Git for Windows from https://git-scm.com/download/win, then open a NEW PowerShell window.'
        exit 1
    }
    Write-Ok ((& git --version) -join ' ')
}

# Returns the repository root that contains this script.
function Find-Repo([string]$Start) {
    $dir = Resolve-Path $Start
    try {
        $root = Invoke-Git $dir rev-parse --show-toplevel | Select-Object -First 1
    } catch {
        Write-Fail "$Start is not inside a Git repository."
        Write-Info 'Clone the repository first (see docs/WORKFLOW.md), then run the script from the cloned folder.'
        exit 1
    }
    $root = [System.IO.Path]::GetFullPath($root)
    if (-not (Test-Path (Join-Path $root 'default.project.json'))) {
        Write-Fail "$root has no default.project.json - this is not the Operation Ironfront repository."
        exit 1
    }
    return $root
}

# Uncommitted local changes as "XY path" lines (untracked files included).
function Get-LocalChanges([string]$Repo) {
    return @(Invoke-Git $Repo status --porcelain | Where-Object { $_ -ne '' })
}

function Get-ChangedPath([string]$StatusLine) {
    $path = $StatusLine.Substring(3)
    if ($path -match ' -> ') { $path = ($path -split ' -> ')[1] }
    return $path.Trim('"')
}

# Makes sure the requested branch is checked out. Switches only when that is safe.
function Select-Branch([string]$Repo, [string]$Branch) {
    $current = (Invoke-Git $Repo rev-parse --abbrev-ref HEAD | Select-Object -First 1)
    if ($current -eq $Branch) {
        Write-Ok "On branch $Branch"
        return $true
    }
    Write-Warn "Current branch is '$current', expected '$Branch'."
    if ((Get-LocalChanges $Repo).Count -gt 0) {
        Write-Fail 'You have uncommitted changes, so the script will not switch branches.'
        Write-Info "Commit or stash them (git stash), or run: git switch $Branch"
        return $false
    }
    $hasLocal = $true
    try { Invoke-Git $Repo rev-parse --verify --quiet "refs/heads/$Branch" | Out-Null } catch { $hasLocal = $false }
    if ($hasLocal) {
        Invoke-Git $Repo switch $Branch | Out-Null
    } else {
        Invoke-Git $Repo fetch $script:Remote $Branch | Out-Null
        Invoke-Git $Repo switch --track "$($script:Remote)/$Branch" | Out-Null
    }
    Write-Ok "Switched to $Branch"
    return $true
}

<#
  Fetches the branch and fast-forwards the local copy when it is safe.
  Returns a hashtable: Status = 'updated' | 'current' | 'ahead' | 'diverged' | 'blocked' | 'error',
  plus OldHead, NewHead, Files (changed paths), Message.
#>
function Update-Branch([string]$Repo, [string]$Branch) {
    $remoteRef = "$($script:Remote)/$Branch"
    try {
        Invoke-Git $Repo fetch --quiet $script:Remote $Branch | Out-Null
    } catch {
        return @{ Status = 'error'; Message = "Could not reach GitHub: $($_.Exception.Message)" }
    }
    $counts = (Invoke-Git $Repo rev-list --left-right --count "HEAD...$remoteRef" | Select-Object -First 1) -split '\s+'
    $ahead = [int]$counts[0]
    $behind = [int]$counts[1]
    $old = (Invoke-Git $Repo rev-parse HEAD | Select-Object -First 1)
    if ($behind -eq 0) {
        if ($ahead -gt 0) {
            return @{ Status = 'ahead'; OldHead = $old; NewHead = $old; Files = @(); Message = "Your branch has $ahead local commit(s) not on GitHub. Nothing to download." }
        }
        return @{ Status = 'current'; OldHead = $old; NewHead = $old; Files = @(); Message = 'Already up to date.' }
    }
    if ($ahead -gt 0) {
        return @{ Status = 'diverged'; OldHead = $old; NewHead = $old; Files = @()
            Message = "Your branch and GitHub both have new commits ($ahead local, $behind remote). Not merging automatically. Run 'git pull --no-rebase' yourself, or ask for help." }
    }
    $incoming = @(Invoke-Git $Repo diff --name-only HEAD $remoteRef)
    $dirty = @(Get-LocalChanges $Repo | ForEach-Object { Get-ChangedPath $_ })
    $clash = @($dirty | Where-Object { $incoming -contains $_ })
    if ($clash.Count -gt 0) {
        return @{ Status = 'blocked'; OldHead = $old; NewHead = $old; Files = $clash
            Message = "These files have local edits AND incoming changes: $($clash -join ', '). Commit, stash (git stash) or undo them, then run again." }
    }
    try {
        Invoke-Git $Repo merge --ff-only --quiet $remoteRef | Out-Null
    } catch {
        return @{ Status = 'blocked'; OldHead = $old; NewHead = $old; Files = @(); Message = "Git refused the fast-forward: $($_.Exception.Message)" }
    }
    $new = (Invoke-Git $Repo rev-parse HEAD | Select-Object -First 1)
    return @{ Status = 'updated'; OldHead = $old; NewHead = $new; Files = $incoming; Message = "Updated $behind commit(s)." }
}

# Prints commits and what the changed files mean for Studio.
function Show-UpdateReport([string]$Repo, $Result) {
    if ($Result.Status -ne 'updated') { return }
    Write-Info 'New commits:'
    Invoke-Git $Repo log --oneline --no-decorate "$($Result.OldHead)..$($Result.NewHead)" | ForEach-Object { Write-Info "  $_" }
    $files = @($Result.Files)
    $code = @($files | Where-Object { $_ -like 'src/*' -or $_ -eq 'default.project.json' })
    $plugin = @($files | Where-Object { $_ -like 'plugin/*' -or $_ -eq 'plugin.project.json' })
    $assets = @($files | Where-Object { $_ -match '\.(fbx|glb|obj|png|jpg|ogg|mp3|wav|rbxm|rbxmx)$' })
    Write-Info ("{0} file(s) changed: {1} game code, {2} plugin, {3} binary asset(s)." -f $files.Count, $code.Count, $plugin.Count, $assets.Count)
    if ($code.Count -gt 0) { Write-Ok 'Game code changes reach Studio automatically while Rojo is connected.' }
    if ($plugin.Count -gt 0) { Write-Warn 'The Ironfront Tools plugin changed. Sync-Ironfront.ps1 rebuilds it; restart Studio (or reload plugins) to use it.' }
    if ($assets.Count -gt 0) {
        Write-Warn 'Binary assets changed. Rojo cannot import FBX/GLB/images - import them in Studio (docs/PREMIUM_ASSETS.md):'
        $assets | Select-Object -First 12 | ForEach-Object { Write-Info "  $_" }
    }
}

# Rojo on PATH (Aftman/Rokit/Foreman shims or a manual install). Returns the version string.
function Assert-Rojo([string]$Repo) {
    if (-not (Test-Command 'rojo')) {
        Write-Fail 'Rojo is not installed or not on PATH.'
        Write-Info 'Easiest: install Aftman (https://github.com/LPGhatguy/aftman/releases), then in this folder run:'
        Write-Info '    aftman install'
        Write-Info 'Or download rojo-7.7.0-windows-x86_64.zip from https://github.com/rojo-rbx/rojo/releases/tag/v7.7.0'
        Write-Info 'and put rojo.exe in a folder on your PATH. Then open a NEW PowerShell window.'
        exit 1
    }
    Push-Location $Repo
    try { $text = (& rojo --version 2>&1) -join ' ' } finally { Pop-Location }
    if ($text -notmatch '(\d+)\.(\d+)\.(\d+)') {
        Write-Fail "Could not read the Rojo version ('$text'). If Aftman says the tool is not installed, run: aftman install"
        exit 1
    }
    $major = [int]$Matches[1]; $minor = [int]$Matches[2]
    if ($major -ne 7) {
        Write-Fail "Rojo $($Matches[0]) found; this project needs Rojo 7.x (7.7.0 recommended)."
        exit 1
    }
    if ($minor -lt 4) { Write-Warn "Rojo $($Matches[0]) is old; 7.7.0 is recommended (aftman install)." }
    Write-Ok "Rojo $($Matches[0])"
    return $Matches[0]
}

function Test-PortFree([int]$Port) {
    try {
        $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
        $listener.Start()
        $listener.Stop()
        return $true
    } catch {
        return $false
    }
}

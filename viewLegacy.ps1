<#
.SYNOPSIS
    Open the old CeeVee-template version of this site in a browser.

.DESCRIPTION
    Checks out the legacy-ceevee-2014 tag into a throwaway worktree beside
    this repo, serves it on localhost, and opens it in your browser. When you
    press Enter it stops the server and deletes the worktree again.

    Nothing here touches main, and nothing is ever pushed. The worktree is a
    detached checkout of an old commit; the tag keeps that commit alive
    forever, so this is repeatable as often as you like.

    Safe to run from any directory, and safe to re-run if a previous session
    was interrupted -- it cleans up leftovers before it starts.

.EXAMPLE
    .\viewLegacy.ps1
    Serve the old site on http://127.0.0.1:8000/ and open it.

.EXAMPLE
    .\viewLegacy.ps1 -Port 8080
    Same, on a different port.

.EXAMPLE
    .\viewLegacy.ps1 -Keep
    Leave the worktree on disk afterwards so you can poke at the files.
    Remove it later with:
      git -C "<this repo>" worktree remove ..\bio-legacy
#>

[CmdletBinding()]
param(
    # Port for the local preview server. Auto-advances if busy.
    [ValidateRange(1024, 65535)]
    [int]$Port = 8000,

    # Which tag or commit to view.
    [string]$Tag = 'legacy-ceevee-2014',

    # Keep the worktree on disk after exiting instead of deleting it.
    [switch]$Keep,

    # Serve it but don't launch a browser.
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
# Keep git's exit codes as exit codes rather than thrown errors, so the
# $LASTEXITCODE checks below behave the same on PowerShell 5.1 and 7.x.
$PSNativeCommandUseErrorActionPreference = $false

$repo     = $PSScriptRoot
$worktree = Join-Path (Split-Path $repo -Parent) 'bio-legacy'
$server   = $null
$created  = $false

function Write-Step { param($m) Write-Host "  $m" -ForegroundColor DarkGray }

try {
    # --- sanity checks ---------------------------------------------------
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git is not on PATH."
    }

    git -C $repo rev-parse --git-dir *> $null
    if ($LASTEXITCODE -ne 0) { throw "$repo is not a git repository." }

    git -C $repo rev-parse --verify --quiet "$Tag^{commit}" *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Tag '$Tag' not found. Available tags: $(git -C $repo tag -l)"
    }

    # Find a Python to serve with.
    $py = $null
    foreach ($c in @(@{Cmd='python'; Pre=@()}, @{Cmd='py'; Pre=@('-3')})) {
        if (Get-Command $c.Cmd -ErrorAction SilentlyContinue) { $py = $c; break }
    }
    if (-not $py) { throw "No python found on PATH; cannot start the preview server." }

    # --- clean up anything a previous run left behind --------------------
    git -C $repo worktree prune *> $null
    if (Test-Path $worktree) {
        Write-Step "Removing a leftover worktree from a previous run..."
        git -C $repo worktree remove --force $worktree *> $null
        if (Test-Path $worktree) { Remove-Item -Recurse -Force $worktree }
    }

    # --- create the worktree ---------------------------------------------
    Write-Host "`nRestoring the old site ($Tag)..." -ForegroundColor Cyan
    git -C $repo worktree add --detach $worktree $Tag *> $null
    if ($LASTEXITCODE -ne 0) { throw "Could not create the worktree at $worktree." }
    $created = $true

    $fileCount = (Get-ChildItem $worktree -Recurse -File -Force |
                  Where-Object { $_.FullName -notmatch '\\\.git' }).Count
    Write-Step "$fileCount files restored to $worktree"

    # --- pick a free port -------------------------------------------------
    while ($true) {
        $inUse = $false
        try {
            $inUse = [bool](Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction Stop)
        } catch { $inUse = $false }
        if (-not $inUse) { break }
        Write-Step "Port $Port is busy, trying $($Port + 1)..."
        $Port++
    }

    # --- serve -------------------------------------------------------------
    $url = "http://127.0.0.1:$Port/"
    # NB: not $args -- that is an automatic variable in PowerShell.
    $serverArgs = @($py.Pre + @('-m', 'http.server', $Port, '--bind', '127.0.0.1'))
    $server = Start-Process -FilePath $py.Cmd -ArgumentList $serverArgs `
                            -WorkingDirectory $worktree -PassThru -WindowStyle Hidden

    # Wait for it to actually answer before opening the browser.
    $ready = $false
    foreach ($i in 1..40) {
        Start-Sleep -Milliseconds 250
        if ($server.HasExited) { throw "The preview server exited unexpectedly." }
        try {
            Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 2 *> $null
            $ready = $true; break
        } catch { }
    }
    if (-not $ready) { throw "The preview server did not come up on $url." }

    Write-Host "`n  The 2014 site is live at " -NoNewline -ForegroundColor Green
    Write-Host $url -ForegroundColor White
    Write-Step "jQuery 1.10.2, skill bars, CeeVee footer and all."

    if (-not $NoBrowser) { Start-Process $url }

    Write-Host ""
    try {
        Read-Host "  Press Enter when you are done looking"
    }
    catch {
        # No console to prompt on (non-interactive host, redirected input).
        # Serve until the process is stopped instead of bailing out.
        Write-Step "Non-interactive session; serving until stopped (Ctrl+C)."
        Wait-Process -Id $server.Id
    }
}
catch {
    Write-Host "`n  $($_.Exception.Message)`n" -ForegroundColor Red
    exit 1
}
finally {
    if ($server -and -not $server.HasExited) {
        Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
    }

    if ($created -and -not $Keep) {
        git -C $repo worktree remove $worktree *> $null
        if ($LASTEXITCODE -ne 0) {
            # Files were edited in the worktree; don't discard them silently.
            Write-Host "  Worktree kept (it has local changes): $worktree" -ForegroundColor Yellow
            Write-Host "  Discard them with: git -C `"$repo`" worktree remove --force `"$worktree`"" -ForegroundColor DarkGray
        } else {
            Write-Host "  Cleaned up. The tag stays, so run this again any time." -ForegroundColor DarkGray
        }
    }
    elseif ($created -and $Keep) {
        Write-Host "  Worktree kept at $worktree" -ForegroundColor Yellow
        Write-Host "  Remove it with: git -C `"$repo`" worktree remove `"$worktree`"" -ForegroundColor DarkGray
    }
}
